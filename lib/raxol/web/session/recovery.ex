defmodule Raxol.Web.Session.Recovery do
  @moduledoc '''
  Handles session recovery for Raxol applications.

  This module provides functionality to recover sessions after crashes or
  unexpected terminations, ensuring session continuity and data integrity.
  '''

  alias Raxol.Web.Session.Storage
  # alias Raxol.Web.Session.{Storage, Session} # Session unused

  @doc '''
  Initialize the session recovery system.
  '''
  def init do
    # Recover any active sessions from the database
    _ = recover_active_sessions()
    :ok
  end

  @doc '''
  Recover a specific session.
  '''
  def recover_session(session_id) do
    case Storage.get(session_id) do
      {:ok, session} ->
        # Check if session needs recovery
        if needs_recovery?(session) do
          # Recover session data
          recovered_session = recover_session_data(session)

          # Store recovered session
          :ok = Storage.store(recovered_session)

          {:ok, recovered_session}
        else
          {:ok, session}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp recover_active_sessions do
    # Get all active sessions from database
    active_sessions = Storage.get_active_sessions()

    # Recover each session
    for session <- active_sessions do
      if needs_recovery?(session) do
        recovered_session = recover_session_data(session)
        :ok = Storage.store(recovered_session)
      end
    end
  end

  defp needs_recovery?(session) do
    # Check if session is active but last active time is too old
    # 5 minutes
    session.status == :active &&
      DateTime.diff(DateTime.utc_now(), session.last_active) > 300
  end

  defp recover_session_data(session) do
    # Update session metadata with recovery information
    metadata =
      Map.merge(session.metadata, %{
        recovered_at: DateTime.utc_now(),
        recovery_count: (session.metadata[:recovery_count] || 0) + 1
      })

    # Update session
    %{session | last_active: DateTime.utc_now(), metadata: metadata}
  end
end
