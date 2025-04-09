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
    %{ "email" => email, "password" => password } = user_params
    # TODO: Implement user lookup (Auth.get_user_by_email is undefined)
    # case Raxol.Accounts.get_user_by_email_and_password(email, password) do # Assumed Accounts func
    case Auth.authenticate_user(email, password) do # Use existing Auth function for now
    # if user = Auth.get_user_by_email(email) do
    #   if Pbkdf2.verify_pass(password, user.hashed_password) do
      {:ok, session_data} -> # Assuming authenticate_user returns session_data
        user = Auth.get_user(session_data.user_id) # Fetch user details
        conn
        |> put_flash(:info, "Welcome back!")
        |> UserAuth.log_in_user(user, user_params)
      _error ->
        # In order to prevent user enumeration attacks,
        # we render the Markdup template non-dependently of invalid email/password scenarios.
        conn
        |> put_flash(:error, "Invalid email or password")
        |> put_session(:user_token, nil) # Ensure no token is set
        |> redirect(to: ~p"/login") # Correct path
        # |> redirect(to: ~p"/users/log_in")
    #   else
    #     # In order to prevent user enumeration attacks,
    #     # we render the Markdup template non-dependently of invalid email/password scenarios.
    #     conn
    #     |> put_flash(:error, "Invalid email or password")
    #     |> redirect(to: ~p"/login") # Correct path
    #     # |> redirect(to: ~p"/users/log_in")
    #   end
    # else
    #   # In order to prevent user enumeration attacks,
    #   # we render the Markdup template non-dependently of invalid email/password scenarios.
    #   conn
    #   |> put_flash(:error, "Invalid email or password")
    #   |> redirect(to: ~p"/login") # Correct path
    #   # |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
  end
end
