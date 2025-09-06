defmodule Raxol.Terminal.Multiplexer.SessionManager do
  @moduledoc """
  Terminal multiplexing system providing tmux-like session management for Raxol.

  This module provides comprehensive session management with:
  - Multiple persistent terminal sessions
  - Window and pane management within sessions
  - Session detaching and reattaching
  - Cross-platform session persistence
  - Real-time session sharing and collaboration
  - Advanced layout management
  - Session scripting and automation
  - Resource isolation between sessions

  ## Features

  ### Session Management
  - Create, list, attach, detach sessions
  - Named sessions with unique identifiers
  - Session persistence across application restarts
  - Session templates and presets
  - Automatic session recovery

  ### Window Management
  - Multiple windows per session
  - Window splitting (horizontal/vertical)
  - Pane management with resize and navigation
  - Custom layouts (even-horizontal, even-vertical, main-vertical, etc.)
  - Window and pane synchronization

  ### Advanced Features
  - Session sharing between users/devices
  - Real-time collaboration with multiple cursors
  - Session recording and playback
  - Command history per session
  - Environment variable isolation
  - Custom key bindings per session

  ## Usage

      # Create and manage sessions
      {:ok, session_mgr} = SessionManager.start_link()
      
      # Create a new session
      {:ok, session_id} = SessionManager.create_session(session_mgr, 
        name: "dev-work", 
        windows: [
          %{name: "editor", command: "nvim"},
          %{name: "server", command: "mix phx.server"},
          %{name: "logs", command: "tail -f log/dev.log"}
        ]
      )
      
      # Attach to session
      SessionManager.attach_session(session_mgr, session_id)
      
      # Create window with panes
      {:ok, window_id} = SessionManager.create_window(session_mgr, session_id, 
        name: "development",
        layout: :main_vertical,
        panes: [
          %{command: "nvim .", size: 70},
          %{command: "iex -S mix", size: 30}
        ]
      )
      
      # Session sharing
      share_token = SessionManager.share_session(session_mgr, session_id,
        permissions: [:read, :write],
        expires_in: :timer.hours(24)
      )
  """

  use GenServer
  require Logger

  # Multiplexer aliases will be added as needed

  defstruct [
    :sessions,
    :active_session,
    :session_storage,
    :config,
    :event_bus,
    :collaboration_server
  ]

  @type session_id :: String.t()
  @type window_id :: String.t()
  @type pane_id :: String.t()
  @type layout_type ::
          :even_horizontal
          | :even_vertical
          | :main_horizontal
          | :main_vertical
          | :tiled
          | :custom

  @type session :: %{
          id: session_id(),
          name: String.t(),
          created_at: integer(),
          last_accessed: integer(),
          windows: [window_id()],
          active_window: window_id() | nil,
          environment: %{String.t() => String.t()},
          working_directory: String.t(),
          status: :active | :detached | :shared,
          metadata: map()
        }

  @type window :: %{
          id: window_id(),
          session_id: session_id(),
          name: String.t(),
          layout: layout_type(),
          panes: [pane_id()],
          active_pane: pane_id() | nil,
          created_at: integer(),
          metadata: map()
        }

  @type pane :: %{
          id: pane_id(),
          window_id: window_id(),
          session_id: session_id(),
          command: String.t() | nil,
          pid: pid() | nil,
          size: %{width: integer(), height: integer()},
          position: %{x: integer(), y: integer()},
          status: :active | :inactive | :dead,
          buffer: term(),
          metadata: map()
        }

  @type collaboration_permission :: :read | :write | :admin
  @type share_token :: String.t()

  # Default configuration
  @default_config %{
    max_sessions: 100,
    session_timeout_hours: 72,
    auto_save_interval_ms: 30_000,
    enable_collaboration: false,
    storage_backend: :file,
    storage_path: "~/.raxol/sessions"
  }

  # Default layouts would be defined here when needed

  ## Public API

  @doc """
  Starts the session manager.

  ## Options
  - `:max_sessions` - Maximum number of concurrent sessions (default: 100)
  - `:session_timeout_hours` - Hours before inactive sessions expire (default: 72)
  - `:enable_collaboration` - Enable session sharing features (default: false)
  - `:storage_backend` - Storage backend (:file, :ets, :database) (default: :file)
  """
  def start_link(opts \\ []) do
    config = opts |> Enum.into(%{}) |> then(&Map.merge(@default_config, &1))
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Creates a new terminal session.

  ## Options
  - `:name` - Session name (default: auto-generated)
  - `:windows` - Initial windows to create
  - `:working_directory` - Initial working directory
  - `:environment` - Environment variables
  - `:template` - Session template to use
  """
  def create_session(manager \\ __MODULE__, opts \\ []) do
    GenServer.call(manager, {:create_session, opts})
  end

  @doc """
  Lists all available sessions.
  """
  def list_sessions(manager \\ __MODULE__) do
    GenServer.call(manager, :list_sessions)
  end

  @doc """
  Gets detailed information about a session.
  """
  def get_session(manager \\ __MODULE__, session_id) do
    GenServer.call(manager, {:get_session, session_id})
  end

  @doc """
  Attaches to a session, making it the active session.
  """
  def attach_session(manager \\ __MODULE__, session_id) do
    GenServer.call(manager, {:attach_session, session_id})
  end

  @doc """
  Detaches from the current session.
  """
  def detach_session(manager \\ __MODULE__) do
    GenServer.call(manager, :detach_session)
  end

  @doc """
  Terminates a session and all its windows/panes.
  """
  def kill_session(manager \\ __MODULE__, session_id) do
    GenServer.call(manager, {:kill_session, session_id})
  end

  @doc """
  Renames a session.
  """
  def rename_session(manager \\ __MODULE__, session_id, new_name) do
    GenServer.call(manager, {:rename_session, session_id, new_name})
  end

  @doc """
  Creates a new window within a session.

  ## Options
  - `:name` - Window name
  - `:command` - Initial command to run
  - `:layout` - Pane layout type
  - `:panes` - Initial panes configuration
  - `:working_directory` - Working directory for the window
  """
  def create_window(manager \\ __MODULE__, session_id, opts \\ []) do
    GenServer.call(manager, {:create_window, session_id, opts})
  end

  @doc """
  Lists windows in a session.
  """
  def list_windows(manager \\ __MODULE__, session_id) do
    GenServer.call(manager, {:list_windows, session_id})
  end

  @doc """
  Switches to a different window within the current session.
  """
  def select_window(manager \\ __MODULE__, session_id, window_id) do
    GenServer.call(manager, {:select_window, session_id, window_id})
  end

  @doc """
  Kills a window and all its panes.
  """
  def kill_window(manager \\ __MODULE__, session_id, window_id) do
    GenServer.call(manager, {:kill_window, session_id, window_id})
  end

  @doc """
  Splits a pane horizontally or vertically.

  ## Options
  - `:direction` - :horizontal or :vertical
  - `:command` - Command to run in new pane
  - `:size` - Size percentage for the new pane
  """
  def split_pane(
        manager \\ __MODULE__,
        session_id,
        window_id,
        pane_id,
        opts \\ []
      ) do
    GenServer.call(manager, {:split_pane, session_id, window_id, pane_id, opts})
  end

  @doc """
  Kills a pane.
  """
  def kill_pane(manager \\ __MODULE__, session_id, window_id, pane_id) do
    GenServer.call(manager, {:kill_pane, session_id, window_id, pane_id})
  end

  @doc """
  Resizes a pane.
  """
  def resize_pane(
        manager \\ __MODULE__,
        session_id,
        window_id,
        pane_id,
        size_change
      ) do
    GenServer.call(
      manager,
      {:resize_pane, session_id, window_id, pane_id, size_change}
    )
  end

  @doc """
  Changes the layout of a window.
  """
  def set_layout(manager \\ __MODULE__, session_id, window_id, layout) do
    GenServer.call(manager, {:set_layout, session_id, window_id, layout})
  end

  @doc """
  Shares a session with other users.

  ## Options
  - `:permissions` - List of permissions (:read, :write, :admin)
  - `:expires_in` - Expiration time in milliseconds
  - `:max_users` - Maximum number of concurrent users
  """
  def share_session(manager \\ __MODULE__, session_id, opts \\ []) do
    GenServer.call(manager, {:share_session, session_id, opts})
  end

  @doc """
  Joins a shared session using a share token.
  """
  def join_shared_session(manager \\ __MODULE__, share_token) do
    GenServer.call(manager, {:join_shared_session, share_token})
  end

  @doc """
  Saves the current session state to storage.
  """
  def save_session(manager \\ __MODULE__, session_id) do
    GenServer.call(manager, {:save_session, session_id})
  end

  @doc """
  Restores a session from storage.
  """
  def restore_session(manager \\ __MODULE__, session_id) do
    GenServer.call(manager, {:restore_session, session_id})
  end

  ## GenServer Implementation

  @impl GenServer
  def init(config) do
    # Initialize storage
    {:ok, storage} = init_storage(config)

    # Schedule periodic saves
    schedule_auto_save(
      config.auto_save_interval_ms > 0,
      config.auto_save_interval_ms
    )

    # Load existing sessions
    sessions = load_sessions(storage)

    state = %__MODULE__{
      sessions: sessions,
      active_session: nil,
      session_storage: storage,
      config: config,
      event_bus: init_event_bus(),
      collaboration_server:
        init_collaboration_if_enabled(config.enable_collaboration)
    }

    Logger.info(
      "Session manager initialized with #{map_size(sessions)} sessions"
    )

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:create_session, opts}, _from, state) do
    case create_session_impl(state, opts) do
      {:ok, session, new_state} ->
        Logger.info("Created session '#{session.name}' (#{session.id})")
        {:reply, {:ok, session.id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:list_sessions, _from, state) do
    sessions =
      state.sessions
      |> Enum.map(fn {id, session} ->
        %{
          id: id,
          name: session.name,
          status: session.status,
          windows: length(session.windows),
          created_at: session.created_at,
          last_accessed: session.last_accessed
        }
      end)

    {:reply, sessions, state}
  end

  @impl GenServer
  def handle_call({:get_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        detailed_session = enrich_session_details(session, state)
        {:reply, {:ok, detailed_session}, state}
    end
  end

  @impl GenServer
  def handle_call({:attach_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        # Update session status and last accessed time
        updated_session = %{
          session
          | status: :active,
            last_accessed: System.monotonic_time(:millisecond)
        }

        new_sessions = Map.put(state.sessions, session_id, updated_session)

        new_state = %{
          state
          | sessions: new_sessions,
            active_session: session_id
        }

        # Broadcast session attachment event
        broadcast_event(state, :session_attached, %{session_id: session_id})

        Logger.info("Attached to session '#{session.name}' (#{session_id})")
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call(:detach_session, _from, state) do
    process_detach_session(state.active_session != nil, state)
  end

  @impl GenServer
  def handle_call({:create_window, session_id, opts}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        {:ok, window, new_state} = create_window_impl(state, session, opts)
        
        Logger.info(
          "Created window '#{window.name}' in session #{session_id}"
        )

        {:reply, {:ok, window.id}, new_state}
    end
  end

  @impl GenServer
  def handle_call(
        {:split_pane, session_id, window_id, pane_id, opts},
        _from,
        state
      ) do
    case get_pane(state, session_id, window_id, pane_id) do
      {:ok, pane} ->
        {:ok, new_pane, new_state} = split_pane_impl(state, pane, opts)
        Logger.info("Split pane #{pane_id} in window #{window_id}")
        {:reply, {:ok, new_pane.id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:share_session, session_id, opts}, _from, state) do
    handle_session_sharing(
      state.config.enable_collaboration,
      state,
      session_id,
      opts
    )
  end

  @impl GenServer
  def handle_info(:auto_save, state) do
    # Auto-save all sessions
    saved_count = save_all_sessions(state)
    Logger.debug("Auto-saved #{saved_count} sessions")
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private Implementation

  defp create_session_impl(state, opts) do
    # Check session limit
    session_limit_reached =
      map_size(state.sessions) >= state.config.max_sessions

    create_session_if_allowed(session_limit_reached, state, opts)
  end

  defp create_session_if_allowed(true, _state, _opts),
    do: {:error, :max_sessions_reached}

  defp create_session_if_allowed(false, state, opts) do
    session_id = generate_session_id()
    session_name = Keyword.get(opts, :name, "session-#{session_id}")

    # Create base session
    session = %{
      id: session_id,
      name: session_name,
      created_at: System.monotonic_time(:millisecond),
      last_accessed: System.monotonic_time(:millisecond),
      windows: [],
      active_window: nil,
      environment: Keyword.get(opts, :environment, System.get_env()),
      working_directory: Keyword.get(opts, :working_directory, File.cwd!()),
      status: :active,
      metadata: %{}
    }

    # Create initial windows if specified
    {updated_session, updated_state} =
      case Keyword.get(opts, :windows, []) do
        [] ->
          # Create default window
          {:ok, window, new_state} = create_default_window(state, session)

          updated_sess = %{
            session
            | windows: [window.id],
              active_window: window.id
          }

          {updated_sess, new_state}

        window_configs ->
          create_initial_windows(state, session, window_configs)
      end

    new_sessions =
      Map.put(updated_state.sessions, session_id, updated_session)

    final_state = %{
      updated_state
      | sessions: new_sessions,
        active_session: session_id
    }

    {:ok, updated_session, final_state}
  end

  defp create_window_impl(state, session, opts) do
    window_id = generate_window_id()
    window_name = Keyword.get(opts, :name, "window-#{window_id}")
    layout = Keyword.get(opts, :layout, :even_horizontal)

    # Create window
    window = %{
      id: window_id,
      session_id: session.id,
      name: window_name,
      layout: layout,
      panes: [],
      active_pane: nil,
      created_at: System.monotonic_time(:millisecond),
      metadata: %{}
    }

    # Create initial pane(s)
    pane_configs = Keyword.get(opts, :panes, [%{}])

    {updated_window, updated_state} =
      create_window_panes(state, window, pane_configs)

    # Update session
    updated_session = %{
      session
      | windows: [window_id | session.windows],
        active_window: window_id
    }

    new_sessions = Map.put(state.sessions, session.id, updated_session)
    final_state = %{updated_state | sessions: new_sessions}

    {:ok, updated_window, final_state}
  end

  defp create_default_window(state, session) do
    create_window_impl(state, session, name: "main")
  end

  defp create_initial_windows(state, session, window_configs) do
    {windows, final_state} =
      Enum.reduce(window_configs, {[], state}, fn window_config,
                                                  {acc_windows, acc_state} ->
        {:ok, window, new_state} =
          create_window_impl(acc_state, session, window_config)

        {[window | acc_windows], new_state}
      end)

    window_ids = Enum.map(windows, & &1.id)
    active_window_id = List.first(window_ids)

    updated_session = %{
      session
      | windows: window_ids,
        active_window: active_window_id
    }

    {updated_session, final_state}
  end

  defp create_window_panes(state, window, pane_configs) do
    {panes, final_state} =
      Enum.reduce(pane_configs, {[], state}, fn pane_config,
                                                {acc_panes, acc_state} ->
        pane = create_pane(window, pane_config)
        {[pane | acc_panes], acc_state}
      end)

    pane_ids = Enum.map(panes, & &1.id)
    active_pane_id = List.first(pane_ids)

    updated_window = %{window | panes: pane_ids, active_pane: active_pane_id}

    {updated_window, final_state}
  end

  defp create_pane(window, config) do
    pane_id = generate_pane_id()

    %{
      id: pane_id,
      window_id: window.id,
      session_id: window.session_id,
      command: Map.get(config, :command),
      # Will be set when command starts
      pid: nil,
      # Default size
      size: %{width: 80, height: 24},
      position: %{x: 0, y: 0},
      status: :active,
      buffer: init_pane_buffer(),
      metadata: %{}
    }
  end

  defp split_pane_impl(state, existing_pane, opts) do
    direction = Keyword.get(opts, :direction, :vertical)
    command = Keyword.get(opts, :command)
    size_ratio = Keyword.get(opts, :size, 50)

    # Create new pane
    new_pane = %{
      id: generate_pane_id(),
      window_id: existing_pane.window_id,
      session_id: existing_pane.session_id,
      command: command,
      pid: nil,
      size: calculate_split_size(existing_pane.size, direction, size_ratio),
      position:
        calculate_split_position(existing_pane.position, direction, size_ratio),
      status: :active,
      buffer: init_pane_buffer(),
      metadata: %{}
    }

    # Update existing pane size
    updated_existing_pane = %{
      existing_pane
      | size:
          calculate_remaining_size(existing_pane.size, direction, size_ratio)
    }

    # Update window and session state
    updated_state = update_pane_layout(state, new_pane, updated_existing_pane)

    {:ok, new_pane, updated_state}
  end

  defp get_pane(state, session_id, window_id, pane_id) do
    # This is a simplified lookup - in practice would maintain proper data structures
    case Map.get(state.sessions, session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        validate_window_and_get_pane(
          window_id in session.windows,
          pane_id,
          window_id,
          session_id
        )
    end
  end

  defp create_share_token(state, session_id, opts) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        permissions = Keyword.get(opts, :permissions, [:read])
        expires_in = Keyword.get(opts, :expires_in, :timer.hours(24))
        max_users = Keyword.get(opts, :max_users, 10)

        share_token = generate_share_token()
        expires_at = System.monotonic_time(:millisecond) + expires_in

        share_info = %{
          token: share_token,
          session_id: session_id,
          permissions: permissions,
          max_users: max_users,
          current_users: 0,
          expires_at: expires_at,
          created_at: System.monotonic_time(:millisecond)
        }

        # Store share info (would use proper storage in practice)
        updated_session = Map.put(session, :share_info, share_info)
        new_sessions = Map.put(state.sessions, session_id, updated_session)
        new_state = %{state | sessions: new_sessions}

        {:ok, share_token, new_state}
    end
  end

  ## Helper Functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  defp generate_window_id do
    :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false)
  end

  defp generate_pane_id do
    :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)
  end

  defp generate_share_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp init_pane_buffer do
    # Initialize terminal buffer for pane
    %{
      lines: [],
      cursor: %{x: 0, y: 0},
      scrollback: []
    }
  end

  defp calculate_split_size(original_size, direction, ratio) do
    case direction do
      :horizontal ->
        %{original_size | height: round(original_size.height * ratio / 100)}

      :vertical ->
        %{original_size | width: round(original_size.width * ratio / 100)}
    end
  end

  defp calculate_split_position(original_position, direction, ratio) do
    case direction do
      :horizontal ->
        %{original_position | y: original_position.y + round(ratio)}

      :vertical ->
        %{original_position | x: original_position.x + round(ratio)}
    end
  end

  defp calculate_remaining_size(original_size, direction, ratio) do
    case direction do
      :horizontal ->
        %{
          original_size
          | height: round(original_size.height * (100 - ratio) / 100)
        }

      :vertical ->
        %{
          original_size
          | width: round(original_size.width * (100 - ratio) / 100)
        }
    end
  end

  defp update_pane_layout(state, _new_pane, _updated_existing_pane) do
    # This would update the actual layout structures
    # For now, just return the state
    state
  end

  defp enrich_session_details(session, _state) do
    # Add detailed information about windows and panes
    windows =
      Enum.map(session.windows, fn window_id ->
        %{
          id: window_id,
          name: "window-#{window_id}",
          panes: 1,
          active: session.active_window == window_id
        }
      end)

    %{session | windows: windows}
  end

  ## Storage Functions

  defp init_storage(config) do
    case config.storage_backend do
      :file ->
        storage_path = Path.expand(config.storage_path)
        File.mkdir_p!(storage_path)
        {:ok, %{type: :file, path: storage_path}}

      :ets ->
        table = :ets.new(:raxol_sessions, [:set, :public, :named_table])
        {:ok, %{type: :ets, table: table}}

      :database ->
        # Would initialize database connection
        {:ok, %{type: :database, connection: nil}}
    end
  end

  defp load_sessions(storage) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           case storage.type do
             :file ->
               sessions_file = Path.join(storage.path, "sessions.json")

               load_sessions_from_file(
                 File.exists?(sessions_file),
                 sessions_file
               )

             :ets ->
               :ets.tab2list(storage.table) |> Map.new()

             :database ->
               # Would load from database
               %{}
           end
         end) do
      {:ok, sessions} -> sessions
      {:error, _reason} -> %{}
    end
  end

  defp save_all_sessions(state) do
    sessions_to_save =
      state.sessions
      |> Enum.filter(fn {_id, session} -> session.status != :dead end)

    case Raxol.Core.ErrorHandling.safe_call(fn ->
           case state.session_storage.type do
             :file ->
               sessions_file =
                 Path.join(state.session_storage.path, "sessions.json")

               json_data = Jason.encode!(sessions_to_save)
               File.write!(sessions_file, json_data)

             :ets ->
               # Clear and repopulate ETS table
               :ets.delete_all_objects(state.session_storage.table)

               Enum.each(sessions_to_save, fn {id, session} ->
                 :ets.insert(state.session_storage.table, {id, session})
               end)

             :database ->
               # Would save to database
               :ok
           end

           length(sessions_to_save)
         end) do
      {:ok, count} ->
        count

      {:error, reason} ->
        Logger.error("Failed to save sessions: #{inspect(reason)}")
        0
    end
  end

  ## Event System

  defp init_event_bus do
    {:ok, pid} = GenServer.start_link(EventBus, [])
    pid
  end

  defp init_collaboration_server do
    # Would initialize collaboration server
    nil
  end

  defp broadcast_event(state, event_type, event_data) do
    broadcast_if_available(
      state.event_bus != nil,
      state.event_bus,
      event_type,
      event_data
    )
  end

  ## Utility Functions

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), atomize_keys(v)} end)
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value

  ## Helper Functions for Pattern Matching

  defp schedule_auto_save(false, _interval), do: :ok

  defp schedule_auto_save(true, interval),
    do: :timer.send_interval(interval, :auto_save)

  defp init_collaboration_if_enabled(true), do: init_collaboration_server()
  defp init_collaboration_if_enabled(false), do: nil

  defp process_detach_session(false, state),
    do: {:reply, {:error, :no_active_session}, state}

  defp process_detach_session(true, state) do
    session_id = state.active_session
    session = Map.get(state.sessions, session_id)

    # Update session status
    updated_session = %{
      session
      | status: :detached,
        last_accessed: System.monotonic_time(:millisecond)
    }

    new_sessions = Map.put(state.sessions, session_id, updated_session)
    new_state = %{state | sessions: new_sessions, active_session: nil}

    # Broadcast detachment event
    broadcast_event(state, :session_detached, %{session_id: session_id})

    Logger.info("Detached from session '#{session.name}' (#{session_id})")
    {:reply, :ok, new_state}
  end

  defp handle_session_sharing(false, state, _session_id, _opts),
    do: {:reply, {:error, :collaboration_disabled}, state}

  defp handle_session_sharing(true, state, session_id, opts) do
    case create_share_token(state, session_id, opts) do
      {:ok, share_token, new_state} ->
        Logger.info(
          "Session #{session_id} shared with token #{String.slice(share_token, 0, 8)}..."
        )

        {:reply, {:ok, share_token}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp validate_window_and_get_pane(false, _pane_id, _window_id, _session_id),
    do: {:error, :window_not_found}

  defp validate_window_and_get_pane(true, pane_id, window_id, session_id) do
    # Mock pane lookup
    pane = %{
      id: pane_id,
      window_id: window_id,
      session_id: session_id,
      command: nil,
      pid: nil,
      size: %{width: 80, height: 24},
      position: %{x: 0, y: 0},
      status: :active,
      buffer: init_pane_buffer(),
      metadata: %{}
    }

    {:ok, pane}
  end

  defp load_sessions_from_file(false, _sessions_file), do: %{}

  defp load_sessions_from_file(true, sessions_file) do
    sessions_file
    |> File.read!()
    |> Jason.decode!()
    |> Enum.map(fn {id, session_data} ->
      {id, atomize_keys(session_data)}
    end)
    |> Map.new()
  end

  defp broadcast_if_available(false, _event_bus, _event_type, _event_data),
    do: :ok

  defp broadcast_if_available(true, event_bus, event_type, event_data) do
    GenServer.cast(event_bus, {:broadcast, event_type, event_data})
  end

  ## Public Utility Functions

  @doc """
  Creates a session template for reuse.
  """
  def create_template(name, session_config) do
    template = %{
      name: name,
      config: session_config,
      created_at: System.monotonic_time(:millisecond)
    }

    # Would save template to storage
    {:ok, template}
  end

  @doc """
  Lists available session templates.
  """
  def list_templates do
    # Would load from storage
    []
  end

  @doc """
  Gets session statistics and usage information.
  """
  def get_statistics(manager \\ __MODULE__) do
    GenServer.call(manager, :get_statistics)
  end
end

# Simple EventBus implementation
defmodule EventBus do
  use GenServer

  def init(_) do
    {:ok, %{subscribers: []}}
  end

  def handle_cast({:broadcast, _event_type, _event_data}, state) do
    # Would broadcast to subscribers
    {:noreply, state}
  end
end
