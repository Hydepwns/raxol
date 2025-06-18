defmodule RaxolWeb.UserSessionController do
  @moduledoc '''
  Handles user session management (login/logout).
  '''
  use RaxolWeb, :controller

  # Use Accounts context
  alias Raxol.Accounts
  alias RaxolWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, error_message: nil)
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    # Use Raxol.Accounts for authentication
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        UserAuth.log_in_user(conn, user)

      {:error, :invalid_credentials} ->
        # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
        render(conn, :new, error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
  end
end
