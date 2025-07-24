defmodule RaxolWeb.Api.UserController do
  use RaxolWeb, :controller

  def index(conn, _params) do
    users = [
      %{id: 1, name: "John Doe", email: "john@example.com", role: "admin"},
      %{id: 2, name: "Jane Smith", email: "jane@example.com", role: "user"},
      %{id: 3, name: "Bob Johnson", email: "bob@example.com", role: "user"}
    ]

    json(conn, %{users: users, total: length(users)})
  end

  def show(conn, %{"id" => id}) do
    user = %{
      id: String.to_integer(id),
      name: "User #{id}",
      email: "user#{id}@example.com",
      role: "user",
      created_at: "2024-01-01T00:00:00Z"
    }

    json(conn, user)
  end

  def create(conn, params) do
    new_user = %{
      id: 4,
      name: params["name"],
      email: params["email"],
      role: params["role"] || "user",
      created_at: DateTime.utc_now()
    }

    conn
    |> put_status(:created)
    |> json(new_user)
  end

  def update(conn, %{"id" => id} = params) do
    updated_user = %{
      id: String.to_integer(id),
      name: params["name"],
      email: params["email"],
      role: params["role"],
      updated_at: DateTime.utc_now()
    }

    json(conn, updated_user)
  end

  def delete(conn, %{"id" => _id}) do
    conn
    |> put_status(:no_content)
    |> json(%{})
  end
end
