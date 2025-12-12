defmodule Raxol.Web.SessionBridge do
  @moduledoc """
  Manages seamless transitions between terminal and web interfaces.

  Implements WASH-style (Web Authoring System Haskell) web continuity,
  enabling state preservation during interface transitions.

  ## Features

  - Terminal to web transitions with full state preservation
  - Web to terminal transitions with state restoration
  - Secure bridge tokens for cross-interface authentication
  - State serialization/deserialization for terminal emulator state

  ## Example

      # From terminal, create transition to web
      {:ok, token} = SessionBridge.create_transition(session_id, terminal_state)

      # In web, resume the session
      {:ok, state} = SessionBridge.resume_session(token)

      # Later, return to terminal
      {:ok, terminal_token} = SessionBridge.create_terminal_transition(session_id)
  """

  use GenServer

  alias Raxol.Core.Runtime.Log

  @token_ttl_seconds 300
  @cleanup_interval_ms 60_000

  defmodule State do
    @moduledoc false
    defstruct transitions: %{},
              sessions: %{}
  end

  defmodule Transition do
    @moduledoc false
    defstruct [
      :token,
      :session_id,
      :state_snapshot,
      :created_at,
      :expires_at,
      :direction
    ]
  end

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the SessionBridge server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Create a transition from terminal to web.

  Captures the current terminal state and generates a secure token
  that can be used to resume the session in a web interface.

  ## Parameters

    - `session_id` - The session identifier
    - `state` - The terminal state to preserve

  ## Returns

    - `{:ok, bridge_token}` - Token to use for web resume
    - `{:error, reason}` - If transition creation fails

  ## Example

      {:ok, token} = SessionBridge.create_transition("session123", emulator_state)
  """
  @spec create_transition(String.t(), map()) ::
          {:ok, String.t()} | {:error, term()}
  def create_transition(session_id, state) when is_binary(session_id) do
    GenServer.call(
      __MODULE__,
      {:create_transition, session_id, state, :terminal_to_web}
    )
  end

  @doc """
  Resume a session using a bridge token.

  Retrieves the preserved state associated with the token and marks
  the transition as consumed.

  ## Parameters

    - `token` - The bridge token from create_transition

  ## Returns

    - `{:ok, session_state}` - The preserved session state
    - `{:error, :invalid_token}` - Token not found or expired
    - `{:error, :token_consumed}` - Token already used

  ## Example

      {:ok, state} = SessionBridge.resume_session(token)
  """
  @spec resume_session(String.t()) :: {:ok, map()} | {:error, term()}
  def resume_session(token) when is_binary(token) do
    GenServer.call(__MODULE__, {:resume_session, token})
  end

  @doc """
  Capture the current state of a session.

  Creates a snapshot of the session state without creating a transition.
  Useful for periodic state persistence.

  ## Example

      snapshot = SessionBridge.capture_state("session123")
  """
  @spec capture_state(String.t()) :: map() | nil
  def capture_state(session_id) when is_binary(session_id) do
    GenServer.call(__MODULE__, {:capture_state, session_id})
  end

  @doc """
  Restore a session from a previously captured snapshot.

  ## Example

      :ok = SessionBridge.restore_state("session123", snapshot)
  """
  @spec restore_state(String.t(), map()) :: :ok | {:error, term()}
  def restore_state(session_id, snapshot)
      when is_binary(session_id) and is_map(snapshot) do
    GenServer.call(__MODULE__, {:restore_state, session_id, snapshot})
  end

  @doc """
  Serialize terminal emulator state to binary.

  Converts the emulator state to a compact binary format suitable
  for storage or transmission.

  ## Example

      binary = SessionBridge.serialize_terminal_state(emulator)
  """
  @spec serialize_terminal_state(map()) :: binary()
  def serialize_terminal_state(emulator) when is_map(emulator) do
    :erlang.term_to_binary(emulator, [:compressed])
  end

  @doc """
  Deserialize terminal emulator state from binary.

  Restores an emulator state from its binary representation.

  ## Example

      {:ok, emulator} = SessionBridge.deserialize_terminal_state(binary)
  """
  @spec deserialize_terminal_state(binary()) :: {:ok, map()} | {:error, term()}
  def deserialize_terminal_state(binary) when is_binary(binary) do
    try do
      {:ok, :erlang.binary_to_term(binary, [:safe])}
    rescue
      ArgumentError -> {:error, :invalid_binary}
    end
  end

  @doc """
  Check if a transition token is valid.

  ## Example

      true = SessionBridge.valid_token?(token)
  """
  @spec valid_token?(String.t()) :: boolean()
  def valid_token?(token) when is_binary(token) do
    GenServer.call(__MODULE__, {:valid_token?, token})
  end

  @doc """
  Get information about an active session.

  ## Example

      {:ok, info} = SessionBridge.session_info("session123")
  """
  @spec session_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  def session_info(session_id) when is_binary(session_id) do
    GenServer.call(__MODULE__, {:session_info, session_id})
  end

  @doc """
  Register a session with the bridge.

  ## Example

      :ok = SessionBridge.register_session("session123", initial_state)
  """
  @spec register_session(String.t(), map()) :: :ok
  def register_session(session_id, initial_state \\ %{})
      when is_binary(session_id) do
    GenServer.call(__MODULE__, {:register_session, session_id, initial_state})
  end

  @doc """
  Unregister a session from the bridge.

  ## Example

      :ok = SessionBridge.unregister_session("session123")
  """
  @spec unregister_session(String.t()) :: :ok
  def unregister_session(session_id) when is_binary(session_id) do
    GenServer.call(__MODULE__, {:unregister_session, session_id})
  end

  @doc """
  List all active session IDs.

  Returns a list of session identifiers that are currently registered
  with the bridge.

  ## Example

      sessions = SessionBridge.list_sessions()
      # => ["session1", "session2", ...]
  """
  @spec list_sessions() :: [String.t()]
  def list_sessions do
    GenServer.call(__MODULE__, :list_sessions)
  end

  @doc """
  Delete a session and its associated state.

  Removes the session from the bridge and cleans up any associated
  transition tokens.

  ## Parameters

    - `session_id` - The session identifier to delete

  ## Example

      :ok = SessionBridge.delete_session("session123")
  """
  @spec delete_session(String.t()) :: :ok
  def delete_session(session_id) when is_binary(session_id) do
    GenServer.call(__MODULE__, {:delete_session, session_id})
  end

  @doc """
  Clean up expired transition tokens.

  Removes all transition tokens that have exceeded their TTL.
  Returns the count of cleaned up tokens.

  ## Example

      {:ok, count} = SessionBridge.cleanup_expired()
  """
  @spec cleanup_expired() :: {:ok, non_neg_integer()}
  def cleanup_expired do
    GenServer.call(__MODULE__, :cleanup_expired)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    schedule_cleanup()
    {:ok, %State{}}
  end

  @impl true
  def handle_call(
        {:create_transition, session_id, state, direction},
        _from,
        server_state
      ) do
    token = generate_token()
    now = System.system_time(:second)

    transition = %Transition{
      token: token,
      session_id: session_id,
      state_snapshot: state,
      created_at: now,
      expires_at: now + @token_ttl_seconds,
      direction: direction
    }

    new_transitions = Map.put(server_state.transitions, token, transition)
    new_state = %{server_state | transitions: new_transitions}

    Log.debug("[SessionBridge] Created transition for session #{session_id}")
    {:reply, {:ok, token}, new_state}
  end

  @impl true
  def handle_call({:resume_session, token}, _from, server_state) do
    case Map.get(server_state.transitions, token) do
      nil ->
        {:reply, {:error, :invalid_token}, server_state}

      %Transition{
        expires_at: expires_at,
        state_snapshot: snapshot,
        session_id: session_id
      } ->
        current_time = System.system_time(:second)

        if expires_at < current_time do
          new_transitions = Map.delete(server_state.transitions, token)

          {:reply, {:error, :token_expired},
           %{server_state | transitions: new_transitions}}
        else
          new_transitions = Map.delete(server_state.transitions, token)
          new_sessions = Map.put(server_state.sessions, session_id, snapshot)

          new_state = %{
            server_state
            | transitions: new_transitions,
              sessions: new_sessions
          }

          Log.debug("[SessionBridge] Resumed session #{session_id}")
          {:reply, {:ok, snapshot}, new_state}
        end
    end
  end

  @impl true
  def handle_call({:capture_state, session_id}, _from, server_state) do
    snapshot = Map.get(server_state.sessions, session_id)
    {:reply, snapshot, server_state}
  end

  @impl true
  def handle_call({:restore_state, session_id, snapshot}, _from, server_state) do
    new_sessions = Map.put(server_state.sessions, session_id, snapshot)
    {:reply, :ok, %{server_state | sessions: new_sessions}}
  end

  @impl true
  def handle_call({:valid_token?, token}, _from, server_state) do
    valid =
      case Map.get(server_state.transitions, token) do
        nil ->
          false

        %Transition{expires_at: expires_at} ->
          expires_at >= System.system_time(:second)
      end

    {:reply, valid, server_state}
  end

  @impl true
  def handle_call({:session_info, session_id}, _from, server_state) do
    case Map.get(server_state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, server_state}

      state ->
        info = %{
          session_id: session_id,
          state: state,
          has_pending_transitions:
            has_pending_transitions?(server_state.transitions, session_id)
        }

        {:reply, {:ok, info}, server_state}
    end
  end

  @impl true
  def handle_call(
        {:register_session, session_id, initial_state},
        _from,
        server_state
      ) do
    new_sessions = Map.put(server_state.sessions, session_id, initial_state)
    {:reply, :ok, %{server_state | sessions: new_sessions}}
  end

  @impl true
  def handle_call({:unregister_session, session_id}, _from, server_state) do
    new_sessions = Map.delete(server_state.sessions, session_id)
    {:reply, :ok, %{server_state | sessions: new_sessions}}
  end

  @impl true
  def handle_call(:list_sessions, _from, server_state) do
    session_ids = Map.keys(server_state.sessions)
    {:reply, session_ids, server_state}
  end

  @impl true
  def handle_call({:delete_session, session_id}, _from, server_state) do
    new_sessions = Map.delete(server_state.sessions, session_id)

    new_transitions =
      server_state.transitions
      |> Enum.reject(fn {_token, %Transition{session_id: sid}} ->
        sid == session_id
      end)
      |> Map.new()

    new_state = %{
      server_state
      | sessions: new_sessions,
        transitions: new_transitions
    }

    Log.debug("[SessionBridge] Deleted session #{session_id}")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:cleanup_expired, _from, server_state) do
    now = System.system_time(:second)

    new_transitions =
      server_state.transitions
      |> Enum.reject(fn {_token, %Transition{expires_at: expires_at}} ->
        expires_at < now
      end)
      |> Map.new()

    expired_count =
      map_size(server_state.transitions) - map_size(new_transitions)

    if expired_count > 0 do
      Log.debug(
        "[SessionBridge] Cleaned up #{expired_count} expired transitions"
      )
    end

    {:reply, {:ok, expired_count},
     %{server_state | transitions: new_transitions}}
  end

  @impl true
  def handle_info(:cleanup_expired, server_state) do
    now = System.system_time(:second)

    new_transitions =
      server_state.transitions
      |> Enum.reject(fn {_token, %Transition{expires_at: expires_at}} ->
        expires_at < now
      end)
      |> Map.new()

    expired_count =
      map_size(server_state.transitions) - map_size(new_transitions)

    if expired_count > 0 do
      Log.debug(
        "[SessionBridge] Cleaned up #{expired_count} expired transitions"
      )
    end

    schedule_cleanup()
    {:noreply, %{server_state | transitions: new_transitions}}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp generate_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired, @cleanup_interval_ms)
  end

  defp has_pending_transitions?(transitions, session_id) do
    Enum.any?(transitions, fn {_token, %Transition{session_id: sid}} ->
      sid == session_id
    end)
  end
end
