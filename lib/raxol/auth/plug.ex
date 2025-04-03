defmodule Raxol.Auth.Plug do
  @moduledoc """
  Plug for handling authentication and authorization.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Raxol.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    cond do
      user = conn.assigns[:current_user] ->
        conn

      user = user_id && Auth.get_user(user_id) ->
        assign(conn, :current_user, user)

      true ->
        assign(conn, :current_user, nil)
    end
  end

  @doc """
  Authenticates a user by email and password.
  """
  def authenticate_user(conn, email, password) do
    case Auth.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)

      {:error, _reason} ->
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

  @doc """
  Checks if the current user has a specific permission.
  """
  def require_permission(conn, module, action) do
    if user = conn.assigns[:current_user] do
      if Auth.has_permission?(user, module, action) do
        conn
      else
        conn
        |> put_status(:forbidden)
        |> put_view(RaxolWeb.ErrorView)
        |> render("403.html")
        |> halt()
      end
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: "/login")
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