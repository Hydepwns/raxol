defmodule RaxolWeb.UserRegistrationController do
  @moduledoc """
  Handles user registration.
  """
  use RaxolWeb, :controller

  # alias Raxol.Auth # Removed unused alias
  # alias Raxol.Auth.User # Removed unused alias
  alias RaxolWeb.UserAuth
  # alias RaxolWeb.Router.Helpers, as: Routes # Removed unused alias

  def new(conn, _params) do
    # TODO: Implement user changeset creation (Auth.change_user is undefined)
    # changeset = Auth.change_user_registration(%User{}) # Placeholder
    # Temporarily commenting out as Raxol.Accounts.change_user_registration/2 was removed
    # changeset = Raxol.Accounts.change_user_registration(%User{}, %{}) # Assuming an Accounts context exists
    # Placeholder
    changeset = %{}
    render(conn, :new, changeset: changeset)
  end

  @spec create(Plug.Conn.t(), %{required(String.t()) => map()}) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    # TODO: Implement user creation (Auth.create_user is undefined)
    # Assuming an Accounts context exists
    case Raxol.Accounts.register_user(user_params) do
      # case Auth.create_user(user_params) do
      {:ok, user} ->
        conn
        |> UserAuth.log_in_user(user)
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: "/")

      {:error, reason} ->
        # Convert reason map to a user-friendly string if possible
        error_msg =
          if is_map(reason) do
            reason
            |> Enum.map(fn {field, msg} -> "#{field} #{msg}" end)
            |> Enum.join(", ")
          else
            # Generic fallback
            "Registration failed."
          end

        conn
        |> put_flash(:error, "Registration failed: #{error_msg}")
        # Pass an empty map as changeset for the form
        |> render(:new, changeset: %{})
    end
  end
end
