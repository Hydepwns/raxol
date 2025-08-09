defmodule RaxolWeb.UserRegistrationController do
  @moduledoc """
  Handles user registration.
  """
  use RaxolWeb, :controller

  alias RaxolWeb.UserAuth

  def new(conn, _params) do
    changeset = Raxol.Auth.User.registration_changeset(%Raxol.Auth.User{}, %{})
    render(conn, :new, changeset: changeset)
  end

  @spec create(Plug.Conn.t(), %{required(String.t()) => map()}) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    changeset =
      Raxol.Auth.User.registration_changeset(%Raxol.Auth.User{}, user_params)

    if changeset.valid? do
      {:ok, user} = Raxol.Repo.insert(changeset)

      conn
      |> UserAuth.log_in_user(user)
      |> put_flash(:info, "User created successfully.")
      |> redirect(to: "/")
    else
      conn
      |> put_flash(:error, "Registration failed.")
      |> render(:new, changeset: changeset)
    end
  end
end
