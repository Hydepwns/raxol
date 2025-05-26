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
  - Logs the event using `Logger`
  - Emits a Telemetry event for observability
  - Calls a user-defined callback module (if provided)

  ## Extending Event Handling

  To add a new event type:

  1. Add a new clause in the `handle_call({:process_event, %Raxol.Core.Events.Event{type: ..., data: ...}}, ...)` function.
  2. Add a corresponding notification helper (e.g., `notify_new_event/2`) if needed.
  3. Ensure the notification helper sends a message, logs, emits telemetry, and calls the callback module if present.

  ## User-defined Callback Modules

  You can pass a `:callback_module` option to `start_link/1` to receive notifications for terminal events. The callback module must implement the `Raxol.Terminal.Manager.Callback` behaviour:

      defmodule MyTerminalCallback do
        @behaviour Raxol.Terminal.Manager.Callback

        def focus_changed(focused, _state), do: IO.inspect({:focus, focused})
        def resized(w, h, _state), do: IO.inspect({:resize, w, h})
        # ...implement other callbacks as needed
      end

      {:ok, pid} = Raxol.Terminal.Manager.start_link(callback_module: MyTerminalCallback)

  ## Telemetry Events

  Each notification emits a telemetry event under the `[:raxol, :terminal, ...]` prefix. You can attach handlers for metrics, tracing, or custom logic.

  ## Logging

  All notifications are logged at the info level for easy debugging and auditability.

  """

  use GenServer

  require Raxol.Core.Runtime.Log
  require Raxol.Core.Runtime.Telemetry

  alias Raxol.Terminal.Session
  # alias Raxol.Terminal.{Session, Registry} # Registry unused

  @type t :: %__MODULE__{
          sessions: map(),
          terminal: Raxol.Terminal.Emulator.t() | nil,
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
  def start_link(opts \\ []) do
    # Support both legacy and new API
    state = %{
      sessions: %{},
      terminal: Keyword.get(opts, :terminal),
      runtime_pid: Keyword.get(opts, :runtime_pid),
      callback_module: Keyword.get(opts, :callback_module)
    }
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @doc """
  Creates a new terminal session.

  ## Examples

      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id} = Manager.create_session(pid, %{width: 80, height: 24})
      iex> is_binary(session_id)
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

  # Callbacks

  @impl true
  def init(state) do
    # Accept initial state for single-terminal mode
    {:ok, Map.merge(%{sessions: %{}, terminal: nil, runtime_pid: nil, callback_module: nil}, state)}
  end

  @impl true
  def handle_call({:create_session, opts}, _from, state) do
    case Session.start_link(opts) do
      {:ok, pid} ->
        session_id = UUID.uuid4()
        new_state = %{state | sessions: Map.put(state.sessions, session_id, pid)}
        if state.runtime_pid, do: send(state.runtime_pid, {:terminal_session_created, session_id, pid})
        {:reply, {:ok, session_id}, new_state}
      error ->
        if state.runtime_pid, do: send(state.runtime_pid, {:terminal_error, error, %{action: :create_session, opts: opts}})
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:destroy_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        if state.runtime_pid, do: send(state.runtime_pid, {:terminal_error, :not_found, %{action: :destroy_session, session_id: session_id}})
        {:reply, {:error, :not_found}, state}
      pid ->
        Session.stop(pid)
        new_state = %{state | sessions: Map.delete(state.sessions, session_id)}
        if state.runtime_pid, do: send(state.runtime_pid, {:terminal_session_destroyed, session_id})
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        if state.runtime_pid, do: send(state.runtime_pid, {:terminal_error, :not_found, %{action: :get_session, session_id: session_id}})
        {:reply, {:error, :not_found}, state}
      pid ->
        session_state = Session.get_state(pid)
        {:reply, {:ok, session_state}, state}
    end
  end

  @impl true
  def handle_call(:list_sessions, _from, state) do
    sessions =
      state.sessions
      |> Enum.map(fn {id, pid} ->
        {id, Session.get_state(pid)}
      end)
      |> Map.new()

    {:reply, sessions, state}
  end

  @impl true
  def handle_call(:count_sessions, _from, state) do
    {:reply, map_size(state.sessions), state}
  end

  @impl true
  def handle_call({:monitor_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      pid ->
        Process.monitor(pid)
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:unmonitor_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      pid ->
        Process.demonitor(pid)
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:update_state, new_state}, _from, _state) do
    if new_state[:runtime_pid], do: send(new_state[:runtime_pid], {:terminal_state_updated, new_state})
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove the session from our state
    new_state = %{
      state
      | sessions:
          state.sessions
          |> Enum.reject(fn {_id, p} -> p == pid end)
          |> Map.new()
    }

    {:noreply, new_state}
  end

  def get_state do
    GenServer.call(__MODULE__, {:get_state})
  end

  def update_state(new_state) do
    GenServer.call(__MODULE__, {:update_state, new_state})
  end

  # --- Single-terminal API ---
  @doc """
  Processes an event (e.g., key, mouse, window) and updates the terminal state.
  Returns :ok.
  """
  def process_event(pid, event) do
    GenServer.call(pid, {:process_event, event})
  end

  @doc """
  Updates the screen buffer or emulator state with a given update map or a list of updates.
  Returns :ok.
  """
  @spec update_screen(pid(), map() | [map()]) :: :ok | {:error, any()}
  def update_screen(pid, updates) when is_list(updates) do
    GenServer.call(pid, {:batch_update_screen, updates})
  end
  def update_screen(pid, update) when is_map(update) do
    GenServer.call(pid, {:update_screen, update})
  end

  @doc """
  Returns the current terminal emulator state.
  """
  def get_terminal_state(pid) do
    GenServer.call(pid, :get_terminal_state)
  end

  @impl true
  def handle_call({:process_event, %Raxol.Core.Events.Event{type: type, data: data} = event}, _from, state) do
    case state.terminal do
      %Raxol.Terminal.Emulator{} = emulator ->
        {new_emulator, _output} = Raxol.Terminal.Emulator.process_input(emulator, event)
        if state.runtime_pid, do: send(state.runtime_pid, {:terminal_event_processed, event, new_emulator})
        # Refined event detection
        case type do
          :window ->
            case data do
              %{action: :resize, width: w, height: h} when is_integer(w) and is_integer(h) ->
                notify_resized(state, w, h)
              %{action: :focus, focused: focused?} ->
                notify_focus_changed(state, focused?)
              %{action: :blur} ->
                notify_focus_changed(state, false)
              _ -> :ok
            end
          :mode ->
            case data do
              %{mode: new_mode} -> notify_mode_changed(state, new_mode)
              _ -> :ok
            end
          :focus ->
            case data do
              %{focused: focused?} -> notify_focus_changed(state, focused?)
              _ -> :ok
            end
          :clipboard ->
            case data do
              %{op: op, content: content} -> notify_clipboard_event(state, op, content)
              _ -> :ok
            end
          :selection ->
            case data do
              %{start_pos: _, end_pos: _, text: _} = selection -> notify_selection_changed(state, selection)
              %{selection: selection} -> notify_selection_changed(state, selection)
              _ -> :ok
            end
          :paste ->
            case data do
              %{text: text, position: pos} -> notify_paste_event(state, text, pos)
              _ -> :ok
            end
          :cursor ->
            case data do
              %{visible: _, style: _, blink: _, position: _} = cursor -> notify_cursor_event(state, cursor)
              _ -> :ok
            end
          :scroll ->
            case data do
              %{direction: dir, delta: delta, position: pos} -> notify_scroll_event(state, dir, delta, pos)
              _ -> :ok
            end
          _ -> :ok
        end
        {:reply, :ok, %{state | terminal: new_emulator}}
      _ ->
        if state.runtime_pid, do: send(state.runtime_pid, {:terminal_error, :no_terminal, %{action: :process_event, event: event}})
        {:reply, {:error, :no_terminal}, state}
    end
  end

  @impl true
  def handle_call({:update_screen, update}, _from, state) do
    case state.terminal do
      %Raxol.Terminal.Emulator{} = emulator ->
        buffer = Raxol.Terminal.Emulator.get_active_buffer(emulator)
        buffer =
          if Map.has_key?(update, :x) and Map.has_key?(update, :y) and Map.has_key?(update, :char) do
            Raxol.Terminal.ScreenBuffer.write_char(buffer, update.x, update.y, update.char, Raxol.Terminal.ANSI.TextFormatting.new())
          else
            buffer
          end
        new_emulator = Raxol.Terminal.Emulator.update_active_buffer(emulator, buffer)
        if state.runtime_pid, do: send(state.runtime_pid, {:terminal_screen_updated, [update], new_emulator})
        # Detect resize if update includes width/height
        if Map.has_key?(update, :width) and Map.has_key?(update, :height) do
          notify_resized(state, update.width, update.height)
        end
        {:reply, :ok, %{state | terminal: new_emulator}}
      _ ->
        if state.runtime_pid, do: send(state.runtime_pid, {:terminal_error, :no_terminal, %{action: :update_screen, update: update}})
        {:reply, {:error, :no_terminal}, state}
    end
  end

  @impl true
  def handle_call(:get_terminal_state, _from, state) do
    if state.runtime_pid, do: send(state.runtime_pid, {:terminal_state_queried, state.terminal})
    {:reply, state.terminal, state}
  end

  @impl true
  def handle_call({:batch_update_screen, updates}, _from, state) do
    case state.terminal do
      %Raxol.Terminal.Emulator{} = emulator ->
        buffer = Raxol.Terminal.Emulator.get_active_buffer(emulator)
        buffer = Enum.reduce(updates, buffer, fn update, buf ->
          if Map.has_key?(update, :x) and Map.has_key?(update, :y) and Map.has_key?(update, :char) do
            Raxol.Terminal.ScreenBuffer.write_char(buf, update.x, update.y, update.char, Raxol.Terminal.ANSI.TextFormatting.new())
          else
            buf
          end
        end)
        new_emulator = Raxol.Terminal.Emulator.update_active_buffer(emulator, buffer)
        if state.runtime_pid, do: send(state.runtime_pid, {:terminal_screen_updated, updates, new_emulator})
        # Detect resize if any update includes width/height
        Enum.each(updates, fn update ->
          if Map.has_key?(update, :width) and Map.has_key?(update, :height) do
            notify_resized(state, update.width, update.height)
          end
        end)
        {:reply, :ok, %{state | terminal: new_emulator}}
      _ ->
        if state.runtime_pid, do: send(state.runtime_pid, {:terminal_error, :no_terminal, %{action: :batch_update_screen, updates: updates}})
        {:reply, {:error, :no_terminal}, state}
    end
  end

  # --- Notification stubs for future focus/resize/mode/clipboard/selection events ---
  # Call these from appropriate places in the future as needed.

  defp notify_focus_changed(state, focused?) do
    if state.runtime_pid, do: send(state.runtime_pid, {:terminal_focus_changed, focused?})
    Raxol.Core.Runtime.Log.info("Terminal focus changed: #{inspect(focused?)}")
    :telemetry.execute([:raxol, :terminal, :focus_changed], %{focused: focused?}, %{pid: self()})
    if state.callback_module, do: apply(state.callback_module, :focus_changed, [focused?, state])
  end

  defp notify_resized(state, width, height) do
    if state.runtime_pid, do: send(state.runtime_pid, {:terminal_resized, width, height})
    Raxol.Core.Runtime.Log.info("Terminal resized: #{width}x#{height}")
    :telemetry.execute([:raxol, :terminal, :resized], %{width: width, height: height}, %{pid: self()})
    if state.callback_module, do: apply(state.callback_module, :resized, [width, height, state])
  end

  defp notify_mode_changed(state, new_mode) do
    if state.runtime_pid, do: send(state.runtime_pid, {:terminal_mode_changed, new_mode})
    Raxol.Core.Runtime.Log.info("Terminal mode changed: #{inspect(new_mode)}")
    :telemetry.execute([:raxol, :terminal, :mode_changed], %{mode: new_mode}, %{pid: self()})
    if state.callback_module, do: apply(state.callback_module, :mode_changed, [new_mode, state])
  end

  defp notify_clipboard_event(state, type, data) do
    if state.runtime_pid, do: send(state.runtime_pid, {:terminal_clipboard_event, type, data})
    Raxol.Core.Runtime.Log.info("Terminal clipboard event: #{inspect(type)} #{inspect(data)}")
    :telemetry.execute([:raxol, :terminal, :clipboard_event], %{op: type, content: data}, %{pid: self()})
    if state.callback_module, do: apply(state.callback_module, :clipboard_event, [type, data, state])
  end

  defp notify_selection_changed(state, selection) do
    if state.runtime_pid, do: send(state.runtime_pid, {:terminal_selection_changed, selection})
    Raxol.Core.Runtime.Log.info("Terminal selection changed: #{inspect(selection)}")
    :telemetry.execute([:raxol, :terminal, :selection_changed], %{selection: selection}, %{pid: self()})
    if state.callback_module, do: apply(state.callback_module, :selection_changed, [selection, state])
  end

  @doc """
  Notifies when a paste event occurs.
  """
  @spec notify_paste_event(map(), String.t(), {integer(), integer()}) :: :ok
  defp notify_paste_event(state, text, pos) do
    if state.runtime_pid, do: send(state.runtime_pid, {:terminal_paste_event, text, pos})
    Raxol.Core.Runtime.Log.info("Terminal paste event: #{inspect(text)} at #{inspect(pos)}")
    :telemetry.execute([:raxol, :terminal, :paste_event], %{text: text, position: pos}, %{pid: self()})
    # Advanced Prometheus metric: paste length
    :telemetry.execute([:raxol, :terminal, :paste_event, :length], %{length: String.length(text)}, %{position: pos, pid: self()})
    if state.callback_module, do: apply(state.callback_module, :paste_event, [text, pos, state])
    :ok
  end

  @doc """
  Notifies when a cursor event occurs.
  """
  @spec notify_cursor_event(map(), map()) :: :ok
  defp notify_cursor_event(state, cursor) do
    if state.runtime_pid, do: send(state.runtime_pid, {:terminal_cursor_event, cursor})
    Raxol.Core.Runtime.Log.info("Terminal cursor event: #{inspect(cursor)}")
    :telemetry.execute([:raxol, :terminal, :cursor_event], %{cursor: cursor}, %{pid: self()})
    if state.callback_module, do: apply(state.callback_module, :cursor_event, [cursor, state])
    :ok
  end

  @doc """
  Notifies when a scroll event occurs.
  """
  @spec notify_scroll_event(map(), atom(), integer(), {integer(), integer()}) :: :ok
  defp notify_scroll_event(state, dir, delta, pos) do
    if state.runtime_pid, do: send(state.runtime_pid, {:terminal_scroll_event, dir, delta, pos})
    Raxol.Core.Runtime.Log.info("Terminal scroll event: #{inspect(dir)} delta=#{delta} at #{inspect(pos)}")
    :telemetry.execute([:raxol, :terminal, :scroll_event], %{direction: dir, delta: delta, position: pos}, %{pid: self()})
    # Advanced Prometheus metric: scroll delta histogram
    :telemetry.execute([:raxol, :terminal, :scroll_event, :delta], %{delta: delta}, %{direction: dir, position: pos, pid: self()})
    if state.callback_module, do: apply(state.callback_module, :scroll_event, [dir, delta, pos, state])
    :ok
  end
end

defmodule Raxol.Terminal.Manager.Callback do
  @moduledoc """
  Behaviour for terminal manager event callbacks. Implement this behaviour to receive notifications for terminal events.
  """
  @callback focus_changed(focused :: boolean(), state :: map()) :: any()
  @callback resized(width :: integer(), height :: integer(), state :: map()) :: any()
  @callback mode_changed(mode :: atom(), state :: map()) :: any()
  @callback clipboard_event(op :: atom(), content :: any(), state :: map()) :: any()
  @callback selection_changed(selection :: map(), state :: map()) :: any()
  @callback paste_event(text :: String.t(), pos :: {integer(), integer()}, state :: map()) :: any()
  @callback cursor_event(cursor :: map(), state :: map()) :: any()
  @callback scroll_event(dir :: atom(), delta :: integer(), pos :: {integer(), integer()}, state :: map()) :: any()
end
