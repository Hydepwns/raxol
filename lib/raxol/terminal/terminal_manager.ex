defmodule Raxol.Terminal.Manager do
  @moduledoc """
  Terminal manager module.

  This module manages terminal sessions, including:
  - Session creation
  - Session destruction
  - Session listing
  - Session monitoring

  ## Event Handling and Notification System

  The manager processes terminal events using pattern matching on the canonical `Raxol.Core.Events.Event` struct. Each event type (e.g., `:window`, `:mode`, `:focus`, `:clipboard`, `:selection`, `:paste`, `:cursor`, `:scroll`) is handled with clear, semantic matches on the expected data fields.

  For each event, the manager:
  - Updates the terminal state as needed
  - Notifies the runtime process (if present) via message passing
  - Logs the event using `Raxol.Core.Runtime.Log`
  - Emits a Telemetry event for observability
  - Calls a user-defined callback module (if provided)

  ## Extending Event Handling

  To add a new event type:

  1. Add a new clause in the `handle_call({:process_event, %Raxol.Core.Events.Event{type: ..., data: ...}}, ...)` function.
  2. Add a corresponding notification helper (e.g., `notify_new_event/2`) if needed.
  3. Ensure the notification helper sends a message, logs, emits telemetry, and calls the callback module if present.

  ## User-defined Callback Modules

  You can pass a `:callback_module` option to `start_link/1` to receive notifications for terminal events. The callback module must implement the `Raxol.Terminal.Manager.Callback` behaviour:

  ```elixir
  defmodule MyTerminalCallback do
    @behaviour Raxol.Terminal.Manager.Callback

    # ...implement other callbacks as needed
  end

  {:ok, pid} = Raxol.Terminal.Manager.start_link(callback_module: MyTerminalCallback)
  ```

  ## Telemetry Events

  Each notification emits a telemetry event under the `[:raxol, :terminal, ...]` prefix. You can attach handlers for metrics, tracing, or custom logic.

  ## Logging

  All notifications are logged at the info level for easy debugging and auditability.

  """

  use Raxol.Core.Behaviours.BaseManager


  require Raxol.Core.Runtime.Log
  require Logger

  alias Raxol.Terminal.Manager.{
    EventHandler,
    ScreenHandler,
    SessionHandler
  }

  alias Raxol.Terminal.Emulator

  @type t :: %__MODULE__{
          sessions: map(),
          terminal: Emulator.t() | nil,
          runtime_pid: pid() | nil,
          callback_module: module() | nil
        }

  defstruct [
    :sessions,
    :terminal,
    :runtime_pid,
    :callback_module
  ]

  @doc """
  Starts the terminal manager.

  ## Options
    * `:terminal` - The initial terminal emulator state (required for single-terminal mode)
    * `:runtime_pid` - The runtime process PID (optional)
    * `:callback_module` - The callback module for the manager (optional)

  ## Examples
      iex> {:ok, pid} = Manager.start_link(terminal: term, runtime_pid: self())
      iex> Process.alive?(pid)
      true
  """
  def start_link_custom(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    gen_server_opts = Keyword.delete(opts, :name)

    _state = %{
      sessions: %{},
      terminal: Keyword.get(gen_server_opts, :terminal),
      runtime_pid: Keyword.get(gen_server_opts, :runtime_pid),
      callback_module: Keyword.get(gen_server_opts, :callback_module)
    }

    # Use BaseManager's start_link with proper options
    __MODULE__.start_link(Keyword.put(gen_server_opts, :name, name))
  end

  @doc """
  Creates a new terminal session.

  ## Examples

      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id} = Manager.create_session(pid, %{width: 80, height: 24})
      iex> binary?(session_id)
      true
  """
  def create_session(pid \\ __MODULE__, opts \\ []) do
    GenServer.call(pid, {:create_session, opts})
  end

  @doc """
  Destroys a terminal session.

  ## Examples

      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id} = Manager.create_session(pid)
      iex> :ok = Manager.destroy_session(pid, session_id)
      iex> Manager.get_session(pid, session_id)
      {:error, :not_found}
  """
  def destroy_session(pid \\ __MODULE__, session_id) do
    GenServer.call(pid, {:destroy_session, session_id})
  end

  @doc """
  Gets a terminal session by ID.

  ## Examples

      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id} = Manager.create_session(pid)
      iex> {:ok, session} = Manager.get_session(pid, session_id)
      iex> session.id
      session_id
  """
  def get_session(pid \\ __MODULE__, session_id) do
    GenServer.call(pid, {:get_session, session_id})
  end

  @doc """
  Lists all terminal sessions.

  ## Examples

      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id1} = Manager.create_session(pid)
      iex> {:ok, session_id2} = Manager.create_session(pid)
      iex> sessions = Manager.list_sessions(pid)
      iex> length(sessions)
      2
  """
  def list_sessions(pid \\ __MODULE__) do
    GenServer.call(pid, :list_sessions)
  end

  @doc """
  Gets the count of terminal sessions.

  ## Examples

      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, _} = Manager.create_session(pid)
      iex> {:ok, _} = Manager.create_session(pid)
      iex> Manager.count_sessions(pid)
      2
  """
  def count_sessions(pid \\ __MODULE__) do
    GenServer.call(pid, :count_sessions)
  end

  @doc """
  Monitors a terminal session.

  ## Examples

      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id} = Manager.create_session(pid)
      iex> :ok = Manager.monitor_session(pid, session_id)
      iex> Process.whereis({:via, Registry, {Registry, session_id}})
      #PID<0.123.0>
  """
  def monitor_session(pid \\ __MODULE__, session_id) do
    GenServer.call(pid, {:monitor_session, session_id})
  end

  @doc """
  Unmonitors a terminal session.

  ## Examples

      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id} = Manager.create_session(pid)
      iex> :ok = Manager.monitor_session(pid, session_id)
      iex> :ok = Manager.unmonitor_session(pid, session_id)
      iex> Process.whereis({:via, Registry, {Registry, session_id}})
      nil
  """
  def unmonitor_session(pid \\ __MODULE__, session_id) do
    GenServer.call(pid, {:unmonitor_session, session_id})
  end

  @doc """
  Processes a terminal event.

  ## Examples

      iex> {:ok, pid} = Manager.start_link()
      iex> event = %Raxol.Core.Events.Event{type: :focus, data: %{focused: true}}
      iex> :ok = Manager.process_event(pid, event)
  """
  def process_event(pid \\ __MODULE__, event) do
    GenServer.call(pid, {:process_event, event})
  end

  @doc """
  Gets the current terminal state.

  ## Examples

      iex> {:ok, pid} = Manager.start_link(terminal: %{width: 80, height: 24})
      iex> state = Manager.get_terminal_state(pid)
      iex> state.width
      80
  """
  def get_terminal_state(pid \\ __MODULE__) do
    GenServer.call(pid, :get_terminal_state)
  end

  @doc """
  Updates the terminal screen.

  ## Examples

      iex> {:ok, pid} = Manager.start_link()
      iex> update = %{type: :clear_screen}
      iex> :ok = Manager.update_screen(pid, update)
  """
  def update_screen(pid \\ __MODULE__, update) do
    GenServer.call(pid, {:update_screen, update})
  end

  @doc """
  Updates the terminal screen with multiple updates in a batch.

  ## Examples

      iex> {:ok, pid} = Manager.start_link()
      iex> updates = [%{type: :clear_screen}, %{type: :set_cursor, x: 0, y: 0}]
      iex> :ok = Manager.batch_update_screen(pid, updates)
  """
  def batch_update_screen(pid \\ __MODULE__, updates) do
    GenServer.call(pid, {:batch_update_screen, updates})
  end

  # Callbacks

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    # Convert keyword list to map and merge with defaults (defaults first, then overrides)
    init_state =
      %{sessions: %{}, terminal: nil, runtime_pid: nil, callback_module: nil}
      |> Map.merge(Enum.into(opts, %{}))

    {:ok, init_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:create_session, opts}, _from, state) do
    case SessionHandler.create_session(opts, state) do
      {:ok, session_id, new_state} -> {:reply, {:ok, session_id}, new_state}
      error -> {:reply, error, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:destroy_session, session_id}, _from, state) do
    case SessionHandler.destroy_session(session_id, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      error -> {:reply, error, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get_session, session_id}, _from, state) do
    case SessionHandler.get_session(session_id, state) do
      {:ok, session_state} -> {:reply, {:ok, session_state}, state}
      error -> {:reply, error, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:list_sessions, _from, state) do
    sessions = SessionHandler.list_sessions(state)
    {:reply, sessions, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:count_sessions, _from, state) do
    count = SessionHandler.count_sessions(state)
    {:reply, count, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:monitor_session, session_id}, _from, state) do
    case SessionHandler.monitor_session(session_id, state) do
      :ok -> {:reply, :ok, state}
      error -> {:reply, error, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:unmonitor_session, session_id}, _from, state) do
    case SessionHandler.unmonitor_session(session_id, state) do
      :ok -> {:reply, :ok, state}
      error -> {:reply, error, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:process_event, event}, _from, state) do
    case EventHandler.process_event(event, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        # Send error notification if runtime_pid is present
        case state.runtime_pid do
          nil ->
            :ok

          runtime_pid ->
            send(
              runtime_pid,
              {:terminal_error, reason, %{action: :process_event, event: event}}
            )
        end

        {:reply, error, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:update_screen, update}, _from, state) do
    case ScreenHandler.process_update(update, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      error -> {:reply, error, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:batch_update_screen, updates}, _from, state) do
    case ScreenHandler.process_batch_updates(updates, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      error -> {:reply, error, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_terminal_state, _from, state) do
    case state.runtime_pid do
      nil ->
        :ok

      runtime_pid ->
        send(runtime_pid, {:terminal_state_queried, state.terminal})
    end

    {:reply, state.terminal, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:update_state, new_state}, _from, _state) do
    struct_state =
      case new_state do
        %__MODULE__{} = s -> s
        map when is_map(map) -> struct(__MODULE__, map)
      end

    {:reply, :ok, struct_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info({:DOWN, _ref, :process, pid, _reason}, state) do
    new_state = SessionHandler.handle_session_down(pid, state)
    {:noreply, new_state}
  end

end

defmodule Raxol.Terminal.Manager.Callback do
  @moduledoc """
  Behaviour for terminal manager event callbacks. Implement this behaviour to receive notifications for terminal events.
  """
  @callback focus_changed(focused :: boolean(), state :: map()) :: any()
  @callback resized(width :: integer(), height :: integer(), state :: map()) ::
              any()
  @callback mode_changed(mode :: atom(), state :: map()) :: any()
  @callback clipboard_event(op :: atom(), content :: any(), state :: map()) ::
              any()
  @callback selection_changed(selection :: map(), state :: map()) :: any()
  @callback paste_event(
              text :: String.t(),
              pos :: {integer(), integer()},
              state :: map()
            ) :: any()
  @callback cursor_event(cursor :: map(), state :: map()) :: any()
  @callback scroll_event(
              dir :: atom(),
              delta :: integer(),
              pos :: {integer(), integer()},
              state :: map()
            ) :: any()
end
