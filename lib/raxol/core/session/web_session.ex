defmodule Raxol.Core.Session.WebSession do
  @moduledoc """
  Web session implementation for the unified session manager.

  Provides HTTP session management with:
  - Session storage and retrieval
  - Session recovery and cleanup
  - Session metadata management
  - Session limits and monitoring
  """

  require Logger

  defstruct [
    :id,
    :user_id,
    :created_at,
    :last_active,
    :metadata,
    :status
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          created_at: DateTime.t(),
          last_active: DateTime.t(),
          metadata: map(),
          status: :active | :ended | :expired
        }

  ## Public API

  @doc """
  Creates a new web session.
  """
  def create(user_id, metadata, _config) do
    session = %__MODULE__{
      id: generate_session_id(),
      user_id: user_id,
      created_at: DateTime.utc_now(),
      last_active: DateTime.utc_now(),
      metadata: metadata || %{},
      status: :active
    }

    # In production, would store to database/storage
    case Application.get_env(:raxol, :env) do
      :test ->
        {:ok, session}

      _ ->
        # Would use actual storage here
        {:ok, session}
    end
  end

  @doc """
  Updates the last activity timestamp.
  """
  def touch(session) do
    %{session | last_active: DateTime.utc_now()}
  end

  @doc """
  Updates session metadata.
  """
  def update_metadata(session, new_metadata) do
    updated_metadata = Map.merge(session.metadata || %{}, new_metadata)

    %{session | metadata: updated_metadata, last_active: DateTime.utc_now()}
  end

  @doc """
  Cleans up expired web sessions.
  """
  def cleanup_expired(sessions, config) do
    now = DateTime.utc_now()
    timeout = config.web_session_timeout

    Enum.filter(sessions, fn {_id, session} ->
      case session.status do
        :active ->
          # Check if session has expired
          expired_time =
            DateTime.add(session.last_active, timeout, :millisecond)

          DateTime.compare(now, expired_time) == :lt

        _ ->
          # Keep non-active sessions for audit purposes temporarily
          created_cutoff =
            DateTime.add(session.created_at, timeout * 2, :millisecond)

          DateTime.compare(now, created_cutoff) == :lt
      end
    end)
    |> Map.new()
  end

  @doc """
  Gets all sessions for a user.
  """
  def get_user_sessions(user_id, sessions) do
    sessions
    |> Enum.filter(fn {_id, session} -> session.user_id == user_id end)
    |> Enum.map(fn {_id, session} -> sanitize_session(session) end)
  end

  ## Private Functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  @spec sanitize_session(any()) :: any()
  defp sanitize_session(session) do
    %{
      id: session.id,
      created_at: session.created_at,
      last_active: session.last_active,
      status: session.status,
      metadata_keys:
        if(session.metadata, do: Map.keys(session.metadata), else: [])
    }
  end
end
