defmodule Raxol.Web.Session.Cleanup do
  @moduledoc """
  Handles session cleanup for Raxol applications.
  
  This module provides functionality to clean up expired and inactive sessions,
  ensuring efficient resource usage and data hygiene.
  """

  alias Raxol.Web.Session.{Storage, Session}
  alias Raxol.Repo

  @doc """
  Initialize the session cleanup system.
  """
  def init do
    # Clean up any expired sessions
    cleanup_expired_sessions()
    :ok
  end

  @doc """
  Clean up expired sessions.
  """
  def cleanup_expired_sessions do
    # Get current time
    now = DateTime.utc_now()
    
    # Get all sessions from database
    expired_sessions = Repo.all(
      from s in Session,
      where: s.status == :active and
             fragment("? < ?", s.last_active, datetime_add(^now, -3600, "second"))
    )
    
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
  end

  @doc """
  Clean up old sessions.
  """
  def cleanup_old_sessions(days \\ 30) do
    # Get cutoff date
    cutoff = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)
    
    # Delete old sessions from database
    Repo.delete_all(
      from s in Session,
      where: s.status in [:ended, :expired] and
             s.ended_at < ^cutoff
    )
  end

  @doc """
  Clean up orphaned sessions.
  """
  def cleanup_orphaned_sessions do
    # Get all sessions from database
    sessions = Repo.all(Session)
    
    # Check each session for orphaned status
    for session <- sessions do
      if is_orphaned?(session) do
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
  end

  # Private functions

  defp is_orphaned?(session) do
    # Check if session is active but has no associated user
    session.status == :active &&
    (is_nil(session.user_id) || session.user_id == "")
  end
end 