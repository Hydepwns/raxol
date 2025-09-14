defmodule Raxol.Terminal.SessionManager do
  @moduledoc """
  Session management module for handling terminal sessions.

  @deprecated "Use Raxol.Terminal.UnifiedSessionManager instead"

  This module has been consolidated into the unified session management system.
  For new code, use:

      # Instead of SessionManager.create_session(user_id)
      UnifiedSessionManager.create_simple_session(user_id, config)
      
      # Instead of SessionManager.authenticate_session(id, token)
      UnifiedSessionManager.authenticate_session(id, token)
  """

  use GenServer
  alias Raxol.Terminal.{Emulator, UnifiedSessionManager}

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Session Management Functions

  @deprecated "Use UnifiedSessionManager.create_simple_session/2 instead"
  def create_session(user_id) do
    UnifiedSessionManager.create_simple_session(user_id)
  end

  def create_session(opts, runtime_pid) do
    {:ok, %{id: :stub, opts: opts, runtime_pid: runtime_pid}}
  end

  def get_session(session_id, sessions, _runtime_pid) do
    Map.get(sessions, session_id)
  end

  def get_session(session_id) do
    %{id: session_id}
  end

  def authenticate_session(session_id, token) do
    GenServer.call(__MODULE__, {:authenticate, session_id, token})
  end

  def cleanup_session(session_id) do
    GenServer.call(__MODULE__, {:cleanup, session_id})
  end

  def destroy_session(_session_id, sessions, _runtime_pid) do
    {:ok, sessions}
  end

  def list_sessions(sessions) do
    Map.keys(sessions)
  end

  def count_sessions(sessions) do
    map_size(sessions)
  end

  def monitor_session(_session_id, _sessions) do
    :ok
  end

  def unmonitor_session(_session_id, _sessions) do
    :ok
  end

  def handle_session_down(_session_id, sessions) do
    sessions
  end

  # Server Callbacks

  def init(_) do
    {:ok, %{}}
  end

  def handle_call({:create_session, user_id}, _from, sessions) do
    session_id = generate_session_id()
    token = generate_token()

    _scrollback_limit =
      Application.get_env(:raxol, :terminal, [])
      |> Keyword.get(:scrollback_lines, 1000)

    session = %{
      id: session_id,
      user_id: user_id,
      token: token,
      emulator: Emulator.new(),
      created_at: DateTime.utc_now(),
      last_active: DateTime.utc_now()
    }

    sessions = Map.put(sessions, session_id, session)
    {:reply, {:ok, session}, sessions}
  end

  def handle_call({:get_session, session_id}, _from, sessions) do
    case Map.get(sessions, session_id) do
      nil -> {:reply, {:error, :not_found}, sessions}
      session -> {:reply, {:ok, session}, sessions}
    end
  end

  def handle_call({:authenticate, session_id, token}, _from, sessions) do
    case Map.get(sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, sessions}

      session ->
        case session.token == token do
          true ->
            session = Map.put(session, :last_active, DateTime.utc_now())
            sessions = Map.put(sessions, session_id, session)
            {:reply, {:ok, session}, sessions}

          false ->
            {:reply, {:error, :invalid_token}, sessions}
        end
    end
  end

  def handle_call({:cleanup, session_id}, _from, sessions) do
    sessions = Map.delete(sessions, session_id)
    {:reply, :ok, sessions}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Private functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64()
  end
end
