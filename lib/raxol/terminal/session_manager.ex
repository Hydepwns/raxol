defmodule Raxol.Terminal.SessionManager do
  @moduledoc """
  Manages terminal sessions, including:
  - Session creation
  - Session destruction
  - Session listing
  - Session monitoring
  - Session state management
  """

  require Raxol.Core.Runtime.Log
  require Logger

  alias Raxol.Terminal.Session

  @doc """
  Creates a new terminal session with the given options.
  Returns {:ok, session_id} or an error tuple.
  """
  @spec create_session(map(), pid() | nil) :: {:ok, String.t()} | {:error, any()}
  def create_session(opts, runtime_pid \\ nil) do
    case Session.start_link(opts) do
      {:ok, pid} ->
        session_id = UUID.uuid4()

        if runtime_pid,
          do:
            send(
              runtime_pid,
              {:terminal_session_created, session_id, pid}
            )

        {:ok, session_id}

      error ->
        if runtime_pid,
          do:
            send(
              runtime_pid,
              {:terminal_error, error, %{action: :create_session, opts: opts}}
            )

        error
    end
  end

  @doc """
  Destroys a terminal session by ID.
  Returns :ok or {:error, :not_found}.
  """
  @spec destroy_session(String.t(), map(), pid() | nil) :: :ok | {:error, :not_found}
  def destroy_session(session_id, sessions, runtime_pid \\ nil) do
    case Map.get(sessions, session_id) do
      nil ->
        if runtime_pid,
          do:
            send(
              runtime_pid,
              {:terminal_error, :not_found,
               %{action: :destroy_session, session_id: session_id}}
            )

        {:error, :not_found}

      pid ->
        Session.stop(pid)
        if runtime_pid, do: send(runtime_pid, {:terminal_session_destroyed, session_id})
        :ok
    end
  end

  @doc """
  Gets a terminal session by ID.
  Returns {:ok, session_state} or {:error, :not_found}.
  """
  @spec get_session(String.t(), map(), pid() | nil) ::
          {:ok, map()} | {:error, :not_found}
  def get_session(session_id, sessions, runtime_pid \\ nil) do
    case Map.get(sessions, session_id) do
      nil ->
        if runtime_pid,
          do:
            send(
              runtime_pid,
              {:terminal_error, :not_found,
               %{action: :get_session, session_id: session_id}}
            )

        {:error, :not_found}

      pid ->
        session_state = Session.get_state(pid)
        {:ok, session_state}
    end
  end

  @doc """
  Lists all terminal sessions.
  Returns a map of session IDs to session states.
  """
  @spec list_sessions(map()) :: map()
  def list_sessions(sessions) do
    sessions
    |> Enum.map(fn {id, pid} ->
      {id, Session.get_state(pid)}
    end)
    |> Map.new()
  end

  @doc """
  Gets the count of terminal sessions.
  """
  @spec count_sessions(map()) :: non_neg_integer()
  def count_sessions(sessions) do
    map_size(sessions)
  end

  @doc """
  Monitors a terminal session.
  Returns :ok or {:error, :not_found}.
  """
  @spec monitor_session(String.t(), map()) :: :ok | {:error, :not_found}
  def monitor_session(session_id, sessions) do
    case Map.get(sessions, session_id) do
      nil -> {:error, :not_found}
      pid -> Process.monitor(pid) && :ok
    end
  end

  @doc """
  Unmonitors a terminal session.
  Returns :ok or {:error, :not_found}.
  """
  @spec unmonitor_session(String.t(), map()) :: :ok | {:error, :not_found}
  def unmonitor_session(session_id, sessions) do
    case Map.get(sessions, session_id) do
      nil -> {:error, :not_found}
      pid -> Process.demonitor(pid) && :ok
    end
  end

  @doc """
  Handles a session process DOWN message.
  Returns the updated sessions map with the terminated session removed.
  """
  @spec handle_session_down(pid(), map()) :: map()
  def handle_session_down(pid, sessions) do
    sessions
    |> Enum.reject(fn {_id, p} -> p == pid end)
    |> Map.new()
  end
end
