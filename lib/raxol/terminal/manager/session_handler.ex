defmodule Raxol.Terminal.Manager.SessionHandler do
  @moduledoc '''
  Handles terminal session management.

  This module is responsible for:
  - Creating new sessions
  - Destroying sessions
  - Managing session state
  - Handling session monitoring
  '''

  require Raxol.Core.Runtime.Log
  alias Raxol.Terminal.SessionManager

  @doc '''
  Creates a new terminal session.
  '''
  @spec create_session(map(), map()) :: {:ok, binary()} | {:error, term()}
  def create_session(opts, state) do
    case SessionManager.create_session(opts, state.runtime_pid) do
      {:ok, session_id, pid} ->
        new_state = %{
          state
          | sessions: Map.put(state.sessions, session_id, pid)
        }

        {:ok, session_id, new_state}

      error ->
        error
    end
  end

  @doc '''
  Destroys a terminal session.
  '''
  @spec destroy_session(binary(), map()) :: :ok | {:error, term()}
  def destroy_session(session_id, state) do
    case SessionManager.destroy_session(
           session_id,
           state.sessions,
           state.runtime_pid
         ) do
      :ok ->
        new_state = %{state | sessions: Map.delete(state.sessions, session_id)}
        {:ok, new_state}

      error ->
        error
    end
  end

  @doc '''
  Gets a terminal session by ID.
  '''
  @spec get_session(binary(), map()) :: {:ok, map()} | {:error, term()}
  def get_session(session_id, state) do
    SessionManager.get_session(session_id, state.sessions, state.runtime_pid)
  end

  @doc '''
  Lists all terminal sessions.
  '''
  @spec list_sessions(map()) :: [map()]
  def list_sessions(state) do
    SessionManager.list_sessions(state.sessions)
  end

  @doc '''
  Gets the count of terminal sessions.
  '''
  @spec count_sessions(map()) :: non_neg_integer()
  def count_sessions(state) do
    SessionManager.count_sessions(state.sessions)
  end

  @doc '''
  Monitors a terminal session.
  '''
  @spec monitor_session(binary(), map()) :: :ok | {:error, term()}
  def monitor_session(session_id, state) do
    SessionManager.monitor_session(session_id, state.sessions)
  end

  @doc '''
  Unmonitors a terminal session.
  '''
  @spec unmonitor_session(binary(), map()) :: :ok | {:error, term()}
  def unmonitor_session(session_id, state) do
    SessionManager.unmonitor_session(session_id, state.sessions)
  end

  @doc '''
  Handles a session process down event.
  '''
  @spec handle_session_down(pid(), map()) :: map()
  def handle_session_down(pid, state) do
    %{
      state
      | sessions: SessionManager.handle_session_down(pid, state.sessions)
    }
  end
end
