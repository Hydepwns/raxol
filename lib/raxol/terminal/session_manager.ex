defmodule Raxol.Terminal.SessionManager do
  @moduledoc """
  Session management module for handling terminal sessions.

  This module provides functionality for:
  - Session creation and management
  - Session authentication
  - Session state tracking
  - Session cleanup
  """

  use GenServer
  alias Raxol.Terminal.Emulator

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def create_session(user_id) do
    GenServer.call(__MODULE__, {:create_session, user_id})
  end

  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  def authenticate_session(session_id, token) do
    GenServer.call(__MODULE__, {:authenticate, session_id, token})
  end

  def cleanup_session(session_id) do
    GenServer.call(__MODULE__, {:cleanup, session_id})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create_session, user_id}, _from, sessions) do
    session_id = generate_session_id()
    token = generate_token()

    scrollback_limit =
      Application.get_env(:raxol, :terminal, [])
      |> Keyword.get(:scrollback_lines, 1000)

    session = %{
      id: session_id,
      user_id: user_id,
      token: token,
      emulator: Emulator.new(80, 24, scrollback: scrollback_limit),
      created_at: DateTime.utc_now(),
      last_active: DateTime.utc_now()
    }

    sessions = Map.put(sessions, session_id, session)
    {:reply, {:ok, session}, sessions}
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, sessions) do
    case Map.get(sessions, session_id) do
      nil -> {:reply, {:error, :not_found}, sessions}
      session -> {:reply, {:ok, session}, sessions}
    end
  end

  @impl true
  def handle_call({:authenticate, session_id, token}, _from, sessions) do
    case Map.get(sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, sessions}

      session ->
        if session.token == token do
          session = Map.put(session, :last_active, DateTime.utc_now())
          sessions = Map.put(sessions, session_id, session)
          {:reply, {:ok, session}, sessions}
        else
          {:reply, {:error, :invalid_token}, sessions}
        end
    end
  end

  @impl true
  def handle_call({:cleanup, session_id}, _from, sessions) do
    sessions = Map.delete(sessions, session_id)
    {:reply, :ok, sessions}
  end

  @impl true
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
