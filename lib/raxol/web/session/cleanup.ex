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
    if function_exported?(Mix, :env, 0) and Mix.env() == :test do
      :ok
    else
      # Clean up any expired sessions
      _ = cleanup_expired_sessions()
      :ok
    end
  end

  @doc """
  Clean up expired sessions.
  """
  def cleanup_expired_sessions do
    # Skip database operations in test environment
    if function_exported?(Mix, :env, 0) and Mix.env() == :test do
      :ok
    else
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
  end

  @doc """
  Clean up old sessions.
  """
  def cleanup_old_sessions(days \\ 30) do
    # Skip database operations in test environment
    if function_exported?(Mix, :env, 0) and Mix.env() == :test do
      :ok
    else
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
  end

  @doc """
  Clean up orphaned sessions.
  """
  def cleanup_orphaned_sessions do
    # Skip database operations in test environment
    if function_exported?(Mix, :env, 0) and Mix.env() == :test do
      :ok
    else
      # Get all sessions from database
      sessions = Repo.all(Session)

      # Check each session for orphaned status
      for session <- sessions do
        if orphaned?(session) do
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

      :ok
    end
  end

  # Private functions

  defp orphaned?(session) do
    # Check if session is active but has no associated user
    session.status == :active &&
      (is_nil(session.user_id) || session.user_id == "")
  end
end
