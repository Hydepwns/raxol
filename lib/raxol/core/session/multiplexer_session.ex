defmodule Raxol.Core.Session.MultiplexerSession do
  @moduledoc """
  Multiplexer session implementation for the unified session manager.

  Provides tmux-like session management with:
  - Multiple terminal sessions with independent state
  - Window and pane management within sessions
  - Session persistence across disconnections
  - Remote session attachment and detachment
  - Session sharing and collaboration features
  """

  require Logger

  defstruct [
    :id,
    :name,
    :created_at,
    :last_activity,
    :status,
    :metadata,
    :windows,
    :active_window,
    :clients
  ]

  defmodule Window do
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
  end

  defmodule Pane do
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
  end

  defmodule Client do
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
  end

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          created_at: integer(),
          last_activity: integer(),
          status: :active | :inactive | :detached,
          metadata: map(),
          windows: [Window.t()],
          active_window: String.t() | nil,
          clients: [Client.t()]
        }

  ## Public API

  @doc """
  Creates a new multiplexer session.
  """
  def create(name, config, _global_config) do
    session_id = generate_session_id(name)
    now = System.monotonic_time(:millisecond)

    session = %__MODULE__{
      id: session_id,
      name: name,
      created_at: now,
      last_activity: now,
      status: :active,
      metadata: Map.get(config, :metadata, %{}),
      windows: [],
      active_window: nil,
      clients: []
    }

    # Create initial windows
    {updated_session, _windows} = create_initial_windows(session, config)

    {:ok, updated_session}
  end

  @doc """
  Creates a summary of the session for listing.
  """
  def summary(session) do
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

  @doc """
  Attaches a client to the session.
  """
  def attach_client(session, client_config) do
    client_id = generate_client_id()

    client = %Client{
      id: client_id,
      session_id: session.id,
      connection_type: Map.get(client_config, :connection_type, :local),
      connected_at: System.monotonic_time(:millisecond),
      last_activity: System.monotonic_time(:millisecond),
      terminal_size: Map.get(client_config, :terminal_size, {80, 24}),
      capabilities:
        Map.get(client_config, :capabilities, [:resize, :color, :mouse]),
      metadata: Map.get(client_config, :metadata, %{})
    }

    updated_session = %{
      session
      | clients: [client | session.clients],
        status: :active,
        last_activity: System.monotonic_time(:millisecond)
    }

    {:ok, client, updated_session}
  end

  @doc """
  Cleans up expired multiplexer sessions.
  """
  def cleanup_expired(sessions, config) do
    now = System.monotonic_time(:millisecond)
    timeout_ms = config.session_timeout_minutes * 60 * 1000

    sessions
    |> Enum.filter(fn {_id, session} ->
      case session.status do
        :detached ->
          # Keep if not expired
          now - session.last_activity <= timeout_ms

        _ ->
          # Keep active and inactive sessions
          true
      end
    end)
    |> Map.new()
  end

  @doc """
  Gets all sessions for a user (multiplexer sessions don't have user_id directly).
  """
  def get_user_sessions(_user_id, sessions) do
    # Multiplexer sessions are typically not tied to specific users
    # but rather to client connections
    sessions
    |> Enum.map(fn {_id, session} -> summary(session) end)
  end

  ## Private Functions

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
          panes: [%{command: nil}]
        })
      end)

    active_window =
      case windows do
        [first | _] -> first.id
        [] -> nil
      end

    updated_session = %{
      session
      | windows: windows,
        active_window: active_window
    }

    {updated_session, windows}
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
      active_pane:
        case panes do
          [first | _] -> first.id
          [] -> nil
        end,
      metadata: Map.get(config, :metadata, %{})
    }
  end

  defp create_pane(window_id, config, index) do
    pane_id = generate_pane_id()
    working_dir = Map.get(config, :working_directory, System.user_home!())
    command = Map.get(config, :command)
    environment = Map.get(config, :environment, %{})

    %Pane{
      id: pane_id,
      window_id: window_id,
      # Would start terminal process in production
      terminal: nil,
      position: {0, index * 25},
      size: {80, 24},
      command: command,
      working_directory: working_dir,
      environment: environment,
      status: :running,
      created_at: System.monotonic_time(:millisecond)
    }
  end

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
end
