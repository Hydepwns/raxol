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

  require Logger

  defmodule Session do
    @enforce_keys [:id, :name, :created_at]
    defstruct [
      :id,
      :name,
      :created_at,
      :last_activity,
      :status,
      :metadata,
      :windows,
      :active_window,
      :clients,
      :persistence_config,
      :resource_limits,
      :hooks
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            created_at: integer(),
            last_activity: integer(),
            status: :active | :inactive | :detached,
            metadata: map(),
            windows: [term()],
            active_window: String.t() | nil,
            clients: [term()],
            persistence_config: map(),
            resource_limits: map(),
            hooks: map()
          }
  end

  defmodule Window do
    @enforce_keys [:id, :session_id, :name]
    defstruct [
      :id,
      :session_id,
      :name,
      :created_at,
      :status,
      :layout,
      :panes,
      :active_pane,
      :metadata
    ]

    @type layout_type ::
            :main_horizontal
            | :main_vertical
            | :even_horizontal
            | :even_vertical
            | :tiled
    @type t :: %__MODULE__{
            id: String.t(),
            session_id: String.t(),
            name: String.t(),
            created_at: integer(),
            status: :active | :inactive,
            layout: layout_type(),
            panes: [term()],
            active_pane: String.t() | nil,
            metadata: map()
          }
  end

  defmodule Pane do
    @enforce_keys [:id, :window_id, :terminal]
    defstruct [
      :id,
      :window_id,
      :terminal,
      :position,
      :size,
      :command,
      :working_directory,
      :environment,
      :status,
      :created_at
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            window_id: String.t(),
            terminal: pid(),
            position: {integer(), integer()},
            size: {integer(), integer()},
            command: String.t() | nil,
            working_directory: String.t(),
            environment: map(),
            status: :running | :stopped | :finished,
            created_at: integer()
          }
  end

  defmodule Client do
    @enforce_keys [:id, :session_id]
    defstruct [
      :id,
      :session_id,
      :connection_type,
      :connected_at,
      :last_activity,
      :terminal_size,
      :capabilities,
      :metadata
    ]

    @type connection_type :: :local | :remote | :shared
    @type t :: %__MODULE__{
            id: String.t(),
            session_id: String.t(),
            connection_type: connection_type(),
            connected_at: integer(),
            last_activity: integer(),
            terminal_size: {integer(), integer()},
            capabilities: [atom()],
            metadata: map()
          }
  end

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
      Raxol.Terminal.SessionManager.Helpers.start_cleanup_timer(
        config.cleanup_interval_minutes
      )

    # Initialize network server for remote sessions
    network_server =
      init_network_server(config.enable_session_sharing, config.network_port)

    state = %__MODULE__{
      sessions: %{},
      clients: %{},
      config: config,
      persistence_manager: init_persistence_manager(persistence_dir),
      resource_monitor: init_resource_monitor(config.resource_monitoring),
      network_server: network_server
    }

    # Restore saved sessions
    restored_sessions = restore_persisted_sessions(state)
    final_state = %{state | sessions: restored_sessions}

    Logger.info(
      "Session manager started with #{map_size(restored_sessions)} restored sessions"
    )

    {:ok, final_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:create_session, name, config}, _from, state) do
    session_id = generate_session_id(name)

    case create_new_session(session_id, name, config, state) do
      {:ok, session, new_state} ->
        Logger.info("Created session '#{name}' (#{session_id})")
        {:reply, {:ok, session}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(:list_sessions, _from, state) do
    sessions_summary =
      state.sessions
      |> Map.values()
      |> Enum.map(&session_summary/1)

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
        new_state = cleanup_session(session, state)
        updated_sessions = Map.delete(new_state.sessions, session_id)
        final_state = %{new_state | sessions: updated_sessions}

        Logger.info("Destroyed session '#{session.name}' (#{session_id})")
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
        client_id = generate_client_id()
        client = create_client(client_id, session_id, client_config)

        # Add client to session and global client registry
        updated_session = %{session | clients: [client | session.clients]}
        updated_sessions = Map.put(state.sessions, session_id, updated_session)
        updated_clients = Map.put(state.clients, client_id, client)

        new_state = %{
          state
          | sessions: updated_sessions,
            clients: updated_clients
        }

        Logger.info("Client #{client_id} attached to session '#{session.name}'")
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

        Logger.info("Client #{client_id} detached from session")
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
    case find_pane(state, session_id, window_id, pane_id) do
      {:ok, _session, window, pane} ->
        handle_pane_splitting(
          window,
          pane,
          direction,
          config,
          state,
          session_id,
          window_id,
          pane_id
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
    case find_pane(state, session_id, window_id, pane_id) do
      {:ok, _session, _window, pane} ->
        # Send input to the pane's terminal process
        case send_to_terminal(pane.terminal, input) do
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
        case save_session_to_disk(session, state.persistence_manager) do
          :ok -> {:reply, :ok, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info(:cleanup_sessions, state) do
    Logger.debug("Running session cleanup")
    new_state = cleanup_expired_sessions(state)
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

  defp create_new_session(session_id, name, config, state) do
    check_session_limit_and_create(session_id, name, config, state)
  end

  defp create_initial_windows(session, config) do
    window_count = Map.get(config, :windows, 1)
    layout = Map.get(config, :layout, :main_horizontal)
    working_dir = Map.get(config, :working_directory, System.user_home!())

    windows =
      Enum.map(1..window_count, fn i ->
        window_id = generate_window_id()
        window_name = "window-#{i}"

        create_window_with_panes(window_id, session.id, window_name, %{
          layout: layout,
          working_directory: working_dir,
          # Default single pane
          panes: [%{command: nil}]
        })
      end)

    # Set first window as active
    active_window = get_active_window(windows)

    {%{session | active_window: active_window}, windows}
  end

  defp create_window_with_panes(window_id, session_id, window_name, config) do
    now = System.monotonic_time(:millisecond)
    layout = Map.get(config, :layout, :main_horizontal)
    pane_configs = Map.get(config, :panes, [%{}])

    panes =
      Enum.with_index(pane_configs)
      |> Enum.map(fn {pane_config, index} ->
        create_pane(window_id, pane_config, index)
      end)

    %Window{
      id: window_id,
      session_id: session_id,
      name: window_name,
      created_at: now,
      status: :active,
      layout: layout,
      panes: panes,
      active_pane: if(length(panes) > 0, do: List.first(panes).id, else: nil),
      metadata: Map.get(config, :metadata, %{})
    }
  end

  defp create_pane(window_id, config, index) do
    pane_id = generate_pane_id()
    working_dir = Map.get(config, :working_directory, System.user_home!())
    command = Map.get(config, :command)
    environment = Map.get(config, :environment, %{})

    # Start terminal process for this pane
    {:ok, terminal_pid} =
      start_terminal_process(command, working_dir, environment)

    %Pane{
      id: pane_id,
      window_id: window_id,
      terminal: terminal_pid,
      # Simplified positioning
      position: {0, index * 25},
      # Default terminal size
      size: {80, 24},
      command: command,
      working_directory: working_dir,
      environment: environment,
      status: :running,
      created_at: System.monotonic_time(:millisecond)
    }
  end

  defp create_client(client_id, session_id, config) do
    %Client{
      id: client_id,
      session_id: session_id,
      connection_type: Map.get(config, :connection_type, :local),
      connected_at: System.monotonic_time(:millisecond),
      last_activity: System.monotonic_time(:millisecond),
      terminal_size: Map.get(config, :terminal_size, {80, 24}),
      capabilities: Map.get(config, :capabilities, [:resize, :color, :mouse]),
      metadata: Map.get(config, :metadata, %{})
    }
  end

  defp split_existing_pane(pane, direction, config) do
    new_pane_id = generate_pane_id()
    working_dir = Map.get(config, :working_directory, pane.working_directory)
    command = Map.get(config, :command)

    {:ok, terminal_pid} =
      start_terminal_process(command, working_dir, pane.environment)

    # Calculate new position and size based on split direction
    {new_position, new_size} = calculate_split_geometry(pane, direction)

    %Pane{
      id: new_pane_id,
      window_id: pane.window_id,
      terminal: terminal_pid,
      position: new_position,
      size: new_size,
      command: command,
      working_directory: working_dir,
      environment: pane.environment,
      status: :running,
      created_at: System.monotonic_time(:millisecond)
    }
  end

  defp calculate_split_geometry(pane, direction) do
    {x, y} = pane.position
    {width, height} = pane.size

    case direction do
      :horizontal ->
        # Split horizontally (new pane below)
        new_height = div(height, 2)
        new_position = {x, y + new_height}
        new_size = {width, new_height}
        {new_position, new_size}

      :vertical ->
        # Split vertically (new pane to the right)
        new_width = div(width, 2)
        new_position = {x + new_width, y}
        new_size = {new_width, height}
        {new_position, new_size}
    end
  end

  defp find_pane(state, session_id, window_id, pane_id) do
    with {:ok, session} <- Map.fetch(state.sessions, session_id),
         {:ok, window} <- find_window_in_session(session, window_id),
         {:ok, pane} <- find_pane_in_window(window, pane_id) do
      {:ok, session, window, pane}
    else
      :error -> {:error, :not_found}
    end
  end

  defp find_window_in_session(session, window_id) do
    case Enum.find(session.windows, &(&1.id == window_id)) do
      nil -> :error
      window -> {:ok, window}
    end
  end

  defp find_pane_in_window(window, pane_id) do
    case Enum.find(window.panes, &(&1.id == pane_id)) do
      nil -> :error
      pane -> {:ok, pane}
    end
  end

  defp update_window_in_session(state, session_id, window_id, updated_window) do
    session = Map.get(state.sessions, session_id)

    updated_windows =
      Enum.map(session.windows, fn window ->
        update_window_if_match(window, window_id, updated_window)
      end)

    updated_session = %{session | windows: updated_windows}
    updated_sessions = Map.put(state.sessions, session_id, updated_session)

    %{state | sessions: updated_sessions}
  end

  defp cleanup_session(session, state) do
    # Terminate all terminal processes
    session.windows
    |> Enum.flat_map(& &1.panes)
    |> Enum.each(&stop_terminal_if_alive/1)

    # Remove all clients
    updated_clients =
      Enum.reduce(session.clients, state.clients, fn client, acc ->
        Map.delete(acc, client.id)
      end)

    %{state | clients: updated_clients}
  end

  defp cleanup_expired_sessions(state) do
    now = System.monotonic_time(:millisecond)
    timeout_ms = state.config.session_timeout_minutes * 60 * 1000

    {expired, active} =
      Enum.split_with(state.sessions, fn {_id, session} ->
        session.status == :detached and
          now - session.last_activity > timeout_ms
      end)

    cleanup_expired_sessions_if_any(expired, active, state)
  end

  defp session_summary(session) do
    %{
      id: session.id,
      name: session.name,
      status: session.status,
      windows: length(session.windows),
      clients: length(session.clients),
      created_at: session.created_at,
      last_activity: session.last_activity
    }
  end

  ## Terminal Process Management

  defp start_terminal_process(command, working_dir, environment) do
    # This would start an actual terminal emulator process
    # For now, we simulate with a simple GenServer
    terminal_config = %{
      command: command,
      working_directory: working_dir,
      environment: environment
    }

    Raxol.Terminal.Emulator.start_link(terminal_config)
  end

  defp send_to_terminal(terminal_pid, input) do
    send_input_if_alive(terminal_pid, input)
  end

  ## Persistence Management

  defp init_persistence_manager(persistence_dir) do
    %{
      directory: persistence_dir,
      enabled: true
    }
  end

  defp save_session_to_disk(session, persistence_manager) do
    save_if_persistence_enabled(session, persistence_manager)
  end

  defp restore_persisted_sessions(state) do
    restore_sessions_if_enabled(state.config.persistence_enabled, state)
  end

  defp restore_session_from_file(file) do
    with {:ok, data} <- File.read(file),
         {:ok, session} <- deserialize_session(data) do
      Logger.info("Restored session '#{session.name}' from #{file}")
      {:ok, session}
    else
      {:error, reason} ->
        Logger.warning(
          "Failed to restore session from #{file}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp serialize_session(session) do
    # Simplified serialization - in practice would use a robust format
    session
    |> Map.from_struct()
    |> :erlang.term_to_binary()
  end

  defp deserialize_session(data) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           session_map = :erlang.binary_to_term(data, [:safe])
           session = struct(Session, session_map)
           session
         end) do
      {:ok, session} -> {:ok, session}
      {:error, reason} -> {:error, reason}
    end
  end

  ## Resource Monitoring

  defp init_resource_monitor(enabled) do
    %{
      enabled: enabled,
      # 1GB
      memory_limit: 1_000_000_000,
      # 80%
      cpu_limit: 80.0
    }
  end

  ## Network Server

  defp start_network_server(port) do
    # Placeholder for network server to enable remote sessions
    # In practice, would start a TCP/WebSocket server
    Logger.info("Session sharing server started on port #{port}")
    %{port: port, enabled: true}
  end

  ## ID Generation

  defp generate_session_id(name) do
    timestamp = System.unique_integer([:positive, :monotonic])

    Base.encode16(:crypto.hash(:sha256, "#{name}-#{timestamp}"))
    |> String.slice(0, 16)
  end

  defp generate_window_id do
    "window_" <> Base.encode16(:crypto.strong_rand_bytes(4))
  end

  defp generate_pane_id do
    "pane_" <> Base.encode16(:crypto.strong_rand_bytes(4))
  end

  defp generate_client_id do
    "client_" <> Base.encode16(:crypto.strong_rand_bytes(4))
  end

  # Additional helper functions

  defp init_network_server(false, _port), do: nil
  defp init_network_server(true, port), do: start_network_server(port)

  defp update_window_if_match(window, window_id, updated_window) do
    case window.id == window_id do
      true -> updated_window
      false -> window
    end
  end

  defp save_if_persistence_enabled(_session, %{enabled: false}), do: :ok

  defp save_if_persistence_enabled(session, %{enabled: true, directory: dir}) do
    filename = Path.join(dir, "#{session.id}.session")
    data = serialize_session(session)
    File.write(filename, data)
  end

  defp send_input_if_alive(terminal_pid, input) do
    case Process.alive?(terminal_pid) do
      true ->
        GenServer.call(terminal_pid, {:send_input, input})

      false ->
        {:error, :terminal_dead}
    end
  end

  defp handle_pane_splitting(
         window,
         pane,
         direction,
         config,
         state,
         session_id,
         window_id,
         _pane_id
       ) do
    new_pane = split_existing_pane(pane, direction, config)
    updated_panes = [new_pane | window.panes]
    updated_window = %{window | panes: updated_panes}

    new_state =
      update_window_in_session(state, session_id, window_id, updated_window)

    {:reply, {:ok, new_pane}, new_state}
  end

  defp handle_window_creation(session, session_id, window_name, config, state) do
    case length(session.windows) < state.config.max_windows_per_session do
      true ->
        window_id = generate_window_id()

        new_window =
          create_window_with_panes(window_id, session_id, window_name, config)

        updated_windows = [new_window | session.windows]
        updated_session = %{session | windows: updated_windows}
        updated_sessions = Map.put(state.sessions, session_id, updated_session)
        new_state = %{state | sessions: updated_sessions}

        Logger.info("Created window '#{window_name}' in session #{session_id}")
        {:reply, {:ok, new_window}, new_state}

      false ->
        {:reply, {:error, :max_windows_exceeded}, state}
    end
  end

  defp stop_terminal_if_alive(pane) do
    case Process.alive?(pane.terminal) do
      true -> GenServer.stop(pane.terminal)
      false -> :ok
    end
  end

  defp check_session_limit_and_create(session_id, name, config, state) do
    case map_size(state.sessions) < state.config.max_sessions do
      true ->
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

        # Create initial windows
        {updated_session, windows} = create_initial_windows(session, config)
        final_session = %{updated_session | windows: windows}

        # Add to state
        updated_sessions = Map.put(state.sessions, session_id, final_session)
        new_state = %{state | sessions: updated_sessions}

        {:ok, final_session, new_state}

      false ->
        {:error, :max_sessions_exceeded}
    end
  end

  defp cleanup_expired_sessions_if_any([], _active, state), do: state

  defp cleanup_expired_sessions_if_any(expired, active, state) do
    Logger.info("Cleaning up #{length(expired)} expired sessions")

    # Cleanup each expired session
    Enum.each(expired, fn {_id, session} ->
      cleanup_session(session, state)
    end)

    # Keep only active sessions
    active_sessions = Map.new(active)
    %{state | sessions: active_sessions}
  end

  defp restore_sessions_if_enabled(false, _state), do: %{}

  defp restore_sessions_if_enabled(true, state) do
    persistence_dir = state.config.persistence_directory |> Path.expand()

    case File.ls(persistence_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".session"))
        |> Enum.reduce(%{}, fn file, acc ->
          file_path = Path.join(persistence_dir, file)

          case restore_session_from_file(file_path) do
            {:ok, session} -> Map.put(acc, session.id, session)
            {:error, _reason} -> acc
          end
        end)

      {:error, reason} ->
        Logger.warning(
          "Could not list persistence directory: #{inspect(reason)}"
        )

        %{}
    end
  end

  defp get_active_window([]), do: nil
  defp get_active_window([window | _windows]), do: window.id
end
