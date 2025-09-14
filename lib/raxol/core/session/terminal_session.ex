defmodule Raxol.Core.Session.TerminalSession do
  @moduledoc """
  Terminal session implementation for the unified session manager.

  Provides terminal emulator session management with:
  - Session creation and authentication
  - Session state tracking
  - Terminal emulator integration
  - Session cleanup and lifecycle management
  """

  require Logger
  alias Raxol.Terminal.Emulator

  defstruct [
    :id,
    :user_id,
    :token,
    :emulator,
    :created_at,
    :last_active
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          token: String.t(),
          emulator: term(),
          created_at: DateTime.t(),
          last_active: DateTime.t()
        }

  ## Public API

  @doc """
  Creates a new terminal session.
  """
  def create(user_id, _config) do
    session = %__MODULE__{
      id: generate_session_id(),
      user_id: user_id,
      token: generate_token(),
      emulator: Emulator.new(),
      created_at: DateTime.utc_now(),
      last_active: DateTime.utc_now()
    }

    {:ok, session}
  end

  @doc """
  Authenticates a terminal session with a token.
  """
  def authenticate(session, token) do
    case session.token == token do
      true ->
        updated_session = %{session | last_active: DateTime.utc_now()}
        {:ok, updated_session}

      false ->
        {:error, :invalid_token}
    end
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

  defp generate_token do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64()
  end

  defp sanitize_session(session) do
    %{
      id: session.id,
      created_at: session.created_at,
      last_active: session.last_active,
      has_emulator: session.emulator != nil
    }
  end
end
