defmodule Raxol.Terminal.UnifiedSessionManager do
  @moduledoc """
  Unified session management interface consolidating multiple session management approaches.

  This module provides a single interface for:
  - Simple terminal sessions (single emulator per session)
  - Advanced multiplexing sessions (tmux-like windows and panes)
  - Session persistence and recovery
  - Authentication and security
  - Registry and lookup operations

  ## Usage Modes

  ### Simple Mode (Legacy compatibility)
      # Create a basic terminal session
      {:ok, session} = UnifiedSessionManager.create_simple_session(user_id, %{
        width: 80, 
        height: 24
      })
      
  ### Advanced Mode (Multiplexing)
      # Create a multiplexed session with windows and panes
      {:ok, session} = UnifiedSessionManager.create_session("dev-work", %{
        windows: 3,
        layout: :main_vertical,
        persistence: true
      })
      
  ### Registry Operations
      sessions = UnifiedSessionManager.list_sessions()
      {:ok, session} = UnifiedSessionManager.get_session(session_id)
  """

  use GenServer
  require Logger

  # Delegate to appropriate implementation based on session type
  alias Raxol.Terminal.Multiplexing.SessionManager, as: MultiplexingManager
  alias Raxol.Terminal.SessionManager, as: SimpleManager
  alias Raxol.Terminal.Session, as: GenServerSession
  alias Raxol.Core.UnifiedRegistry

  defmodule SessionBehaviour do
    @moduledoc """
    Behaviour defining the unified session management interface.
    """

    @callback create_session(String.t(), map()) ::
                {:ok, term()} | {:error, term()}
    @callback destroy_session(String.t()) :: :ok | {:error, term()}
    @callback get_session(String.t()) :: {:ok, term()} | {:error, term()}
    @callback list_sessions() :: [term()]
    @callback authenticate_session(String.t(), String.t()) ::
                {:ok, term()} | {:error, term()}
  end

  @behaviour SessionBehaviour

  @type session_type :: :simple | :multiplexed | :genserver
  @type session_config :: %{
          type: session_type(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          windows: non_neg_integer(),
          layout: atom(),
          persistence: boolean(),
          authentication: boolean()
        }

  # Client API

  @doc """
  Starts the unified session manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a session using the unified interface.

  The session type is determined by the configuration:
  - If `windows` > 1 or `layout` specified: multiplexed session
  - If `persistence` or advanced features: GenServer session
  - Otherwise: simple session
  """
  @impl true
  def create_session(name_or_user_id, config \\ %{}) do
    session_type = determine_session_type(config)
    create_session_by_type(session_type, name_or_user_id, config)
  end

  @doc """
  Creates a simple terminal session (legacy compatibility).
  """
  def create_simple_session(user_id, config \\ %{}) do
    config_with_type = Map.put(config, :type, :simple)
    create_session(user_id, config_with_type)
  end

  @doc """
  Creates a multiplexed session with windows and panes.
  """
  def create_multiplexed_session(name, config \\ %{}) do
    config_with_type = Map.put(config, :type, :multiplexed)
    create_session(name, config_with_type)
  end

  @doc """
  Creates a persistent GenServer session.
  """
  def create_persistent_session(id, config \\ %{}) do
    config_with_type = Map.put(config, :type, :genserver)
    create_session(id, config_with_type)
  end

  @doc """
  Gets a session by ID, regardless of type.
  """
  @impl true
  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  @doc """
  Lists all sessions across all types.
  """
  @impl true
  def list_sessions do
    GenServer.call(__MODULE__, :list_sessions)
  end

  @doc """
  Destroys a session regardless of type.
  """
  @impl true
  def destroy_session(session_id) do
    GenServer.call(__MODULE__, {:destroy_session, session_id})
  end

  @doc """
  Authenticates a session (for sessions with authentication enabled).
  """
  @impl true
  def authenticate_session(session_id, token) do
    GenServer.call(__MODULE__, {:authenticate_session, session_id, token})
  end

  @doc """
  Attaches a client to a session (multiplexed sessions only).
  """
  def attach_session(session_id, client_config \\ %{}) do
    case get_session_type(session_id) do
      {:ok, :multiplexed} ->
        MultiplexingManager.attach_session(session_id, client_config)

      {:ok, _other_type} ->
        {:error, :not_multiplexed_session}

      error ->
        error
    end
  end

  @doc """
  Creates a window in a multiplexed session.
  """
  def create_window(session_id, window_name, config \\ %{}) do
    case get_session_type(session_id) do
      {:ok, :multiplexed} ->
        MultiplexingManager.create_window(session_id, window_name, config)

      {:ok, _other_type} ->
        {:error, :not_multiplexed_session}

      error ->
        error
    end
  end

  @doc """
  Sends input to a session.
  """
  def send_input(session_id, input, target \\ nil) do
    GenServer.call(__MODULE__, {:send_input, session_id, input, target})
  end

  @doc """
  Saves a session to persistent storage.
  """
  def save_session(session_id) do
    GenServer.call(__MODULE__, {:save_session, session_id})
  end

  @doc """
  Loads a session from persistent storage.
  """
  def load_session(session_id) do
    GenServer.call(__MODULE__, {:load_session, session_id})
  end

  # GenServer Implementation

  @impl GenServer
  def init(opts) do
    # Start required child managers
    {:ok, _registry} =
      Registry.start_link(keys: :unique, name: :session_registry)

    {:ok, _simple} = SimpleManager.start_link(opts)
    {:ok, _multiplexing} = MultiplexingManager.start_link()

    state = %{
      # session_id -> session_type mapping
      session_types: %{},
      config: Keyword.get(opts, :config, %{})
    }

    Logger.info("Unified Session Manager started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:get_session, session_id}, _from, state) do
    result =
      case get_session_type_from_state(state, session_id) do
        {:ok, :simple} ->
          # Simple sessions are stateless, create a stub
          {:ok, %{id: session_id, type: :simple}}

        {:ok, :multiplexed} ->
          MultiplexingManager.get_session(session_id)

        {:ok, :genserver} ->
          case UnifiedRegistry.lookup(:sessions, session_id) do
            [] -> {:error, :not_found}
            [{pid, _}] -> {:ok, GenServerSession.get_state(pid)}
          end

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:list_sessions, _from, state) do
    # Aggregate sessions from all sources
    simple_sessions = get_simple_sessions()
    multiplexed_sessions = MultiplexingManager.list_sessions()
    genserver_sessions = get_genserver_sessions()

    all_sessions = simple_sessions ++ multiplexed_sessions ++ genserver_sessions
    {:reply, all_sessions, state}
  end

  @impl GenServer
  def handle_call({:destroy_session, session_id}, _from, state) do
    result =
      case get_session_type_from_state(state, session_id) do
        {:ok, :simple} ->
          # Simple sessions don't need cleanup
          :ok

        {:ok, :multiplexed} ->
          MultiplexingManager.destroy_session(session_id)

        {:ok, :genserver} ->
          case UnifiedRegistry.lookup(:sessions, session_id) do
            [] -> {:error, :not_found}
            [{pid, _}] -> GenServerSession.stop(pid)
          end

        {:error, reason} ->
          {:error, reason}
      end

    # Remove from session type tracking
    new_state = %{
      state
      | session_types: Map.delete(state.session_types, session_id)
    }

    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call({:authenticate_session, session_id, token}, _from, state) do
    result =
      case get_session_type_from_state(state, session_id) do
        {:ok, :simple} ->
          SimpleManager.authenticate_session(session_id, token)

        {:ok, _other_type} ->
          {:error, :authentication_not_supported}

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:send_input, session_id, input, target}, _from, state) do
    result =
      case get_session_type_from_state(state, session_id) do
        {:ok, :simple} ->
          # Simple sessions don't track state, so we can't send input
          {:error, :not_implemented}

        {:ok, :multiplexed} ->
          case target do
            %{window_id: window_id, pane_id: pane_id} ->
              MultiplexingManager.send_input(
                session_id,
                window_id,
                pane_id,
                input
              )

            %{window_id: window_id} ->
              MultiplexingManager.broadcast_input(session_id, window_id, input)

            nil ->
              {:error, :target_required_for_multiplexed}
          end

        {:ok, :genserver} ->
          case UnifiedRegistry.lookup(:sessions, session_id) do
            [] ->
              {:error, :not_found}

            [{pid, _}] ->
              GenServerSession.send_input(pid, input)
              {:ok, :sent}
          end

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:save_session, session_id}, _from, state) do
    result =
      case get_session_type_from_state(state, session_id) do
        {:ok, :simple} ->
          {:error, :simple_sessions_not_persistent}

        {:ok, :multiplexed} ->
          MultiplexingManager.save_session(session_id)

        {:ok, :genserver} ->
          case UnifiedRegistry.lookup(:sessions, session_id) do
            [] -> {:error, :not_found}
            [{pid, _}] -> GenServerSession.save_session(pid)
          end

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:create_session, type, name_or_id, config}, _from, state) do
    {result, new_state} =
      handle_session_creation(type, name_or_id, config, state)

    {:reply, result, new_state}
  end

  # Private Helper Functions

  defp determine_session_type(config) do
    cond do
      Map.get(config, :type) -> Map.get(config, :type)
      Map.get(config, :windows, 1) > 1 -> :multiplexed
      Map.get(config, :layout) -> :multiplexed
      Map.get(config, :persistence, false) -> :genserver
      Map.get(config, :auto_save, false) -> :genserver
      true -> :simple
    end
  end

  defp create_session_by_type(type, name_or_id, config) do
    GenServer.call(__MODULE__, {:create_session, type, name_or_id, config})
  end

  defp handle_session_creation(:simple, user_id, config, state) do
    case create_simple_session(user_id, config) do
      {:ok, session} ->
        session_id = session.id
        new_session_types = Map.put(state.session_types, session_id, :simple)
        new_state = %{state | session_types: new_session_types}
        {{:ok, session}, new_state}

      error ->
        {error, state}
    end
  end

  defp handle_session_creation(:multiplexed, name, config, state) do
    case MultiplexingManager.create_session(name, config) do
      {:ok, session} ->
        session_id = session.id

        new_session_types =
          Map.put(state.session_types, session_id, :multiplexed)

        new_state = %{state | session_types: new_session_types}
        {{:ok, session}, new_state}

      error ->
        {error, state}
    end
  end

  defp handle_session_creation(:genserver, id, config, state) do
    session_opts = [
      id: id,
      width: Map.get(config, :width, 80),
      height: Map.get(config, :height, 24),
      title: Map.get(config, :title, "Terminal"),
      theme: Map.get(config, :theme, %{}),
      auto_save: Map.get(config, :auto_save, true)
    ]

    case GenServerSession.start_link(session_opts) do
      {:ok, pid} ->
        session = GenServerSession.get_state(pid)
        session_id = session.id
        new_session_types = Map.put(state.session_types, session_id, :genserver)
        new_state = %{state | session_types: new_session_types}
        {{:ok, session}, new_state}

      error ->
        {error, state}
    end
  end

  defp get_session_type(session_id) do
    GenServer.call(__MODULE__, {:get_session_type, session_id})
  end

  defp get_session_type_from_state(state, session_id) do
    case Map.get(state.session_types, session_id) do
      nil -> {:error, :session_not_found}
      type -> {:ok, type}
    end
  end

  defp get_simple_sessions do
    # Simple sessions are stateless, we can't really list them
    # This would require the SimpleManager to track created sessions
    []
  end

  defp get_genserver_sessions do
    case UnifiedRegistry.list(:sessions) do
      session_ids when is_list(session_ids) ->
        Enum.map(session_ids, fn id -> %{id: id, type: :genserver} end)

      _ ->
        []
    end
  end
end
