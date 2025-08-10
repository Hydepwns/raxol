defmodule Raxol.Web.SessionBridge do
  @moduledoc """
  Session Bridge for WASH-style continuous web applications.

  This module enables seamless transitions between terminal and web interfaces
  while maintaining complete session state continuity. Inspired by the WASH
  (Web Authoring System Haskell) approach but adapted for Elixir/OTP.

  ## Key Features

  - **Interface Migration**: Move sessions between terminal and web without state loss
  - **State Preservation**: All terminal state (buffers, cursor, history) preserved
  - **Real-time Sync**: Multi-client state synchronization via Phoenix PubSub
  - **Persistent Storage**: Multi-tier storage (ETS → DETS → Database)
  - **Conflict Resolution**: Intelligent handling of concurrent updates

  ## Architecture

  ```
  Terminal Client ←→ SessionBridge ←→ Web Browser(s)
        ↓                 ↓                 ↓
   TerminalSession → PersistentStore → LiveView
        ↓                 ↓                 ↓
     Emulator      → StateSynchronizer → Phoenix.PubSub
  ```

  ## Usage

      # Migrate terminal session to web
      SessionBridge.migrate_to_web(session_id, socket)
      
      # Access session from any interface
      {:ok, state} = SessionBridge.get_session_state(session_id)
      
      # Subscribe to real-time updates
      SessionBridge.subscribe_to_updates(session_id, self())
  """

  use GenServer
  alias Raxol.Web.{PersistentStore, StateSynchronizer}
  alias Raxol.Terminal.Session
  alias Phoenix.PubSub

  require Logger

  # Session bridge state
  defstruct [
    :session_id,
    :terminal_pid,
    :web_pids,
    :current_interface,
    :last_sync,
    :subscription_refs
  ]

  @type interface :: :terminal | :web
  @type session_state :: %{
          terminal_state: map(),
          cursor_position: {integer(), integer()},
          buffer_content: binary(),
          history: list(binary()),
          metadata: map(),
          timestamp: DateTime.t()
        }

  # Client API

  @doc """
  Starts a session bridge for the given session ID.
  """
  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via_tuple(session_id))
  end

  @doc """
  Migrates a terminal session to web interface.

  The terminal session state is captured and made available to web clients.
  The terminal remains active but web clients can now access the session.
  """
  @spec migrate_to_web(String.t(), pid()) :: :ok | {:error, term()}
  def migrate_to_web(session_id, web_pid) do
    GenServer.call(via_tuple(session_id), {:migrate_to_web, web_pid})
  end

  @doc """
  Migrates a web session back to terminal interface.

  The web session state is transferred back to the terminal session.
  Web clients are notified of the migration.
  """
  @spec migrate_to_terminal(String.t(), pid()) :: :ok | {:error, term()}
  def migrate_to_terminal(session_id, terminal_pid) do
    GenServer.call(via_tuple(session_id), {:migrate_to_terminal, terminal_pid})
  end

  @doc """
  Retrieves the current session state regardless of interface.

  This provides a unified view of the session state that can be used
  by either terminal or web clients.
  """
  @spec get_session_state(String.t()) ::
          {:ok, session_state()} | {:error, :not_found}
  def get_session_state(session_id) do
    case GenServer.whereis(via_tuple(session_id)) do
      nil -> {:error, :not_found}
      pid -> GenServer.call(pid, :get_session_state)
    end
  end

  @doc """
  Updates session state from either interface.

  Changes are synchronized across all connected clients in real-time.
  """
  @spec update_session_state(String.t(), map(), interface()) ::
          :ok | {:error, term()}
  def update_session_state(session_id, changes, from_interface) do
    GenServer.cast(
      via_tuple(session_id),
      {:update_state, changes, from_interface}
    )
  end

  @doc """
  Subscribes a process to real-time session updates.
  """
  @spec subscribe_to_updates(String.t(), pid()) :: :ok
  def subscribe_to_updates(session_id, subscriber_pid) do
    topic = "session:#{session_id}"
    PubSub.subscribe(Raxol.PubSub, topic)
    GenServer.cast(via_tuple(session_id), {:subscribe, subscriber_pid})
  end

  @doc """
  Lists all active sessions with their current interfaces.
  """
  @spec list_active_sessions() :: [
          %{session_id: String.t(), interface: interface(), clients: integer()}
        ]
  def list_active_sessions do
    # In a full implementation, this would query the registry
    []
  end

  # GenServer Implementation

  @impl GenServer
  def init(session_id) do
    Logger.info("Starting SessionBridge for session: #{session_id}")

    # Subscribe to terminal and web events for this session
    topic = "session:#{session_id}"
    PubSub.subscribe(Raxol.PubSub, topic)

    state = %__MODULE__{
      session_id: session_id,
      terminal_pid: nil,
      web_pids: MapSet.new(),
      current_interface: nil,
      last_sync: DateTime.utc_now(),
      subscription_refs: %{}
    }

    # Initialize persistent storage for this session
    PersistentStore.init_session(session_id)

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:migrate_to_web, web_pid}, _from, state) do
    Logger.info("Migrating session #{state.session_id} to web interface")

    # Capture current terminal state if terminal is active
    session_state =
      case state.terminal_pid do
        nil ->
          # Load from persistent store
          PersistentStore.get_session(state.session_id)

        terminal_pid ->
          # Capture live terminal state
          capture_terminal_state(terminal_pid)
      end

    # Store the state persistently
    :ok = PersistentStore.store_session(state.session_id, session_state)

    # Add web client to active set
    new_web_pids = MapSet.put(state.web_pids, web_pid)

    # Monitor the web process
    Process.monitor(web_pid)

    # Broadcast migration event
    broadcast_event(state.session_id, {:migrated_to_web, web_pid})

    new_state = %{
      state
      | web_pids: new_web_pids,
        current_interface: :web,
        last_sync: DateTime.utc_now()
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:migrate_to_terminal, terminal_pid}, _from, state) do
    Logger.info("Migrating session #{state.session_id} to terminal interface")

    # Get current session state
    session_state = PersistentStore.get_session(state.session_id)

    # Apply state to terminal session
    :ok = apply_state_to_terminal(terminal_pid, session_state)

    # Monitor terminal process
    Process.monitor(terminal_pid)

    # Notify web clients of migration
    broadcast_to_web_clients(
      state.web_pids,
      {:migrated_to_terminal, terminal_pid}
    )

    # Broadcast migration event
    broadcast_event(state.session_id, {:migrated_to_terminal, terminal_pid})

    new_state = %{
      state
      | terminal_pid: terminal_pid,
        current_interface: :terminal,
        last_sync: DateTime.utc_now()
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_session_state, _from, state) do
    case PersistentStore.get_session(state.session_id) do
      {:ok, session_state} -> {:reply, {:ok, session_state}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_cast({:update_state, changes, from_interface}, state) do
    Logger.debug(
      "Updating session #{state.session_id} state from #{from_interface}"
    )

    # Get current state
    {:ok, current_state} = PersistentStore.get_session(state.session_id)

    # Merge changes with conflict resolution
    new_state =
      StateSynchronizer.merge_changes(current_state, changes, from_interface)

    # Store updated state
    :ok = PersistentStore.store_session(state.session_id, new_state)

    # Broadcast changes to other interfaces
    case from_interface do
      :terminal ->
        broadcast_to_web_clients(state.web_pids, {:state_update, changes})

      :web ->
        if state.terminal_pid,
          do: send(state.terminal_pid, {:state_update, changes})
    end

    # Broadcast to all subscribers
    broadcast_event(state.session_id, {:state_updated, changes, from_interface})

    updated_state = %{state | last_sync: DateTime.utc_now()}
    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:subscribe, subscriber_pid}, state) do
    # Monitor subscriber
    ref = Process.monitor(subscriber_pid)
    refs = Map.put(state.subscription_refs, subscriber_pid, ref)

    {:noreply, %{state | subscription_refs: refs}}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Logger.info(
      "Process #{inspect(pid)} disconnected from session #{state.session_id}"
    )

    cond do
      pid == state.terminal_pid ->
        # Terminal disconnected - session continues in web mode
        new_state = %{state | terminal_pid: nil, current_interface: :web}
        broadcast_event(state.session_id, {:terminal_disconnected, pid})
        {:noreply, new_state}

      MapSet.member?(state.web_pids, pid) ->
        # Web client disconnected
        new_web_pids = MapSet.delete(state.web_pids, pid)

        new_interface =
          if MapSet.size(new_web_pids) == 0 and state.terminal_pid,
            do: :terminal,
            else: state.current_interface

        new_state = %{
          state
          | web_pids: new_web_pids,
            current_interface: new_interface,
            subscription_refs: Map.delete(state.subscription_refs, pid)
        }

        broadcast_event(state.session_id, {:web_client_disconnected, pid})

        # If no clients remain, schedule cleanup
        if MapSet.size(new_web_pids) == 0 and is_nil(state.terminal_pid) do
          # 30 second grace period
          Process.send_after(self(), :cleanup_session, 30_000)
        end

        {:noreply, new_state}

      true ->
        # Unknown process disconnected
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:cleanup_session, state) do
    Logger.info("Cleaning up session #{state.session_id} - no active clients")

    # In a full implementation, this might archive the session or mark it inactive
    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp via_tuple(session_id) do
    {:via, Registry, {Raxol.Web.SessionRegistry, session_id}}
  end

  defp capture_terminal_state(terminal_pid) do
    # In a real implementation, this would communicate with the terminal session
    # to extract current state (buffer content, cursor position, history, etc.)
    try do
      case GenServer.call(terminal_pid, :get_full_state, 5000) do
        {:ok, terminal_state} ->
          %{
            terminal_state: terminal_state,
            cursor_position: Map.get(terminal_state, :cursor_position, {0, 0}),
            buffer_content: Map.get(terminal_state, :buffer_content, ""),
            history: Map.get(terminal_state, :history, []),
            metadata: %{
              captured_at: DateTime.utc_now(),
              interface: :terminal
            },
            timestamp: DateTime.utc_now()
          }

        {:error, reason} ->
          Logger.warning("Failed to capture terminal state: #{inspect(reason)}")
          default_session_state()
      end
    rescue
      error ->
        Logger.warning("Error capturing terminal state: #{inspect(error)}")
        default_session_state()
    end
  end

  defp apply_state_to_terminal(terminal_pid, session_state) do
    # In a real implementation, this would restore the terminal state
    try do
      GenServer.call(terminal_pid, {:restore_state, session_state}, 5000)
      :ok
    rescue
      error ->
        Logger.error("Failed to restore terminal state: #{inspect(error)}")
        {:error, :restore_failed}
    end
  end

  defp broadcast_to_web_clients(web_pids, message) do
    Enum.each(web_pids, fn pid ->
      send(pid, message)
    end)
  end

  defp broadcast_event(session_id, event) do
    topic = "session:#{session_id}"
    PubSub.broadcast(Raxol.PubSub, topic, event)
  end

  defp default_session_state do
    %{
      terminal_state: %{},
      cursor_position: {0, 0},
      buffer_content: "",
      history: [],
      metadata: %{
        created_at: DateTime.utc_now(),
        interface: :unknown
      },
      timestamp: DateTime.utc_now()
    }
  end
end
