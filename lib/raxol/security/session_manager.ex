defmodule Raxol.Security.SessionManager do
  @moduledoc """
  Secure session management with built-in security features.

  Features:
  - Cryptographically secure session tokens
  - Session expiration and renewal
  - Concurrent session limiting
  - Session fixation protection
  - Secure session storage
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Utils.TimerManager
  alias Raxol.Core.Runtime.Log

  # 30 minutes
  @session_timeout_ms 30 * 60 * 1000
  @max_concurrent_sessions 5
  @token_bytes 32

  defmodule Session do
    @moduledoc false
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
  end

  # Client API

  def start_link_legacy(opts \\ []) do
    __MODULE__.start_link(opts)
  end

  @doc """
  Creates a new secure session.

  ## Options
  - `:ip_address` - Client IP address
  - `:user_agent` - Client user agent
  - `:metadata` - Additional session metadata
  """
  def create_session(user_id, opts \\ []) do
    GenServer.call(__MODULE__, {:create_session, user_id, opts})
  end

  @doc """
  Validates a session token and returns session info.
  """
  def validate_session(session_id, token) do
    GenServer.call(__MODULE__, {:validate_session, session_id, token})
  end

  @doc """
  Refreshes session activity timestamp.
  """
  def touch_session(session_id) do
    GenServer.cast(__MODULE__, {:touch_session, session_id})
  end

  @doc """
  Invalidates a session.
  """
  def invalidate_session(session_id) do
    GenServer.call(__MODULE__, {:invalidate_session, session_id})
  end

  @doc """
  Invalidates all sessions for a user.
  """
  def invalidate_user_sessions(user_id) do
    GenServer.call(__MODULE__, {:invalidate_user_sessions, user_id})
  end

  @doc """
  Gets active sessions for a user.
  """
  def get_user_sessions(user_id) do
    GenServer.call(__MODULE__, {:get_user_sessions, user_id})
  end

  @doc """
  Regenerates session ID to prevent fixation attacks.
  """
  def regenerate_session_id(old_session_id) do
    GenServer.call(__MODULE__, {:regenerate_session_id, old_session_id})
  end

  # Server callbacks

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    # Create ETS tables for fast lookups (safe creation)
    _ =
      Raxol.Core.CompilerState.ensure_table(:sessions, [
        :set,
        :private,
        :named_table
      ])

    _ =
      Raxol.Core.CompilerState.ensure_table(:user_sessions, [
        :bag,
        :private,
        :named_table
      ])

    # Schedule cleanup
    schedule_cleanup()

    state = %{
      timeout: Keyword.get(opts, :timeout, @session_timeout_ms),
      max_concurrent:
        Keyword.get(opts, :max_concurrent, @max_concurrent_sessions)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:create_session, user_id, opts}, _from, state) do
    # Check concurrent session limit
    case check_session_limit(user_id, state.max_concurrent) do
      :ok ->
        session = create_new_session(user_id, opts, state)
        store_session(session)

        {:reply,
         {:ok,
          %{
            session_id: session.id,
            token: session.token,
            expires_at: session.expires_at
          }}, state}

      {:error, :limit_exceeded} ->
        {:reply, {:error, :session_limit_exceeded}, state}
    end
  end

  @impl true
  def handle_call({:validate_session, session_id, token}, _from, state) do
    case lookup_session(session_id) do
      nil ->
        {:reply, {:error, :invalid_session}, state}

      session ->
        validate_session_token_and_expiry(session, token, session_id, state)
    end
  end

  @impl true
  def handle_call({:invalidate_session, session_id}, _from, state) do
    invalidate_session_internal(session_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:invalidate_user_sessions, user_id}, _from, state) do
    sessions = get_user_sessions_internal(user_id)

    Enum.each(sessions, fn session ->
      invalidate_session_internal(session.id)
    end)

    {:reply, {:ok, length(sessions)}, state}
  end

  @impl true
  def handle_call({:get_user_sessions, user_id}, _from, state) do
    sessions =
      get_user_sessions_internal(user_id)
      |> Enum.map(&sanitize_session_info/1)

    {:reply, {:ok, sessions}, state}
  end

  @impl true
  def handle_call({:regenerate_session_id, old_session_id}, _from, state) do
    case lookup_session(old_session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        # Create new session with same data but new ID and token
        new_session = %{
          session
          | id: generate_session_id(),
            token: generate_secure_token(),
            created_at: DateTime.utc_now()
        }

        # Atomic swap
        invalidate_session_internal(old_session_id)
        store_session(new_session)

        {:reply,
         {:ok,
          %{
            session_id: new_session.id,
            token: new_session.token
          }}, state}
    end
  end

  @impl true
  def handle_cast({:touch_session, session_id}, state) do
    touch_session_internal(session_id)
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    cleanup_expired_sessions()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp validate_session_token_and_expiry(session, token, session_id, state) do
    with true <- secure_token_compare(session.token, token),
         false <- expired?(session) do
      # Update last activity
      touch_session_internal(session_id)

      {:reply,
       {:ok,
        %{
          user_id: session.user_id,
          metadata: session.metadata,
          expires_at: session.expires_at
        }}, state}
    else
      false ->
        Log.warning("Invalid token for session #{session_id}")
        {:reply, {:error, :invalid_token}, state}

      true ->
        invalidate_session_internal(session_id)
        {:reply, {:error, :session_expired}, state}
    end
  end

  defp create_new_session(user_id, opts, state) do
    now = DateTime.utc_now()

    %Session{
      id: generate_session_id(),
      user_id: user_id,
      token: generate_secure_token(),
      created_at: now,
      last_activity: now,
      expires_at: DateTime.add(now, state.timeout, :millisecond),
      ip_address: Keyword.get(opts, :ip_address),
      user_agent: Keyword.get(opts, :user_agent),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  defp generate_session_id do
    Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
  end

  defp generate_secure_token do
    Base.url_encode64(:crypto.strong_rand_bytes(@token_bytes), padding: false)
  end

  defp store_session(session) do
    :ets.insert(:sessions, {session.id, session})
    :ets.insert(:user_sessions, {session.user_id, session.id})
  end

  defp lookup_session(session_id) do
    case Raxol.Core.CompilerState.safe_lookup(:sessions, session_id) do
      {:ok, [{_, session}]} -> session
      {:ok, []} -> nil
      {:error, :table_not_found} -> nil
    end
  end

  defp invalidate_session_internal(session_id) do
    case lookup_session(session_id) do
      nil ->
        :ok

      session ->
        :ets.delete(:sessions, session_id)
        :ets.delete_object(:user_sessions, {session.user_id, session_id})

        Log.info("Session invalidated: #{session_id}")
    end
  end

  defp get_user_sessions_internal(user_id) do
    case Raxol.Core.CompilerState.safe_lookup(:user_sessions, user_id) do
      {:ok, sessions} -> sessions
      {:error, :table_not_found} -> []
    end
    |> Enum.map(fn {_, session_id} -> lookup_session(session_id) end)
    |> Enum.filter(& &1)
    |> Enum.reject(&expired?/1)
  end

  defp touch_session_internal(session_id) do
    case lookup_session(session_id) do
      nil ->
        :ok

      session ->
        updated = %{session | last_activity: DateTime.utc_now()}
        :ets.insert(:sessions, {session_id, updated})
    end
  end

  defp check_session_limit(user_id, max_concurrent) do
    active_count = length(get_user_sessions_internal(user_id))

    case active_count >= max_concurrent do
      true ->
        {:error, :limit_exceeded}

      false ->
        :ok
    end
  end

  defp expired?(session) do
    DateTime.compare(DateTime.utc_now(), session.expires_at) == :gt
  end

  defp secure_token_compare(token1, token2) do
    case byte_size(token1) == byte_size(token2) do
      true ->
        :crypto.hash_equals(token1, token2)

      false ->
        false
    end
  end

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
    all_sessions = :ets.tab2list(:sessions)

    expired =
      Enum.filter(all_sessions, fn {_, session} ->
        expired?(session)
      end)

    Enum.each(expired, fn {session_id, _} ->
      invalidate_session_internal(session_id)
    end)

    case length(expired) > 0 do
      true ->
        Log.info("Cleaned up #{length(expired)} expired sessions")

      false ->
        :ok
    end
  end

  defp schedule_cleanup do
    # Run cleanup every 5 minutes
    # Use TimerManager for consistent timer handling
    TimerManager.send_after(:cleanup_expired, 5 * 60 * 1000)
  end

  @doc """
  Generates a secure CSRF token for a session.
  """
  def generate_csrf_token(session_id) do
    # Use HMAC with session ID as key
    secret = Application.get_env(:raxol, :secret_key_base)

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
end
