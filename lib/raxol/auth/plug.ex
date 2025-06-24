defmodule Raxol.Auth.Plug do
  @moduledoc """
  Plug for handling authentication and authorization.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Raxol.Accounts
  # alias Raxol.Repo # Removed - Unused
  # alias Raxol.Accounts.User # Removed - Unused

  require Raxol.Core.Runtime.Log

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    cond do
      _user = conn.assigns[:current_user] ->
        conn

      user = user_id && Accounts.get_user(user_id) ->
        assign(conn, :current_user, user)

      true ->
        assign(conn, :current_user, nil)
    end
  end

  @doc """
  Authenticates a user by email and password.
  """
  def authenticate_user(conn, email, password) do
    Raxol.Core.Runtime.Log.debug("Authenticating user: #{email}")

    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        Raxol.Core.Runtime.Log.debug(
          "Authentication successful for user ID: #{user.id}"
        )

        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning(
          "Authentication failed for user: #{inspect(reason)}"
        )

        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: "/login")
    end
  end

  @doc """
  Logs out the current user.
  """
  def logout_user(conn) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  defguard admin?(conn) when conn.assigns.current_user.role == :admin

  @spec require_permission(
          Plug.Conn.t(),
          atom() | list(atom()),
          atom() | list(atom())
        ) ::
          Plug.Conn.t()
  def require_permission(conn, module, action) do
    user = conn.assigns.current_user

    # Permission checking is currently disabled - Raxol.Accounts.has_permission?/3 needs implementation
    if Accounts.has_permission?(user, module, action) do
      Raxol.Core.Runtime.Log.debug(
        "Skipping permission check for #{inspect(module)}.#{action} - has_permission? not implemented."
      )

      conn
    else
      Raxol.Core.Runtime.Log.warning(
        "Authorization failed for user #{user.id} on #{inspect(module)}.#{action}"
      )

      conn
      |> put_status(:forbidden)
      |> text("Forbidden")
      |> halt()
    end
  end

  @doc """
  Checks if the current user is logged in.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
