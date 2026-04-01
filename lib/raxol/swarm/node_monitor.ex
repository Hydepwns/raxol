defmodule Raxol.Swarm.NodeMonitor do
  @moduledoc """
  Health and latency tracking for cluster nodes.

  Monitors nodes via `:net_kernel.monitor_nodes/1`, pings at a
  configurable interval, and maintains RTT history per node. Notifies
  subscribers on status changes (healthy -> suspect -> down).
  """

  use GenServer

  require Logger

  @default_ping_interval_ms Raxol.Core.Defaults.monitor_interval_ms()
  @rtt_history_size 60
  @suspect_threshold_ms 5_000
  @down_threshold_ms Raxol.Core.Defaults.health_check_interval_ms()

  @type status :: :healthy | :suspect | :down

  @type health_record :: %{
          node: node(),
          rtt_history: [float()],
          avg_rtt_ms: float(),
          last_seen: integer(),
          status: status(),
          joined_at: integer()
        }

  @type t :: %__MODULE__{
          nodes: %{node() => health_record()},
          ping_interval_ms: pos_integer(),
          subscribers: [pid()],
          ping_ref: reference() | nil
        }

  defstruct nodes: %{},
            ping_interval_ms: @default_ping_interval_ms,
            subscribers: [],
            ping_ref: nil

  # -- Public API --

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec get_health(GenServer.server(), node()) ::
          {:ok, health_record()} | {:error, :unknown}
  def get_health(server \\ __MODULE__, node) do
    GenServer.call(server, {:get_health, node})
  end

  @spec list_healthy(GenServer.server()) :: [node()]
  def list_healthy(server \\ __MODULE__) do
    GenServer.call(server, :list_healthy)
  end

  @spec list_suspect(GenServer.server()) :: [node()]
  def list_suspect(server \\ __MODULE__) do
    GenServer.call(server, :list_suspect)
  end

  @spec list_all(GenServer.server()) :: [health_record()]
  def list_all(server \\ __MODULE__) do
    GenServer.call(server, :list_all)
  end

  @spec subscribe(GenServer.server()) :: :ok
  def subscribe(server \\ __MODULE__) do
    GenServer.call(server, {:subscribe, self()})
  end

  @spec unsubscribe(GenServer.server()) :: :ok
  def unsubscribe(server \\ __MODULE__) do
    GenServer.call(server, {:unsubscribe, self()})
  end

  # -- Callbacks --

  @impl true
  def init(opts) do
    ping_interval =
      Keyword.get(opts, :ping_interval_ms, @default_ping_interval_ms)

    _ = :net_kernel.monitor_nodes(true)

    nodes =
      Node.list()
      |> Map.new(fn node -> {node, new_health_record(node)} end)

    state = %__MODULE__{
      ping_interval_ms: ping_interval,
      nodes: nodes
    }

    {:ok, schedule_ping(state)}
  end

  @impl true
  def handle_call({:get_health, node}, _from, state) do
    case Map.get(state.nodes, node) do
      nil -> {:reply, {:error, :unknown}, state}
      record -> {:reply, {:ok, record}, state}
    end
  end

  @impl true
  def handle_call(:list_healthy, _from, state) do
    healthy =
      for {node, %{status: :healthy}} <- state.nodes, do: node

    {:reply, healthy, state}
  end

  @impl true
  def handle_call(:list_suspect, _from, state) do
    suspect =
      for {node, %{status: :suspect}} <- state.nodes, do: node

    {:reply, suspect, state}
  end

  @impl true
  def handle_call(:list_all, _from, state) do
    {:reply, Map.values(state.nodes), state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, %__MODULE__{} = state) do
    Process.monitor(pid)
    {:reply, :ok, %__MODULE__{state | subscribers: [pid | state.subscribers]}}
  end

  @impl true
  def handle_call({:unsubscribe, pid}, _from, %__MODULE__{} = state) do
    {:reply, :ok,
     %__MODULE__{state | subscribers: List.delete(state.subscribers, pid)}}
  end

  @impl true
  def handle_info({:nodeup, node}, %__MODULE__{} = state) do
    Logger.info("Swarm: node up: #{node}")
    record = new_health_record(node)
    state = %__MODULE__{state | nodes: Map.put(state.nodes, node, record)}
    notify_subscribers(state.subscribers, {:node_up, node})
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node}, %__MODULE__{} = state) do
    Logger.info("Swarm: node down: #{node}")

    state =
      case Map.get(state.nodes, node) do
        nil ->
          state

        record ->
          record = %{record | status: :down}
          %__MODULE__{state | nodes: Map.put(state.nodes, node, record)}
      end

    notify_subscribers(state.subscribers, {:node_down, node})
    {:noreply, state}
  end

  @impl true
  def handle_info(:ping, %__MODULE__{} = state) do
    old_nodes = state.nodes

    nodes =
      Map.new(old_nodes, fn {node, record} ->
        {node, ping_node(node, record)}
      end)

    state = %__MODULE__{state | nodes: nodes}

    Enum.each(nodes, fn {node, new_record} ->
      old_record = Map.get(old_nodes, node)

      if old_record && old_record.status != new_record.status do
        notify_subscribers(
          state.subscribers,
          {:status_change, node, old_record.status, new_record.status}
        )
      end
    end)

    {:noreply, schedule_ping(state)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %__MODULE__{} = state) do
    {:noreply,
     %__MODULE__{state | subscribers: List.delete(state.subscribers, pid)}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("#{__MODULE__} received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    _ = :net_kernel.monitor_nodes(false)
    :ok
  end

  # -- Private --

  defp new_health_record(node) do
    now = System.monotonic_time(:millisecond)

    %{
      node: node,
      rtt_history: [],
      avg_rtt_ms: 0.0,
      last_seen: now,
      status: :healthy,
      joined_at: now
    }
  end

  defp ping_node(node, record) do
    before = System.monotonic_time(:millisecond)

    case :net_adm.ping(node) do
      :pong ->
        rtt = System.monotonic_time(:millisecond) - before
        rtt_history = Enum.take([rtt | record.rtt_history], @rtt_history_size)
        avg_rtt = Enum.sum(rtt_history) / length(rtt_history)

        %{
          record
          | rtt_history: rtt_history,
            avg_rtt_ms: avg_rtt,
            last_seen: before,
            status: :healthy
        }

      :pang ->
        age_ms = before - record.last_seen
        status = classify_status(age_ms)
        %{record | status: status}
    end
  end

  defp classify_status(age_ms) when age_ms < @suspect_threshold_ms, do: :healthy
  defp classify_status(age_ms) when age_ms < @down_threshold_ms, do: :suspect
  defp classify_status(_age_ms), do: :down

  defp schedule_ping(%__MODULE__{} = state) do
    _ = if state.ping_ref, do: Process.cancel_timer(state.ping_ref)
    ref = Process.send_after(self(), :ping, state.ping_interval_ms)
    %__MODULE__{state | ping_ref: ref}
  end

  defp notify_subscribers(subscribers, event) do
    Enum.each(subscribers, fn pid -> send(pid, {:swarm_event, event}) end)
  end
end
