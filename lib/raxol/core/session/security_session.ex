defmodule Raxol.Core.Session.SecuritySession do
  alias Raxol.Core.Runtime.Log

  @moduledoc """
  Security session implementation for the unified session manager.

  Provides cryptographically secure session management with:
  - Secure token generation and validation
  - Session expiration and renewal
  - Concurrent session limiting
  - Session fixation protection
  - CSRF token generation
  """
  defstruct [
    :id,
    :user_id,
    :token,
    :created_at,
    :last_activity,
    :expires_at,
    :ip_address,
    :user_agent,
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          token: binary(),
          created_at: DateTime.t(),
          last_activity: DateTime.t(),
          expires_at: DateTime.t(),
          ip_address: String.t() | nil,
          user_agent: String.t() | nil,
          metadata: map()
        }

  ## Public API

  @doc """
  Creates a new security session.
  """
  def create(user_id, opts, config, sessions_state) do
    case check_session_limit(user_id, config.max_concurrent, sessions_state) do
      :ok ->
        session = create_new_session(user_id, opts, config)
        updated_state = store_session(session, sessions_state)

        session_info = %{
          session_id: session.id,
          token: session.token,
          expires_at: session.expires_at
        }

        {:ok, session_info, updated_state}

      {:error, :limit_exceeded} ->
        {:error, :session_limit_exceeded}
    end
  end

  @doc """
  Validates a session token and returns session info.
  """
  def validate(session_id, token, sessions_state) do
    case lookup_session(session_id, sessions_state) do
      nil ->
        {:error, :invalid_session}

      session ->
        validate_token_and_expiry(session, token, session_id, sessions_state)
    end
  end

  @doc """
  Invalidates a session.
  """
  def invalidate(session_id, sessions_state) do
    invalidate_session_internal(session_id, sessions_state)
  end

  @doc """
  Invalidates all sessions for a user.
  """
  def invalidate_user_sessions(user_id, sessions_state) do
    sessions = get_user_sessions_internal(user_id, sessions_state)

    updated_state =
      Enum.reduce(sessions, sessions_state, fn session, acc ->
        invalidate_session_internal(session.id, acc)
      end)

    {length(sessions), updated_state}
  end

  @doc """
  Generates a CSRF token for a session.
  """
  def generate_csrf_token(session_id) do
    secret = Application.get_env(:raxol, :secret_key_base, "default_secret")

    :crypto.mac(:hmac, :sha256, secret, session_id)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Validates a CSRF token.
  """
  def validate_csrf_token(session_id, token) do
    expected = generate_csrf_token(session_id)
    secure_token_compare(expected, token)
  end

  @doc """
  Gets statistics about security sessions.
  """
  def get_stats(_sessions_state) do
    case Raxol.Core.CompilerState.safe_lookup(:unified_security_sessions, :all) do
      {:ok, sessions} ->
        %{
          total: length(sessions),
          active: count_active_sessions(sessions)
        }

      {:error, :table_not_found} ->
        %{total: 0, active: 0}
    end
  end

  @doc """
  Counts total security sessions.
  """
  def count(_sessions_state) do
    case Raxol.Core.CompilerState.safe_lookup(:unified_security_sessions, :all) do
      {:ok, sessions} -> length(sessions)
      {:error, :table_not_found} -> 0
    end
  end

  @doc """
  Cleans up expired security sessions.
  """
  def cleanup_expired(sessions_state, _config) do
    cleanup_expired_sessions()
    sessions_state
  end

  @doc """
  Gets all sessions for a user.
  """
  def get_user_sessions(user_id, sessions_state) do
    get_user_sessions_internal(user_id, sessions_state)
    |> Enum.map(&sanitize_session_info/1)
  end

  ## Private Functions

  @spec create_new_session(String.t() | integer(), keyword(), map()) :: any()
  defp create_new_session(user_id, opts, config) do
    now = DateTime.utc_now()

    %__MODULE__{
      id: generate_session_id(),
      user_id: user_id,
      token: generate_secure_token(config.token_bytes),
      created_at: now,
      last_activity: now,
      expires_at: DateTime.add(now, config.timeout, :millisecond),
      ip_address: Keyword.get(opts, :ip_address),
      user_agent: Keyword.get(opts, :user_agent),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  defp generate_session_id do
    Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
  end

  @spec generate_secure_token(any()) :: any()
  defp generate_secure_token(token_bytes) do
    Base.url_encode64(:crypto.strong_rand_bytes(token_bytes), padding: false)
  end

  @spec store_session(any(), map()) :: any()
  defp store_session(session, sessions_state) do
    :ets.insert(:unified_security_sessions, {session.id, session})
    :ets.insert(:unified_user_security_sessions, {session.user_id, session.id})
    sessions_state
  end

  @spec lookup_session(String.t() | integer(), map()) :: any()
  defp lookup_session(session_id, _sessions_state) do
    case Raxol.Core.CompilerState.safe_lookup(
           :unified_security_sessions,
           session_id
         ) do
      {:ok, [{_, session}]} -> session
      {:ok, []} -> nil
      {:error, :table_not_found} -> nil
    end
  end

  @spec validate_token_and_expiry(any(), any(), String.t() | integer(), map()) ::
          {:ok, any()} | {:error, any()}
  defp validate_token_and_expiry(session, token, session_id, sessions_state) do
    with true <- secure_token_compare(session.token, token),
         false <- expired?(session) do
      # Update last activity
      updated_session = %{session | last_activity: DateTime.utc_now()}
      :ets.insert(:unified_security_sessions, {session_id, updated_session})

      session_info = %{
        user_id: session.user_id,
        metadata: session.metadata,
        expires_at: session.expires_at
      }

      {:ok, session_info, sessions_state}
    else
      false ->
        Log.module_warning("Invalid token for session #{session_id}")
        {:error, :invalid_token}

      true ->
        invalidate_session_internal(session_id, sessions_state)
        {:error, :session_expired}
    end
  end

  @spec invalidate_session_internal(String.t() | integer(), map()) :: any()
  defp invalidate_session_internal(session_id, sessions_state) do
    case lookup_session(session_id, sessions_state) do
      nil ->
        sessions_state

      session ->
        :ets.delete(:unified_security_sessions, session_id)

        :ets.delete_object(
          :unified_user_security_sessions,
          {session.user_id, session_id}
        )

        Log.info("Security session invalidated: #{session_id}")
        sessions_state
    end
  end

  @spec get_user_sessions_internal(String.t() | integer(), map()) :: any() | nil
  defp get_user_sessions_internal(user_id, _sessions_state) do
    case Raxol.Core.CompilerState.safe_lookup(
           :unified_user_security_sessions,
           user_id
         ) do
      {:ok, sessions} -> sessions
      {:error, :table_not_found} -> []
    end
    |> Enum.map(fn {_, session_id} -> lookup_session(session_id, nil) end)
    |> Enum.filter(& &1)
    |> Enum.reject(&expired?/1)
  end

  @spec check_session_limit(String.t() | integer(), any(), map()) :: any()
  defp check_session_limit(user_id, max_concurrent, sessions_state) do
    active_count = length(get_user_sessions_internal(user_id, sessions_state))

    case active_count >= max_concurrent do
      true -> {:error, :limit_exceeded}
      false -> :ok
    end
  end

  @spec expired?(any()) :: boolean()
  defp expired?(session) do
    DateTime.compare(DateTime.utc_now(), session.expires_at) == :gt
  end

  @spec secure_token_compare(any(), any()) :: any()
  defp secure_token_compare(token1, token2) do
    case byte_size(token1) == byte_size(token2) do
      true -> :crypto.hash_equals(token1, token2)
      false -> false
    end
  end

  @spec sanitize_session_info(any()) :: any()
  defp sanitize_session_info(session) do
    %{
      id: session.id,
      created_at: session.created_at,
      last_activity: session.last_activity,
      expires_at: session.expires_at,
      ip_address: session.ip_address,
      user_agent: session.user_agent
    }
  end

  defp cleanup_expired_sessions do
    case Raxol.Core.CompilerState.safe_lookup(:unified_security_sessions, :all) do
      {:ok, all_sessions} ->
        expired =
          Enum.filter(all_sessions, fn {_, session} -> expired?(session) end)

        Enum.each(expired, fn {session_id, _} ->
          invalidate_session_internal(session_id, %{})
        end)

        if length(expired) > 0 do
          Log.info("Cleaned up #{length(expired)} expired security sessions")
        end

      {:error, :table_not_found} ->
        :ok
    end
  end

  @spec count_active_sessions(any()) :: any()
  defp count_active_sessions(sessions) do
    Enum.count(sessions, fn {_, session} -> not expired?(session) end)
  end
end
