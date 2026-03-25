defmodule Raxol.Agent.Orchestrator do
  @moduledoc """
  Coordinates multiple AI agents in the cockpit.

  Manages pane layout, routes pilot input to the focused pane,
  handles agent spawning/killing, and implements the takeover/release
  protocol.

  Pilot modes:
  - `:observe` -- watching agents work (default)
  - `:command` -- sending directives to agents
  - `:takeover` -- directly controlling an agent's terminal
  """

  use GenServer

  require Raxol.Core.Runtime.Log

  alias Raxol.Agent.Process, as: AgentProcess
  alias Raxol.Agent.Protocol

  defstruct agents: %{},
            pane_layout: %{},
            focused_pane: nil,
            pilot_mode: :observe,
            event_log: []

  @type t :: %__MODULE__{
          agents: %{atom() => pid()},
          pane_layout: %{atom() => map()},
          focused_pane: atom() | nil,
          pilot_mode: :observe | :command | :takeover,
          event_log: [term()]
        }

  @max_event_log 200
  @default_pane_position %{x: 0, y: 0}
  @default_pane_dimensions %{width: 80, height: 24}

  # -- Client API --------------------------------------------------------------

  @doc "Start the orchestrator."
  @spec start_link(keyword()) :: {:ok, pid()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts,
      name: {:via, Registry, {Raxol.Agent.Registry, :orchestrator}}
    )
  end

  @doc "Spawn a new agent and assign it a pane."
  @spec spawn_agent(pid(), atom(), module(), keyword()) ::
          {:ok, atom()} | {:error, term()}
  def spawn_agent(orchestrator, agent_id, agent_module, opts \\ []) do
    GenServer.call(orchestrator, {:spawn_agent, agent_id, agent_module, opts})
  end

  @doc "Kill an agent and remove its pane."
  @spec kill_agent(pid(), atom()) :: :ok
  def kill_agent(orchestrator, agent_id) do
    GenServer.call(orchestrator, {:kill_agent, agent_id})
  end

  @doc "Switch pilot focus to a different pane."
  @spec focus_pane(pid(), atom()) :: :ok
  def focus_pane(orchestrator, pane_id) do
    GenServer.call(orchestrator, {:focus_pane, pane_id})
  end

  @doc "Pilot takes over the focused agent's terminal."
  @spec pilot_takeover(pid()) :: :ok | {:error, term()}
  def pilot_takeover(orchestrator) do
    GenServer.call(orchestrator, :pilot_takeover)
  end

  @doc "Pilot releases the taken-over agent's terminal."
  @spec pilot_release(pid()) :: :ok | {:error, term()}
  def pilot_release(orchestrator) do
    GenServer.call(orchestrator, :pilot_release)
  end

  @doc "Route pilot input to the focused pane's agent (during takeover)."
  @spec send_input(pid(), term()) :: :ok | {:error, term()}
  def send_input(orchestrator, input) do
    GenServer.call(orchestrator, {:send_input, input})
  end

  @doc "Send a directive to a specific agent."
  @spec send_directive(pid(), atom(), term()) :: :ok | {:error, term()}
  def send_directive(orchestrator, agent_id, directive) do
    GenServer.call(orchestrator, {:send_directive, agent_id, directive})
  end

  @doc "Broadcast a directive to all agents."
  @spec broadcast_directive(pid(), term()) :: :ok
  def broadcast_directive(orchestrator, directive) do
    GenServer.cast(orchestrator, {:broadcast_directive, directive})
  end

  @doc "Get the current layout and agent status."
  @spec get_layout(pid()) :: map()
  def get_layout(orchestrator) do
    GenServer.call(orchestrator, :get_layout)
  end

  @doc "Get all agent statuses."
  @spec get_statuses(pid()) :: map()
  def get_statuses(orchestrator) do
    GenServer.call(orchestrator, :get_statuses)
  end

  # -- Server ------------------------------------------------------------------

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:spawn_agent, agent_id, agent_module, opts}, _from, state) do
    if Map.has_key?(state.agents, agent_id) do
      {:reply, {:error, :already_exists}, state}
    else
      agent_opts =
        Keyword.merge(opts,
          agent_id: agent_id,
          agent_module: agent_module,
          pane_id: agent_id
        )

      case DynamicSupervisor.start_child(
             Raxol.Agent.DynSup,
             {AgentProcess, agent_opts}
           ) do
        {:ok, pid} ->
          pane = %{
            agent_id: agent_id,
            agent_pid: pid,
            position: Keyword.get(opts, :position, @default_pane_position),
            dimensions:
              Keyword.get(opts, :dimensions, @default_pane_dimensions),
            terminal_pid: Keyword.get(opts, :terminal_pid),
            buffer_pid: Keyword.get(opts, :buffer_pid),
            label: Keyword.get(opts, :label, to_string(agent_id))
          }

          state = %{
            state
            | agents: Map.put(state.agents, agent_id, pid),
              pane_layout: Map.put(state.pane_layout, agent_id, pane)
          }

          state =
            if is_nil(state.focused_pane) do
              %{state | focused_pane: agent_id}
            else
              state
            end

          state = log_event(state, {:agent_spawned, agent_id})
          {:reply, {:ok, agent_id}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  def handle_call({:kill_agent, agent_id}, _from, state) do
    case Map.get(state.agents, agent_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      pid ->
        _ = DynamicSupervisor.terminate_child(Raxol.Agent.DynSup, pid)

        state = %{
          state
          | agents: Map.delete(state.agents, agent_id),
            pane_layout: Map.delete(state.pane_layout, agent_id)
        }

        state =
          if state.focused_pane == agent_id do
            next = state.agents |> Map.keys() |> List.first()
            %{state | focused_pane: next, pilot_mode: :observe}
          else
            state
          end

        state = log_event(state, {:agent_killed, agent_id})
        {:reply, :ok, state}
    end
  end

  def handle_call({:focus_pane, pane_id}, _from, state) do
    if Map.has_key?(state.pane_layout, pane_id) do
      {:reply, :ok, %{state | focused_pane: pane_id}}
    else
      {:reply, {:error, :pane_not_found}, state}
    end
  end

  def handle_call(:pilot_takeover, _from, state) do
    case state.focused_pane do
      nil ->
        {:reply, {:error, :no_focused_pane}, state}

      pane_id ->
        case Map.get(state.agents, pane_id) do
          nil ->
            {:reply, {:error, :agent_not_found}, state}

          pid ->
            _ = AgentProcess.takeover(pid)

            state =
              %{state | pilot_mode: :takeover}
              |> log_event({:pilot_takeover, pane_id})

            {:reply, :ok, state}
        end
    end
  end

  def handle_call(:pilot_release, _from, state) do
    case state.focused_pane do
      nil ->
        {:reply, {:error, :no_focused_pane}, state}

      pane_id ->
        case Map.get(state.agents, pane_id) do
          nil ->
            {:reply, {:error, :agent_not_found}, state}

          pid ->
            _ = AgentProcess.release(pid)

            state =
              %{state | pilot_mode: :observe}
              |> log_event({:pilot_release, pane_id})

            {:reply, :ok, state}
        end
    end
  end

  def handle_call({:send_input, input}, _from, state) do
    case {state.pilot_mode, state.focused_pane} do
      {:takeover, pane_id} when not is_nil(pane_id) ->
        case Map.get(state.pane_layout, pane_id) do
          %{terminal_pid: terminal_pid} when is_pid(terminal_pid) ->
            AgentProcess.push_event(
              Map.get(state.agents, pane_id),
              {:pilot_input, input}
            )

            {:reply, :ok, state}

          _ ->
            {:reply, {:error, :no_terminal}, state}
        end

      {:takeover, nil} ->
        {:reply, {:error, :no_focused_pane}, state}

      _ ->
        {:reply, {:error, :not_in_takeover}, state}
    end
  end

  def handle_call({:send_directive, agent_id, directive}, _from, state) do
    case Map.get(state.agents, agent_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      pid ->
        AgentProcess.send_directive(pid, directive)
        {:reply, :ok, state}
    end
  end

  def handle_call(:get_layout, _from, state) do
    layout = %{
      panes: state.pane_layout,
      focused: state.focused_pane,
      pilot_mode: state.pilot_mode,
      agent_count: map_size(state.agents)
    }

    {:reply, layout, state}
  end

  def handle_call(:get_statuses, _from, state) do
    statuses =
      state.agents
      |> Enum.map(fn {agent_id, pid} ->
        status =
          if Process.alive?(pid) do
            AgentProcess.get_status(pid)
          else
            %{status: :dead}
          end

        {agent_id, status}
      end)
      |> Map.new()

    {:reply, statuses, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, {:error, :unknown_call}, state}
  end

  @impl true
  def handle_cast({:broadcast_directive, directive}, state) do
    Enum.each(state.agents, fn {_id, pid} ->
      AgentProcess.send_directive(pid, directive)
    end)

    {:noreply, state}
  end

  def handle_cast(_msg, state), do: {:noreply, state}

  @impl true
  def handle_info({:agent_query, agent_id, %Protocol{} = msg}, state) do
    Raxol.Core.Runtime.Log.info(
      "[Orchestrator] Agent #{agent_id} asks pilot: #{inspect(msg.payload)}"
    )

    state = log_event(state, {:agent_query, agent_id, msg.payload})
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case Enum.find(state.agents, fn {_, p} -> p == pid end) do
      {agent_id, _} ->
        Raxol.Core.Runtime.Log.warning(
          "[Orchestrator] Agent #{agent_id} died: #{inspect(reason)}"
        )

        state = %{state | agents: Map.delete(state.agents, agent_id)}
        {:noreply, state}

      nil ->
        {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # -- Private -----------------------------------------------------------------

  defp log_event(state, event) do
    entry = {event, DateTime.utc_now()}
    %{state | event_log: [entry | state.event_log] |> Enum.take(@max_event_log)}
  end
end
