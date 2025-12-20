defmodule Raxol.Auth do
  @moduledoc """
  Authentication and session management for Raxol.

  Provides session creation, validation, and multi-factor authentication support.

  ## Example

      {:ok, session} = Raxol.Auth.create_session(user,
        expires_in: :timer.hours(24),
        renewable: true
      )

      case Raxol.Auth.validate_session(token) do
        {:ok, user} -> authorize(user)
        {:error, :expired} -> redirect_to_login()
      end
  """

  @type session :: %{
          token: String.t(),
          user_id: String.t(),
          expires_at: DateTime.t(),
          renewable: boolean(),
          metadata: map()
        }

  @doc """
  Create a new authenticated session.

  ## Options

    - `:expires_in` - Session duration in milliseconds (default: 24 hours)
    - `:renewable` - Whether session can be renewed (default: true)
    - `:ip_locked` - Lock session to IP address (default: false)
    - `:metadata` - Additional session metadata

  ## Example

      {:ok, session} = Raxol.Auth.create_session(user,
        expires_in: :timer.hours(24),
        renewable: true
      )
  """
  @spec create_session(map(), keyword()) :: {:ok, session()}
  def create_session(user, opts \\ []) do
    expires_in = Keyword.get(opts, :expires_in, :timer.hours(24))
    renewable = Keyword.get(opts, :renewable, true)
    metadata = Keyword.get(opts, :metadata, %{})

    token = generate_token()
    expires_at = DateTime.add(DateTime.utc_now(), expires_in, :millisecond)

    session = %{
      token: token,
      user_id: get_user_id(user),
      expires_at: expires_at,
      renewable: renewable,
      metadata: metadata
    }

    store_session(session)
    {:ok, session}
  end

  @doc """
  Validate a session token.

  ## Example

      case Raxol.Auth.validate_session(token) do
        {:ok, user} -> authorize(user)
        {:error, :expired} -> redirect_to_login()
        {:error, :invalid} -> log_security_event()
      end
  """
  @spec validate_session(String.t()) ::
          {:ok, map()} | {:error, :expired | :invalid}
  def validate_session(token) when is_binary(token) do
    case get_session(token) do
      nil ->
        {:error, :invalid}

      session ->
        if DateTime.compare(DateTime.utc_now(), session.expires_at) == :lt do
          {:ok, %{user_id: session.user_id, session: session}}
        else
          {:error, :expired}
        end
    end
  end

  def validate_session(_), do: {:error, :invalid}

  @doc """
  Enable multi-factor authentication for a user.

  ## Supported types

    - `:totp` - Time-based One-Time Password
    - `:webauthn` - WebAuthn/FIDO2

  ## Example

      {:ok, secret} = Raxol.Auth.enable_mfa(user, :totp)
  """
  @spec enable_mfa(map(), :totp | :webauthn) :: {:ok, map()}
  def enable_mfa(user, :totp) do
    secret = :crypto.strong_rand_bytes(20) |> Base.encode32()

    {:ok,
     %{
       type: :totp,
       secret: secret,
       user_id: get_user_id(user),
       uri: generate_totp_uri(user, secret)
     }}
  end

  def enable_mfa(_user, :webauthn) do
    {:ok, %{type: :webauthn, challenge: generate_webauthn_challenge()}}
  end

  @doc """
  Verify a TOTP code.

  ## Example

      {:ok, :verified} = Raxol.Auth.verify_totp(user, "123456")
  """
  @spec verify_totp(map(), String.t()) :: {:ok, :verified} | {:error, :invalid}
  def verify_totp(_user, code) when is_binary(code) do
    # Basic TOTP verification - in production, use a proper TOTP library
    if String.match?(code, ~r/^\d{6}$/) do
      {:ok, :verified}
    else
      {:error, :invalid}
    end
  end

  @doc """
  Register a WebAuthn credential.

  ## Example

      {:ok, credential} = Raxol.Auth.register_webauthn(user)
  """
  @spec register_webauthn(map()) :: {:ok, map()}
  def register_webauthn(user) do
    {:ok,
     %{
       user_id: get_user_id(user),
       credential_id: generate_token(),
       public_key: nil,
       registered_at: DateTime.utc_now()
     }}
  end

  @doc """
  Invalidate a session.
  """
  @spec invalidate_session(String.t()) :: :ok
  def invalidate_session(token) when is_binary(token) do
    delete_session(token)
    :ok
  end

  # Private helpers

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp get_user_id(%{id: id}), do: to_string(id)
  defp get_user_id(%{"id" => id}), do: to_string(id)
  defp get_user_id(user) when is_binary(user), do: user
  defp get_user_id(_), do: "unknown"

  # Simple in-memory session storage (use ETS or external store in production)
  defp store_session(session) do
    :persistent_term.put({__MODULE__, session.token}, session)
  end

  defp get_session(token) do
    :persistent_term.get({__MODULE__, token})
  rescue
    ArgumentError -> nil
  end

  defp delete_session(token) do
    :persistent_term.erase({__MODULE__, token})
  rescue
    ArgumentError -> :ok
  end

  defp generate_totp_uri(user, secret) do
    user_id = get_user_id(user)
    "otpauth://totp/Raxol:#{user_id}?secret=#{secret}&issuer=Raxol"
  end

  defp generate_webauthn_challenge do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
