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
    changeset = Raxol.Auth.User.registration_changeset(%Raxol.Auth.User{}, %{})
    render(conn, :new, changeset: changeset)
  end

  @spec create(Plug.Conn.t(), %{required(String.t()) => map()}) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    changeset =
      Raxol.Auth.User.registration_changeset(%Raxol.Auth.User{}, user_params)

    case Raxol.Repo.insert(changeset) do
      {:ok, user} ->
        conn
        |> UserAuth.log_in_user(user)
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: "/")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Registration failed.")
        |> render(:new, changeset: changeset)
    end
  end
end
