defmodule Raxol.Terminal.Manager.SessionHandler do
  @moduledoc """
  Handles terminal session management.

  This module is responsible for:
  - Creating new sessions
  - Destroying sessions
  - Managing session state
  - Handling session monitoring
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Core.Session.SessionManager

  @doc """
  Creates a new terminal session.
  """
  @spec create_session(map(), map()) :: {:ok, binary()} | {:error, term()}
  def create_session(opts, state) do
    user_id = Map.get(opts, :user_id, "anonymous")

    case SessionManager.create_terminal_session(user_id) do
      {:ok, session_id} ->
        # Create a session structure compatible with the handler
        session = %{
          id: session_id,
          user_id: user_id,
          runtime_pid: state.runtime_pid,
          opts: opts,
          created_at: DateTime.utc_now()
        }

        new_state = %{
          state
          | sessions: Map.put(state.sessions, session_id, session)
        }

        {:ok, session_id, new_state}

      error ->
        error
    end
  end

  @doc """
  Destroys a terminal session.
  """
  @spec destroy_session(binary(), map()) :: :ok | {:error, term()}
  def destroy_session(session_id, state) do
    case SessionManager.cleanup_terminal_session(session_id) do
      :ok ->
        new_state = %{state | sessions: Map.delete(state.sessions, session_id)}
        {:ok, new_state}

      error ->
        error
    end
  end

  @doc """
  Gets a terminal session by ID.
  """
  @spec get_session(binary(), map()) :: {:ok, map()} | {:error, term()}
  def get_session(session_id, state) do
    case SessionManager.get_terminal_session(session_id) do
      {:ok, core_session} ->
        # Return the local session if it exists, otherwise use core session
        case Map.get(state.sessions, session_id) do
          nil -> {:ok, core_session}
          local_session -> {:ok, local_session}
        end

      error ->
        error
    end
  end

  @doc """
  Lists all terminal sessions.
  """
  @spec list_sessions(map()) :: [map()]
  def list_sessions(state) do
    Map.values(state.sessions)
  end

  @doc """
  Gets the count of terminal sessions.
  """
  @spec count_sessions(map()) :: non_neg_integer()
  def count_sessions(state) do
    map_size(state.sessions)
  end

  @doc """
  Monitors a terminal session.
  """
  @spec monitor_session(binary(), map()) :: :ok | {:error, term()}
  def monitor_session(_session_id, _state) do
    # Session monitoring is handled internally by the core session manager
    :ok
  end

  @doc """
  Unmonitors a terminal session.
  """
  @spec unmonitor_session(binary(), map()) :: :ok | {:error, term()}
  def unmonitor_session(_session_id, _state) do
    # Session monitoring is handled internally by the core session manager
    :ok
  end

  @doc """
  Handles a session process down event.
  """
  @spec handle_session_down(pid(), map()) :: map()
  def handle_session_down(_pid, state) do
    # Session cleanup is handled internally by the core session manager
    state
  end
end
