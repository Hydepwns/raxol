defmodule Raxol.Web.Session.Cleanup do
  @moduledoc """
  Handles session cleanup for Raxol applications.

  This module provides functionality to clean up expired and inactive sessions,
  ensuring efficient resource usage and data hygiene.
  """

  import Ecto.Query
  alias Raxol.Web.Session.{Storage, Session}
  alias Raxol.Repo

  @doc """
  Initialize the session cleanup system.
  """
  def init do
    # Skip database operations in test environment
    handle_init_cleanup(is_test_env())
  end

  @doc """
  Clean up expired sessions.
  """
  def cleanup_expired_sessions do
    # Skip database operations in test environment
    handle_expired_cleanup(is_test_env())
  end

  @doc """
  Clean up old sessions.
  """
  def cleanup_old_sessions(days \\ 30) do
    # Skip database operations in test environment
    handle_old_sessions_cleanup(is_test_env(), days)
  end

  @doc """
  Clean up orphaned sessions.
  """
  def cleanup_orphaned_sessions do
    # Skip database operations in test environment
    handle_orphaned_cleanup(is_test_env())
  end

  # Private functions

  defp orphaned?(session) do
    # Check if session is active but has no associated user
    session.status == :active &&
      (is_nil(session.user_id) || session.user_id == "")
  end

  # Helper functions for if statement elimination

  defp is_test_env do
    function_exported?(Mix, :env, 0) and Mix.env() == :test
  end

  defp handle_init_cleanup(true), do: :ok

  defp handle_init_cleanup(false) do
    # Clean up any expired sessions
    _ = cleanup_expired_sessions()
    :ok
  end

  defp handle_expired_cleanup(true), do: :ok

  defp handle_expired_cleanup(false) do
    # Get current time
    now = DateTime.utc_now()

    # Get all sessions from database
    query =
      from(s in Session,
        where:
          s.status == :active and
            s.last_active < datetime_add(^now, -3600, "second")
      )

    expired_sessions = Repo.all(query)

    # Mark sessions as expired
    for session <- expired_sessions do
      session
      |> Session.changeset(%{
        status: :expired,
        ended_at: now
      })
      |> Repo.update()

      # Remove from ETS
      Storage.delete(session.id)
    end

    :ok
  end

  defp handle_old_sessions_cleanup(true, _days), do: :ok

  defp handle_old_sessions_cleanup(false, days) do
    # Get cutoff date
    cutoff = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    # Delete old sessions from database
    query =
      from(s in Session,
        where:
          s.status in [:ended, :expired] and
            s.ended_at < ^cutoff
      )

    Repo.delete_all(query)
    :ok
  end

  defp handle_orphaned_cleanup(true), do: :ok

  defp handle_orphaned_cleanup(false) do
    # Get all sessions from database
    sessions = Repo.all(Session)

    # Check each session for orphaned status
    for session <- sessions do
      process_orphaned_session(orphaned?(session), session)
    end

    :ok
  end

  defp process_orphaned_session(false, _session), do: :ok

  defp process_orphaned_session(true, session) do
    # Mark as expired
    session
    |> Session.changeset(%{
      status: :expired,
      ended_at: DateTime.utc_now()
    })
    |> Repo.update()

    # Remove from ETS
    Storage.delete(session.id)
  end
end
