defmodule Raxol.Auth.Session do
  @moduledoc """
  Session management for authentication.

  This module provides session creation, validation, and cleanup
  functionality for the Auth module. It acts as a bridge between
  the Auth module and the Web.Session.SessionManager.
  """

  alias Raxol.Web.Session.SessionManager, as: Manager
  require Raxol.Core.Runtime.Log

  @doc """
  Creates a new session for a user.

  ## Parameters

  - `user_id` - The ID of the user
  - `metadata` - Optional metadata to store with the session

  ## Returns

  - `{:ok, session_data}` - Session created successfully
  - `{:error, reason}` - Session creation failed

  ## Session Data Structure

  The returned session_data contains:
  - `session_id` - Unique session identifier
  - `user_id` - User ID associated with the session
  - `token` - Secure token for session validation
  - `created_at` - Session creation timestamp
  """
  @spec create_session(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def create_session(user_id, metadata \\ %{}) do
    Raxol.Core.Runtime.Log.debug("Creating session for user ID: #{user_id}")

    case Manager.create_session(user_id, metadata) do
      {:ok, session} ->
        # Generate a secure token for this session
        token = generate_secure_token()

        # Update session with token
        case Manager.update_session(session.id, %{token: token}) do
          {:ok, updated_session} ->
            session_data = %{
              session_id: updated_session.id,
              user_id: updated_session.user_id,
              token: token,
              created_at: updated_session.created_at
            }

            Raxol.Core.Runtime.Log.debug(
              "Session created successfully: #{session_data.session_id}"
            )

            {:ok, session_data}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error(
              "Failed to update session with token: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "Failed to create session: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Validates a session using session ID and token.

  ## Parameters

  - `session_id` - The session identifier
  - `token` - The session token

  ## Returns

  - `{:ok, user_id}` - Session is valid
  - `{:error, :invalid_token}` - Token is invalid
  - `{:error, :not_found}` - Session not found
  - `{:error, reason}` - Other validation error
  """
  @spec validate_session(String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def validate_session(session_id, token)
      when is_binary(session_id) and is_binary(token) do
    case Manager.get_session(session_id) do
      {:ok, session} ->
        case {session.token == token, session.status == :active} do
          {true, true} ->
            {:ok, session.user_id}

          _ ->
            Raxol.Core.Runtime.Log.warning(
              "Invalid session token or inactive session: #{session_id}"
            )

            {:error, :invalid_token}
        end

      {:error, :not_found} ->
        Raxol.Core.Runtime.Log.warning("Session not found: #{session_id}")
        {:error, :not_found}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "Session validation error: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Validates a session using session ID and token.
  Returns nil for invalid sessions (for backward compatibility).
  """
  @spec validate_session_nil(String.t(), String.t()) :: String.t() | nil
  def validate_session_nil(session_id, token)
      when is_binary(session_id) and is_binary(token) do
    case validate_session(session_id, token) do
      {:ok, user_id} -> user_id
      _ -> nil
    end
  end

  @doc """
  Cleans up a session by marking it as ended.

  ## Parameters

  - `session_id` - The session identifier to clean up

  ## Returns

  - `:ok` - Session cleaned up successfully
  - `{:error, reason}` - Cleanup failed
  """
  @spec cleanup_session(String.t()) :: :ok | {:error, term()}
  def cleanup_session(session_id) when is_binary(session_id) do
    Raxol.Core.Runtime.Log.debug("Cleaning up session: #{session_id}")

    case Manager.end_session(session_id) do
      :ok ->
        Raxol.Core.Runtime.Log.debug(
          "Session cleaned up successfully: #{session_id}"
        )

        :ok

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "Failed to cleanup session: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @spec cleanup_session(any()) :: :ok
  def cleanup_session(_), do: :ok

  @doc """
  Gets a session by ID.

  ## Parameters

  - `session_id` - The session identifier

  ## Returns

  - `{:ok, session}` - Session found
  - `{:error, :not_found}` - Session not found
  """
  @spec get_session(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_session(session_id) when is_binary(session_id) do
    Manager.get_session(session_id)
  end

  @spec get_session(String.t()) :: map() | nil
  def get_session(session_id) when is_binary(session_id) do
    case Manager.get_session(session_id) do
      {:ok, session} -> session
      {:error, _} -> nil
    end
  end

  # Private functions

  @doc false
  defp generate_secure_token do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64()
  end
end
