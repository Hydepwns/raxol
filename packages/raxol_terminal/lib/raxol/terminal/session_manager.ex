defmodule Raxol.Terminal.SessionManager do
  @moduledoc """
  Terminal multiplexing system providing tmux-like session management for Raxol.

  This module implements comprehensive terminal session multiplexing with:
  - Multiple terminal sessions with independent state
  - Window and pane management within sessions
  - Session persistence across disconnections
  - Remote session attachment and detachment
  - Session sharing and collaboration features
  - Automatic session recovery and state preservation
  - Advanced session management (naming, grouping, tagging)

  ## Features

  ### Session Management
  - Create, destroy, and switch between multiple sessions
  - Named sessions with metadata and tags
  - Session persistence to disk with state recovery
  - Automatic cleanup of orphaned sessions
  - Session templates and presets

  ### Window and Pane Management
  - Multiple windows per session
  - Split windows into panes (horizontal/vertical)
  - Pane resizing and layout management
  - Window/pane navigation and switching
  - Synchronized input across panes

  ### Advanced Features
  - Session sharing between multiple clients
  - Remote session access over network
  - Session recording and playback
  - Custom session hooks and automation
  - Resource monitoring and limits

  ## Usage

      # Create a new session
      {:ok, session} = SessionManager.create_session("dev-session",
        windows: 3,
        layout: :main_vertical
      )

      # Attach to an existing session
      {:ok, client} = SessionManager.attach_session("dev-session")

      # Create window with panes
      {:ok, window} = SessionManager.create_window(session, "editor",
        panes: [
          %{command: "nvim", directory: "/home/user/project"},
          %{command: "bash", directory: "/home/user/project"}
        ]
      )

      # Detach and session continues running
      SessionManager.detach_client(client)
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log

  alias Raxol.Terminal.SessionManager.{
    Cleanup,
    Helpers,
    Persistence,
    Session,
    StateQueries,
    Window,
    WindowFactory
  }

  @compile {:no_warn_undefined, Raxol.Terminal.SessionManager.Cleanup}
  @compile {:no_warn_undefined, Raxol.Terminal.SessionManager.Helpers}
  @compile {:no_warn_undefined, Raxol.Terminal.SessionManager.Persistence}
  @compile {:no_warn_undefined, Raxol.Terminal.SessionManager.Session}
  @compile {:no_warn_undefined, Raxol.Terminal.SessionManager.StateQueries}
  @compile {:no_warn_undefined, Raxol.Terminal.SessionManager.Window}
  @compile {:no_warn_undefined, Raxol.Terminal.SessionManager.WindowFactory}

  defstruct [
    :sessions,
    :clients,
    :config,
    :persistence_manager,
    :resource_monitor,
    :network_server
  ]

  @type session_config :: %{
          name: String.t(),
          windows: integer(),
          layout: Window.layout_type(),
          working_directory: String.t(),
          environment: map(),
          persistence: boolean(),
          resource_limits: map()
        }

  # Default configuration
  @default_config %{
    max_sessions: 50,
    max_windows_per_session: 20,
    max_panes_per_window: 16,
    # 24 hours
    session_timeout_minutes: 1440,
    persistence_enabled: true,
    persistence_directory: "~/.raxol/sessions",
    cleanup_interval_minutes: 60,
    resource_monitoring: true,
    network_port: 9999,
    enable_session_sharing: true
  }

  ## Public API

  # BaseManager provides start_link/1 which will call init_manager/1
  # Callers should use: SessionManager.start_link(name: __MODULE__)

  @doc """
  Creates a new terminal session.

  ## Examples

      {:ok, session} = SessionManager.create_session("dev",
        windows: 2,
        layout: :main_vertical,
        working_directory: "/home/user/project"
      )
  """
  def create_session(name, config \\ %{}) do
    GenServer.call(__MODULE__, {:create_session, name, config})
  end

  @doc """
  Lists all available sessions.
  """
  def list_sessions do
    GenServer.call(__MODULE__, :list_sessions)
  end

  @doc """
  Gets detailed information about a session.
  """
  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  @doc """
  Destroys a session and all its windows/panes.
  """
  def destroy_session(session_id) do
    GenServer.call(__MODULE__, {:destroy_session, session_id})
  end

  @doc """
  Attaches a client to a session.
  """
  def attach_session(session_id, client_config \\ %{}) do
    GenServer.call(__MODULE__, {:attach_session, session_id, client_config})
  end

  @doc """
  Detaches a client from their current session.
  """
  def detach_client(client_id) do
    GenServer.call(__MODULE__, {:detach_client, client_id})
  end

  @doc """
  Creates a new window in a session.
  """
  def create_window(session_id, window_name, config \\ %{}) do
    GenServer.call(
      __MODULE__,
      {:create_window, session_id, window_name, config}
    )
  end

  @doc """
  Destroys a window and all its panes.
  """
  def destroy_window(session_id, window_id) do
    GenServer.call(__MODULE__, {:destroy_window, session_id, window_id})
  end

  @doc """
  Splits a pane horizontally or vertically.
  """
  def split_pane(session_id, window_id, pane_id, direction, config \\ %{})
      when direction in [:horizontal, :vertical] do
    GenServer.call(
      __MODULE__,
      {:split_pane, session_id, window_id, pane_id, direction, config}
    )
  end

  @doc """
  Switches the active window in a session.
  """
  def switch_window(session_id, window_id) do
    GenServer.call(__MODULE__, {:switch_window, session_id, window_id})
  end

  @doc """
  Switches the active pane in a window.
  """
  def switch_pane(session_id, window_id, pane_id) do
    GenServer.call(__MODULE__, {:switch_pane, session_id, window_id, pane_id})
  end

  @doc """
  Resizes a pane.
  """
  def resize_pane(session_id, window_id, pane_id, {width, height}) do
    GenServer.call(
      __MODULE__,
      {:resize_pane, session_id, window_id, pane_id, {width, height}}
    )
  end

  @doc """
  Sends input to a specific pane.
  """
  def send_input(session_id, window_id, pane_id, input) do
    GenServer.call(
      __MODULE__,
      {:send_input, session_id, window_id, pane_id, input}
    )
  end

  @doc """
  Broadcasts input to all panes in a window (synchronized input).
  """
  def broadcast_input(session_id, window_id, input) do
    GenServer.call(__MODULE__, {:broadcast_input, session_id, window_id, input})
  end

  @doc """
  Saves session state to persistent storage.
  """
  def save_session(session_id) do
    GenServer.call(__MODULE__, {:save_session, session_id})
  end

  @doc """
  Restores session from persistent storage.
  """
  def restore_session(session_name) do
    GenServer.call(__MODULE__, {:restore_session, session_name})
  end

  @doc """
  Enables session sharing for collaboration.
  """
  def enable_session_sharing(session_id, sharing_config \\ %{}) do
    GenServer.call(__MODULE__, {:enable_sharing, session_id, sharing_config})
  end

  @doc """
  Gets session statistics and resource usage.
  """
  def get_session_stats(session_id) do
    GenServer.call(__MODULE__, {:get_session_stats, session_id})
  end

  ## BaseManager Implementation

  # BaseManager provides GenServer callbacks that delegate to handle_manager_*

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    # Merge with default config
    config = Map.merge(@default_config, Map.new(opts))

    # Initialize persistence directory
    persistence_dir = Path.expand(config.persistence_directory)
    File.mkdir_p!(persistence_dir)

    # Start cleanup timer
    _ =
      Raxol.Terminal.SessionManager.Helpers.start_cleanup_timer(config.cleanup_interval_minutes)

    # Initialize network server for remote sessions
    network_server =
      Helpers.init_network_server(
        config.enable_session_sharing,
        config.network_port
      )

    state = %__MODULE__{
      sessions: %{},
      clients: %{},
      config: config,
      persistence_manager: Persistence.init(persistence_dir),
      resource_monitor: Cleanup.init_resource_monitor(config.resource_monitoring),
      network_server: network_server
    }

    # Restore saved sessions
    restored_sessions =
      Persistence.restore_all(config.persistence_enabled, state)

    final_state = %{state | sessions: restored_sessions}

    Log.info("Session manager started with #{map_size(restored_sessions)} restored sessions")

    {:ok, final_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:create_session, name, config}, _from, state) do
    session_id = Helpers.generate_session_id(name)

    case check_session_limit_and_create(session_id, name, config, state) do
      {:ok, session, new_state} ->
        Log.info("Created session '#{name}' (#{session_id})")
        {:reply, {:ok, session}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(:list_sessions, _from, state) do
    sessions_summary =
      state.sessions
      |> Map.values()
      |> Enum.map(&StateQueries.session_summary/1)

    {:reply, sessions_summary, state}
  end

  def handle_manager_call({:get_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil -> {:reply, {:error, :session_not_found}, state}
      session -> {:reply, {:ok, session}, state}
    end
  end

  def handle_manager_call({:destroy_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        # Cleanup all clients, windows, and panes
        new_state = Cleanup.cleanup_session(session, state)
        updated_sessions = Map.delete(new_state.sessions, session_id)
        final_state = %{new_state | sessions: updated_sessions}

        Log.info("Destroyed session '#{session.name}' (#{session_id})")
        {:reply, :ok, final_state}
    end
  end

  def handle_manager_call(
        {:attach_session, session_id, client_config},
        _from,
        state
      ) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        client_id = Helpers.generate_client_id()
        client = Helpers.create_client(client_id, session_id, client_config)

        # Add client to session and global client registry
        updated_session = %{session | clients: [client | session.clients]}
        updated_sessions = Map.put(state.sessions, session_id, updated_session)
        updated_clients = Map.put(state.clients, client_id, client)

        new_state = %{
          state
          | sessions: updated_sessions,
            clients: updated_clients
        }

        Log.info("Client #{client_id} attached to session '#{session.name}'")

        {:reply, {:ok, client}, new_state}
    end
  end

  def handle_manager_call({:detach_client, client_id}, _from, state) do
    case Map.get(state.clients, client_id) do
      nil ->
        {:reply, {:error, :client_not_found}, state}

      client ->
        # Remove client from session
        session = Map.get(state.sessions, client.session_id)

        updated_session = %{
          session
          | clients: List.delete(session.clients, client)
        }

        updated_sessions =
          Map.put(state.sessions, client.session_id, updated_session)

        updated_clients = Map.delete(state.clients, client_id)

        new_state = %{
          state
          | sessions: updated_sessions,
            clients: updated_clients
        }

        Log.info("Client #{client_id} detached from session")
        {:reply, :ok, new_state}
    end
  end

  def handle_manager_call(
        {:create_window, session_id, window_name, config},
        _from,
        state
      ) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        handle_window_creation(session, session_id, window_name, config, state)
    end
  end

  def handle_manager_call(
        {:split_pane, session_id, window_id, pane_id, direction, config},
        _from,
        state
      ) do
    case StateQueries.find_pane(state, session_id, window_id, pane_id) do
      {:ok, _session, window, pane} ->
        handle_pane_splitting(
          window,
          pane,
          direction,
          config,
          state,
          session_id,
          window_id
        )

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(
        {:send_input, session_id, window_id, pane_id, input},
        _from,
        state
      ) do
    case StateQueries.find_pane(state, session_id, window_id, pane_id) do
      {:ok, _session, _window, pane} ->
        # Send input to the pane's terminal process
        case Helpers.send_to_terminal(pane.terminal, input) do
          :ok -> {:reply, :ok, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call({:save_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        case Persistence.save_session(session, state.persistence_manager) do
          :ok -> {:reply, :ok, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info(:cleanup_sessions, state) do
    Log.debug("Running session cleanup")
    new_state = Cleanup.cleanup_expired_sessions(state)
    {:noreply, new_state}
  end

  def handle_manager_info({:session_activity, session_id}, state) do
    # Update last activity timestamp
    case Map.get(state.sessions, session_id) do
      nil ->
        {:noreply, state}

      session ->
        updated_session = %{
          session
          | last_activity: System.monotonic_time(:millisecond)
        }

        updated_sessions = Map.put(state.sessions, session_id, updated_session)
        {:noreply, %{state | sessions: updated_sessions}}
    end
  end

  def handle_manager_info(_msg, state) do
    {:noreply, state}
  end

  ## Private Implementation

  defp handle_pane_splitting(
         window,
         pane,
         direction,
         config,
         state,
         session_id,
         window_id
       ) do
    new_pane = WindowFactory.split_pane(pane, direction, config)
    updated_panes = [new_pane | window.panes]
    updated_window = %{window | panes: updated_panes}

    new_state =
      StateQueries.update_window_in_session(
        state,
        session_id,
        window_id,
        updated_window
      )

    {:reply, {:ok, new_pane}, new_state}
  end

  defp handle_window_creation(session, session_id, window_name, config, state) do
    if length(session.windows) < state.config.max_windows_per_session do
      window_id = WindowFactory.generate_window_id()

      new_window =
        WindowFactory.create_window_with_panes(
          window_id,
          session_id,
          window_name,
          config
        )

      updated_windows = [new_window | session.windows]
      updated_session = %{session | windows: updated_windows}
      updated_sessions = Map.put(state.sessions, session_id, updated_session)
      new_state = %{state | sessions: updated_sessions}

      Log.info("Created window '#{window_name}' in session #{session_id}")

      {:reply, {:ok, new_window}, new_state}
    else
      {:reply, {:error, :max_windows_exceeded}, state}
    end
  end

  defp check_session_limit_and_create(session_id, name, config, state) do
    if map_size(state.sessions) < state.config.max_sessions do
      now = System.monotonic_time(:millisecond)

      session = %Session{
        id: session_id,
        name: name,
        created_at: now,
        last_activity: now,
        status: :active,
        metadata: Map.get(config, :metadata, %{}),
        windows: [],
        active_window: nil,
        clients: [],
        persistence_config: %{},
        resource_limits: %{},
        hooks: %{}
      }

      {updated_session, windows} =
        WindowFactory.create_initial_windows(session, config)

      final_session = %{updated_session | windows: windows}

      updated_sessions = Map.put(state.sessions, session_id, final_session)
      new_state = %{state | sessions: updated_sessions}

      {:ok, final_session, new_state}
    else
      {:error, :max_sessions_exceeded}
    end
  end
end
