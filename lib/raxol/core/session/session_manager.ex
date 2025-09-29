defmodule Raxol.Core.Session.SessionManager do
  @moduledoc """
  Unified session management system for Raxol applications.

  This module consolidates all session management capabilities across different domains:
  - Security sessions (secure tokens, CSRF, authentication)
  - Web sessions (HTTP session management, storage, recovery)
  - Terminal sessions (terminal emulator sessions)
  - Multiplexer sessions (tmux-like session management)

  ## Features

  ### Security Sessions
  - Cryptographically secure session tokens
  - Session expiration and renewal
  - Concurrent session limiting
  - Session fixation protection
  - CSRF token generation and validation

  ### Web Sessions
  - Session storage and retrieval
  - Session recovery and cleanup
  - Session limits and monitoring
  - Session metadata management

  ### Terminal Sessions
  - Terminal emulator session management
  - Session authentication and state tracking
  - Session cleanup and lifecycle management

  ### Multiplexer Sessions
  - tmux-like session management
  - Window and pane management
  - Session persistence and recovery
  - Remote session attachment/detachment

  ## Usage

      # Security session
      {:ok, session} = UnifiedSessionManager.create_security_session("user123", 
        ip_address: "192.168.1.1",
        user_agent: "Browser/1.0"
      )

      # Web session  
      {:ok, session} = UnifiedSessionManager.create_web_session("user123", %{
        preferences: %{theme: "dark"}
      })

      # Terminal session
      {:ok, session} = UnifiedSessionManager.create_terminal_session("user123")

      # Multiplexer session
      {:ok, session} = UnifiedSessionManager.create_multiplexer_session("dev-work",
        windows: 3,
        layout: :main_vertical
      )
  """

  use Raxol.Core.Behaviours.BaseManager

  require Logger

  alias Raxol.Core.Session.{
    SecuritySession,
    WebSession,
    TerminalSession,
    MultiplexerSession
  }

  defstruct [
    :security_sessions,
    :web_sessions,
    :terminal_sessions,
    :multiplexer_sessions,
    :config,
    :cleanup_timer
  ]

  @default_config %{
    # Security session defaults
    # 30 minutes
    security_session_timeout_ms: 30 * 60 * 1000,
    max_concurrent_sessions: 5,
    token_bytes: 32,

    # Web session defaults
    web_session_timeout: :timer.hours(1),
    max_web_sessions: 1000,
    cleanup_interval: :timer.minutes(5),

    # Terminal session defaults
    terminal_scrollback_lines: 1000,
    max_terminal_sessions: 100,

    # Multiplexer session defaults
    max_multiplexer_sessions: 50,
    max_windows_per_session: 20,
    max_panes_per_window: 16,
    # 24 hours
    session_timeout_minutes: 1440,
    persistence_enabled: true,
    persistence_directory: "~/.raxol/sessions"
  }

  ## Public API

  @doc """
  Starts the unified session manager.
  """
  # BaseManager provides start_link/1 and start_link/2 automatically
  # We need to override for custom configuration handling
  def start_link(opts) when is_list(opts) do
    config =
      Keyword.get(opts, :config, %{}) |> then(&Map.merge(@default_config, &1))

    Raxol.Core.Behaviours.BaseManager.start_link(__MODULE__, config, name: __MODULE__)
  end

  def start_link(config) do
    merged_config = Map.merge(@default_config, config)
    Raxol.Core.Behaviours.BaseManager.start_link(__MODULE__, merged_config, name: __MODULE__)
  end

  ## Security Session API

  @doc """
  Creates a new secure session with cryptographic tokens.
  """
  def create_security_session(user_id, opts \\ []) do
    GenServer.call(__MODULE__, {:create_security_session, user_id, opts})
  end

  @doc """
  Validates a security session token.
  """
  def validate_security_session(session_id, token) do
    GenServer.call(__MODULE__, {:validate_security_session, session_id, token})
  end

  @doc """
  Invalidates a security session.
  """
  def invalidate_security_session(session_id) do
    GenServer.call(__MODULE__, {:invalidate_security_session, session_id})
  end

  @doc """
  Invalidates all security sessions for a user.
  """
  def invalidate_user_security_sessions(user_id) do
    GenServer.call(__MODULE__, {:invalidate_user_security_sessions, user_id})
  end

  @doc """
  Generates a CSRF token for a security session.
  """
  def generate_csrf_token(session_id) do
    GenServer.call(__MODULE__, {:generate_csrf_token, session_id})
  end

  @doc """
  Validates a CSRF token.
  """
  def validate_csrf_token(session_id, token) do
    GenServer.call(__MODULE__, {:validate_csrf_token, session_id, token})
  end

  ## Web Session API

  @doc """
  Creates a new web session with storage capabilities.
  """
  def create_web_session(user_id, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:create_web_session, user_id, metadata})
  end

  @doc """
  Gets a web session by ID.
  """
  def get_web_session(session_id) do
    GenServer.call(__MODULE__, {:get_web_session, session_id})
  end

  @doc """
  Updates web session metadata.
  """
  def update_web_session(session_id, metadata) do
    GenServer.call(__MODULE__, {:update_web_session, session_id, metadata})
  end

  @doc """
  Ends a web session.
  """
  def end_web_session(session_id) do
    GenServer.call(__MODULE__, {:end_web_session, session_id})
  end

  ## Terminal Session API

  @doc """
  Creates a new terminal session.
  """
  def create_terminal_session(user_id) do
    GenServer.call(__MODULE__, {:create_terminal_session, user_id})
  end

  @doc """
  Gets a terminal session by ID.
  """
  def get_terminal_session(session_id) do
    GenServer.call(__MODULE__, {:get_terminal_session, session_id})
  end

  @doc """
  Authenticates a terminal session.
  """
  def authenticate_terminal_session(session_id, token) do
    GenServer.call(
      __MODULE__,
      {:authenticate_terminal_session, session_id, token}
    )
  end

  @doc """
  Cleans up a terminal session.
  """
  def cleanup_terminal_session(session_id) do
    GenServer.call(__MODULE__, {:cleanup_terminal_session, session_id})
  end

  ## Multiplexer Session API

  @doc """
  Creates a new multiplexer session with tmux-like capabilities.
  """
  def create_multiplexer_session(name, config \\ %{}) do
    GenServer.call(__MODULE__, {:create_multiplexer_session, name, config})
  end

  @doc """
  Lists all multiplexer sessions.
  """
  def list_multiplexer_sessions do
    GenServer.call(__MODULE__, :list_multiplexer_sessions)
  end

  @doc """
  Attaches to a multiplexer session.
  """
  def attach_multiplexer_session(session_id, client_config \\ %{}) do
    GenServer.call(
      __MODULE__,
      {:attach_multiplexer_session, session_id, client_config}
    )
  end

  @doc """
  Detaches from a multiplexer session.
  """
  def detach_multiplexer_session(client_id) do
    GenServer.call(__MODULE__, {:detach_multiplexer_session, client_id})
  end

  @doc """
  Creates a window in a multiplexer session.
  """
  def create_multiplexer_window(session_id, window_name, config \\ %{}) do
    GenServer.call(
      __MODULE__,
      {:create_multiplexer_window, session_id, window_name, config}
    )
  end

  @doc """
  Splits a pane in a multiplexer session.
  """
  def split_multiplexer_pane(
        session_id,
        window_id,
        pane_id,
        direction,
        config \\ %{}
      ) do
    GenServer.call(
      __MODULE__,
      {:split_multiplexer_pane, session_id, window_id, pane_id, direction,
       config}
    )
  end

  ## Utility API

  @doc """
  Gets statistics for all session types.
  """
  def get_session_statistics do
    GenServer.call(__MODULE__, :get_session_statistics)
  end

  @doc """
  Performs cleanup across all session types.
  """
  def cleanup_all_sessions do
    GenServer.call(__MODULE__, :cleanup_all_sessions)
  end

  @doc """
  Gets active sessions for a user across all types.
  """
  def get_user_sessions(user_id) do
    GenServer.call(__MODULE__, {:get_user_sessions, user_id})
  end

  ## GenServer Implementation

  @impl true
  def init_manager(config) do
    # Initialize session storage structures
    state = %__MODULE__{
      security_sessions: init_security_storage(config),
      web_sessions: %{},
      terminal_sessions: %{},
      multiplexer_sessions: %{},
      config: config
    }

    # Start cleanup timer
    cleanup_timer = schedule_cleanup(config.cleanup_interval)
    final_state = %{state | cleanup_timer: cleanup_timer}

    Logger.info("Unified session manager initialized")
    {:ok, final_state}
  end

  ## Security Session Handlers

  @impl true
  def handle_manager_call({:create_security_session, user_id, opts}, _from, state) do
    case SecuritySession.create(
           user_id,
           opts,
           state.config,
           state.security_sessions
         ) do
      {:ok, session_info, updated_sessions} ->
        new_state = %{state | security_sessions: updated_sessions}
        {:reply, {:ok, session_info}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:validate_security_session, session_id, token}, _from, state) do
    case SecuritySession.validate(session_id, token, state.security_sessions) do
      {:ok, session_info, updated_sessions} ->
        new_state = %{state | security_sessions: updated_sessions}
        {:reply, {:ok, session_info}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:invalidate_security_session, session_id}, _from, state) do
    updated_sessions =
      SecuritySession.invalidate(session_id, state.security_sessions)

    new_state = %{state | security_sessions: updated_sessions}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:invalidate_user_security_sessions, user_id}, _from, state) do
    {count, updated_sessions} =
      SecuritySession.invalidate_user_sessions(user_id, state.security_sessions)

    new_state = %{state | security_sessions: updated_sessions}
    {:reply, {:ok, count}, new_state}
  end

  @impl true
  def handle_manager_call({:generate_csrf_token, session_id}, _from, state) do
    token = SecuritySession.generate_csrf_token(session_id)
    {:reply, {:ok, token}, state}
  end

  @impl true
  def handle_manager_call({:validate_csrf_token, session_id, token}, _from, state) do
    valid = SecuritySession.validate_csrf_token(session_id, token)
    {:reply, {:ok, valid}, state}
  end

  ## Web Session Handlers

  @impl true
  def handle_manager_call({:create_web_session, user_id, metadata}, _from, state) do
    {:ok, session} = WebSession.create(user_id, metadata, state.config)
    updated_sessions = Map.put(state.web_sessions, session.id, session)
    new_state = %{state | web_sessions: updated_sessions}
    {:reply, {:ok, session}, new_state}
  end

  @impl true
  def handle_manager_call({:get_web_session, session_id}, _from, state) do
    case Map.get(state.web_sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      session ->
        # Update last active time
        updated_session = WebSession.touch(session)

        updated_sessions =
          Map.put(state.web_sessions, session_id, updated_session)

        new_state = %{state | web_sessions: updated_sessions}
        {:reply, {:ok, updated_session}, new_state}
    end
  end

  @impl true
  def handle_manager_call({:update_web_session, session_id, metadata}, _from, state) do
    case Map.get(state.web_sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      session ->
        updated_session = WebSession.update_metadata(session, metadata)

        updated_sessions =
          Map.put(state.web_sessions, session_id, updated_session)

        new_state = %{state | web_sessions: updated_sessions}
        {:reply, {:ok, updated_session}, new_state}
    end
  end

  @impl true
  def handle_manager_call({:end_web_session, session_id}, _from, state) do
    case Map.get(state.web_sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _session ->
        updated_sessions = Map.delete(state.web_sessions, session_id)
        new_state = %{state | web_sessions: updated_sessions}
        {:reply, :ok, new_state}
    end
  end

  ## Terminal Session Handlers

  @impl true
  def handle_manager_call({:create_terminal_session, user_id}, _from, state) do
    {:ok, session} = TerminalSession.create(user_id, state.config)
    updated_sessions = Map.put(state.terminal_sessions, session.id, session)
    new_state = %{state | terminal_sessions: updated_sessions}
    {:reply, {:ok, session}, new_state}
  end

  @impl true
  def handle_manager_call({:get_terminal_session, session_id}, _from, state) do
    case Map.get(state.terminal_sessions, session_id) do
      nil -> {:reply, {:error, :not_found}, state}
      session -> {:reply, {:ok, session}, state}
    end
  end

  @impl true
  def handle_manager_call(
        {:authenticate_terminal_session, session_id, token},
        _from,
        state
      ) do
    case Map.get(state.terminal_sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      session ->
        case TerminalSession.authenticate(session, token) do
          {:ok, updated_session} ->
            updated_sessions =
              Map.put(state.terminal_sessions, session_id, updated_session)

            new_state = %{state | terminal_sessions: updated_sessions}
            {:reply, {:ok, updated_session}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_manager_call({:cleanup_terminal_session, session_id}, _from, state) do
    updated_sessions = Map.delete(state.terminal_sessions, session_id)
    new_state = %{state | terminal_sessions: updated_sessions}
    {:reply, :ok, new_state}
  end

  ## Multiplexer Session Handlers

  @impl true
  def handle_manager_call({:create_multiplexer_session, name, config}, _from, state) do
    {:ok, session} = MultiplexerSession.create(name, config, state.config)

    updated_sessions =
      Map.put(state.multiplexer_sessions, session.id, session)

    new_state = %{state | multiplexer_sessions: updated_sessions}
    {:reply, {:ok, session}, new_state}
  end

  @impl true
  def handle_manager_call(:list_multiplexer_sessions, _from, state) do
    sessions =
      state.multiplexer_sessions
      |> Map.values()
      |> Enum.map(&MultiplexerSession.summary/1)

    {:reply, sessions, state}
  end

  @impl true
  def handle_manager_call(
        {:attach_multiplexer_session, session_id, client_config},
        _from,
        state
      ) do
    case Map.get(state.multiplexer_sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        case MultiplexerSession.attach_client(session, client_config) do
          {:ok, client, updated_session} ->
            updated_sessions =
              Map.put(state.multiplexer_sessions, session_id, updated_session)

            new_state = %{state | multiplexer_sessions: updated_sessions}
            {:reply, {:ok, client}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  ## Utility Handlers

  @impl true
  def handle_manager_call(:get_session_statistics, _from, state) do
    stats = %{
      security_sessions: SecuritySession.get_stats(state.security_sessions),
      web_sessions: map_size(state.web_sessions),
      terminal_sessions: map_size(state.terminal_sessions),
      multiplexer_sessions: map_size(state.multiplexer_sessions),
      total_sessions:
        SecuritySession.count(state.security_sessions) +
          map_size(state.web_sessions) +
          map_size(state.terminal_sessions) +
          map_size(state.multiplexer_sessions)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_manager_call(:cleanup_all_sessions, _from, state) do
    Logger.info("Running unified session cleanup")

    # Cleanup security sessions
    updated_security =
      SecuritySession.cleanup_expired(state.security_sessions, state.config)

    # Cleanup web sessions
    updated_web = WebSession.cleanup_expired(state.web_sessions, state.config)

    # Cleanup terminal sessions (no specific expiration logic for now)
    updated_terminal = state.terminal_sessions

    # Cleanup multiplexer sessions
    updated_multiplexer =
      MultiplexerSession.cleanup_expired(
        state.multiplexer_sessions,
        state.config
      )

    new_state = %{
      state
      | security_sessions: updated_security,
        web_sessions: updated_web,
        terminal_sessions: updated_terminal,
        multiplexer_sessions: updated_multiplexer
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:get_user_sessions, user_id}, _from, state) do
    user_sessions = %{
      security:
        SecuritySession.get_user_sessions(user_id, state.security_sessions),
      web: WebSession.get_user_sessions(user_id, state.web_sessions),
      terminal:
        TerminalSession.get_user_sessions(user_id, state.terminal_sessions),
      multiplexer:
        MultiplexerSession.get_user_sessions(
          user_id,
          state.multiplexer_sessions
        )
    }

    {:reply, user_sessions, state}
  end

  @impl true
  def handle_manager_info(:cleanup_timer, state) do
    {:reply, _status, new_state} =
      handle_call(:cleanup_all_sessions, self(), state)

    # Schedule next cleanup
    cleanup_timer = schedule_cleanup(state.config.cleanup_interval)
    final_state = %{new_state | cleanup_timer: cleanup_timer}

    {:noreply, final_state}
  end

  ## Private Functions

  @spec init_security_storage(map()) :: any()
  defp init_security_storage(config) do
    # Initialize ETS tables for security sessions (safe creation)
    _ =
      Raxol.Core.CompilerState.ensure_table(:unified_security_sessions, [
        :set,
        :private,
        :named_table
      ])

    _ =
      Raxol.Core.CompilerState.ensure_table(:unified_user_security_sessions, [
        :bag,
        :private,
        :named_table
      ])

    %{
      timeout: config.security_session_timeout_ms,
      max_concurrent: config.max_concurrent_sessions,
      token_bytes: config.token_bytes
    }
  end

  @spec schedule_cleanup(any()) :: any()
  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup_timer, interval)
  end
end
