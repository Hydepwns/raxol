defmodule RaxolWeb.UserSessionController do
  @moduledoc """
  Handles user session management (login/logout).
  """
  use RaxolWeb, :controller

  alias Raxol.Auth
  alias RaxolWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Auth.get_user_by_email(email) do
      case Auth.authenticate_user(email, password) do
        {:ok, user} ->
          conn
          |> UserAuth.log_in_user(user, user_params)
          |> redirect(to: "/")

        {:error, _reason} ->
          conn
          |> put_flash(:error, "Invalid email or password")
          |> render(:new)
      end
    else
      conn
      |> put_flash(:error, "Invalid email or password")
      |> render(:new)
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
  end
end 