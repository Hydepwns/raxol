defmodule Raxol.Web.Session.Storage do
  @moduledoc """
  Handles session storage and retrieval for Raxol applications.

  This module provides persistent storage for session data using ETS tables
  and optional database storage for long-term persistence.
  """

  alias Raxol.Repo
  alias Raxol.Web.Session.Session

  # ETS table name for session storage
  @table_name :session_storage

  @doc """
  Initialize the session storage system.
  """
  def init do
    # Create ETS table for session storage if it doesn't exist
    case :ets.whereis(@table_name) do
      :undefined ->
        _ = :ets.new(@table_name, [:named_table, :set, :public])
        :ok

      _tid ->
        # Table already exists
        :ok
    end
  end

  @doc """
  Store a session in the storage system.
  """
  def store(session) do
    # Store in ETS for fast access
    :ets.insert(@table_name, {session.id, session})

    # Skip database operations in test environment
    handle_database_store(is_test_env(), session)
  end

  @doc """
  Retrieve a session from storage.
  """
  def get(session_id) do
    # Try ETS first
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, session}] ->
        {:ok, session}

      [] ->
        handle_database_get(is_test_env(), session_id)
    end
  end

  @doc """
  Get all expired sessions.
  """
  def get_expired_sessions(timeout) do
    # Get current time
    now = DateTime.utc_now()

    # Get all sessions from ETS
    sessions = :ets.tab2list(@table_name)

    # Filter expired sessions
    Enum.filter(sessions, fn {_id, session} ->
      # Check if session is active and last active time is older than timeout
      session.status == :active &&
        DateTime.diff(now, session.last_active) > div(timeout, 1000)
    end)
    |> Enum.map(fn {_id, session} -> session end)
  end

  @doc """
  Delete a session from storage.
  """
  def delete(session_id) do
    # Delete from ETS
    :ets.delete(@table_name, session_id)

    # Skip database operations in test environment
    handle_database_delete(is_test_env(), session_id)

    :ok
  end

  @doc """
  Get all active sessions.
  """
  def get_active_sessions do
    :ets.tab2list(@table_name)
    |> Enum.filter(fn {_id, session} -> session.status == :active end)
    |> Enum.map(fn {_id, session} -> session end)
  end

  # Helper functions to eliminate if/unless statements

  defp is_test_env do
    function_exported?(Mix, :env, 0) and Mix.env() == :test
  end

  defp handle_database_store(true, session), do: {:ok, session}

  defp handle_database_store(false, session) do
    # Store in database for persistence
    case Repo.get(Session, session.id) do
      nil ->
        # Create new session
        %Session{}
        |> Session.changeset(Map.from_struct(session))
        |> Repo.insert()

      existing ->
        # Update existing session
        existing
        |> Session.changeset(Map.from_struct(session))
        |> Repo.update()
    end
  end

  defp handle_database_get(true, _session_id), do: {:error, :not_found}

  defp handle_database_get(false, session_id) do
    # Try database
    case Repo.get(Session, session_id) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  defp handle_database_delete(true, _session_id), do: :ok

  defp handle_database_delete(false, session_id) do
    # Delete from database
    case Repo.get(Session, session_id) do
      nil -> :ok
      session -> Repo.delete(session)
    end
  end
end
