defmodule Raxol.Swarm.Topology do
  @moduledoc """
  Manages node roles and handles promotion/demotion on failure.

  Uses seniority-based commander election: the longest-running node
  becomes commander. No Raft/Paxos -- tactical decisions don't need
  consensus, just a coordinator.
  """

  use GenServer

  require Logger

  @type role :: :commander | :wingmate | :observer | :relay

  @type node_info :: %{
          role: role(),
          joined_at: integer()
        }

  @type t :: %__MODULE__{
          node_id: node(),
          role: role(),
          nodes: %{node() => node_info()},
          commander: node() | nil,
          election_state: :stable | :electing,
          quorum_size: pos_integer(),
          node_monitor: GenServer.server()
        }

  defstruct node_id: nil,
            role: :wingmate,
            nodes: %{},
            commander: nil,
            election_state: :stable,
            quorum_size: 1,
            node_monitor: Raxol.Swarm.NodeMonitor

  # -- Public API --

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec get_role(GenServer.server()) :: role()
  def get_role(server \\ __MODULE__) do
    GenServer.call(server, :get_role)
  end

  @spec get_commander(GenServer.server()) ::
          {:ok, node()} | {:error, :no_commander}
  def get_commander(server \\ __MODULE__) do
    GenServer.call(server, :get_commander)
  end

  @spec list_nodes(GenServer.server()) :: [{node(), role()}]
  def list_nodes(server \\ __MODULE__) do
    GenServer.call(server, :list_nodes)
  end

  @spec promote(GenServer.server(), node(), role()) :: :ok | {:error, term()}
  def promote(server \\ __MODULE__, node, role) do
    GenServer.call(server, {:promote, node, role})
  end

  @spec request_role(GenServer.server(), role()) :: :ok | {:error, term()}
  def request_role(server \\ __MODULE__, role) do
    GenServer.call(server, {:request_role, role})
  end

  @spec node_count(GenServer.server()) :: non_neg_integer()
  def node_count(server \\ __MODULE__) do
    GenServer.call(server, :node_count)
  end

  @doc "Notify topology of a node joining. Called by Supervisor on node_up."
  @spec node_joined(GenServer.server(), node()) :: :ok
  def node_joined(server \\ __MODULE__, node) do
    GenServer.cast(server, {:node_joined, node})
  end

  @doc "Notify topology of a node leaving. Called by Supervisor on node_down."
  @spec node_left(GenServer.server(), node()) :: :ok
  def node_left(server \\ __MODULE__, node) do
    GenServer.cast(server, {:node_left, node})
  end

  # -- Callbacks --

  @impl true
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, Node.self())
    quorum_size = Keyword.get(opts, :quorum_size, 1)
    node_monitor = Keyword.get(opts, :node_monitor, Raxol.Swarm.NodeMonitor)

    # Subscribe to NodeMonitor for automatic node tracking
    try do
      Raxol.Swarm.NodeMonitor.subscribe(node_monitor)
    catch
      :exit, _ -> :ok
    end

    now = System.monotonic_time(:millisecond)

    self_info = %{role: :wingmate, joined_at: now}

    state = %__MODULE__{
      node_id: node_id,
      quorum_size: quorum_size,
      node_monitor: node_monitor,
      nodes: %{node_id => self_info}
    }

    state = run_election(state)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_role, _from, state) do
    {:reply, state.role, state}
  end

  @impl true
  def handle_call(:get_commander, _from, state) do
    case state.commander do
      nil -> {:reply, {:error, :no_commander}, state}
      commander -> {:reply, {:ok, commander}, state}
    end
  end

  @impl true
  def handle_call(:list_nodes, _from, state) do
    nodes = Enum.map(state.nodes, fn {node, info} -> {node, info.role} end)
    {:reply, nodes, state}
  end

  @impl true
  def handle_call({:promote, node, role}, _from, %__MODULE__{} = state) do
    case Map.get(state.nodes, node) do
      nil ->
        {:reply, {:error, :unknown_node}, state}

      info ->
        state =
          state
          |> put_node_role(node, %{info | role: role})
          |> maybe_update_own_role(node, role)
          |> maybe_update_commander(node, role)

        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:request_role, role}, _from, %__MODULE__{} = state) do
    case Map.get(state.nodes, state.node_id) do
      nil ->
        {:reply, {:error, :not_registered}, state}

      info ->
        state =
          state
          |> put_node_role(state.node_id, %{info | role: role})
          |> maybe_update_own_role(state.node_id, role)

        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:node_count, _from, state) do
    {:reply, map_size(state.nodes), state}
  end

  @impl true
  def handle_cast({:node_joined, node}, %__MODULE__{} = state) do
    if Map.has_key?(state.nodes, node) do
      {:noreply, state}
    else
      now = System.monotonic_time(:millisecond)
      info = %{role: :wingmate, joined_at: now}
      state = %__MODULE__{state | nodes: Map.put(state.nodes, node, info)}
      Logger.info("Swarm topology: node joined: #{node}")
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:node_left, node}, %__MODULE__{} = state) do
    state = %__MODULE__{state | nodes: Map.delete(state.nodes, node)}
    Logger.info("Swarm topology: node left: #{node}")

    state =
      if state.commander == node do
        Logger.info("Swarm topology: commander lost, re-electing")
        run_election(state)
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:swarm_event, {:node_up, node}}, %__MODULE__{} = state) do
    if Map.has_key?(state.nodes, node) do
      {:noreply, state}
    else
      now = System.monotonic_time(:millisecond)
      info = %{role: :wingmate, joined_at: now}
      state = %__MODULE__{state | nodes: Map.put(state.nodes, node, info)}
      Logger.info("Swarm topology: node joined via discovery: #{node}")
      state = run_election(state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:swarm_event, {:node_down, node}}, %__MODULE__{} = state) do
    state = %__MODULE__{state | nodes: Map.delete(state.nodes, node)}
    Logger.info("Swarm topology: node left via discovery: #{node}")

    state =
      if state.commander == node do
        Logger.info("Swarm topology: commander lost, re-electing")
        run_election(state)
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:swarm_event, _}, state), do: {:noreply, state}

  @impl true
  def handle_info(msg, state) do
    Logger.debug("#{__MODULE__} received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # -- Private --

  defp put_node_role(%__MODULE__{} = state, node, info),
    do: %__MODULE__{state | nodes: Map.put(state.nodes, node, info)}

  defp maybe_update_own_role(%__MODULE__{node_id: node_id} = state, node, role)
       when node == node_id,
       do: %__MODULE__{state | role: role}

  defp maybe_update_own_role(%__MODULE__{} = state, _node, _role), do: state

  defp maybe_update_commander(%__MODULE__{} = state, node, :commander),
    do: %__MODULE__{state | commander: node}

  defp maybe_update_commander(%__MODULE__{} = state, _node, _role), do: state

  defp run_election(%__MODULE__{} = state) do
    state = %__MODULE__{state | election_state: :electing}
    elect_if_quorum(state, map_size(state.nodes) >= state.quorum_size)
  end

  defp elect_if_quorum(%__MODULE__{} = state, false) do
    Logger.warning(
      "Swarm topology: no quorum (#{map_size(state.nodes)}/#{state.quorum_size})"
    )

    %__MODULE__{state | commander: nil, election_state: :stable}
  end

  defp elect_if_quorum(%__MODULE__{} = state, true) do
    {winner, _info} =
      state.nodes
      |> Enum.min_by(fn {_node, info} -> info.joined_at end)

    Logger.info("Swarm topology: elected commander: #{winner}")

    nodes =
      Map.new(state.nodes, fn {node, info} ->
        {node, %{info | role: role_for_node(node, winner)}}
      end)

    %__MODULE__{
      state
      | nodes: nodes,
        commander: winner,
        role: role_for_node(state.node_id, winner),
        election_state: :stable
    }
  end

  defp role_for_node(node, winner) when node == winner, do: :commander
  defp role_for_node(_node, _winner), do: :wingmate
end
