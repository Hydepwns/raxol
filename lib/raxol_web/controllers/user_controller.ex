defmodule RaxolWeb.UserController do
  use RaxolWeb, :controller

  def index(conn, _params) do
    # Mock user data - in a real app, this would come from the database
    users = [
      %{id: 1, name: "John Doe", email: "john@example.com", role: "admin", status: "active"},
      %{id: 2, name: "Jane Smith", email: "jane@example.com", role: "user", status: "active"},
      %{id: 3, name: "Bob Johnson", email: "bob@example.com", role: "user", status: "inactive"}
    ]

    render(conn, :index, users: users)
  end

  def profile(conn, _params) do
    # Mock current user data
    current_user = %{
      id: 1,
      name: "John Doe",
      email: "john@example.com",
      role: "admin",
      avatar: "https://via.placeholder.com/150",
      bio: "Full-stack developer with 5+ years of experience",
      joined_at: "2023-01-15"
    }

    render(conn, :profile, user: current_user)
  end

  def show(conn, %{"id" => id}) do
    # Mock user data by ID
    user = %{
      id: String.to_integer(id),
      name: "User #{id}",
      email: "user#{id}@example.com",
      role: "user",
      status: "active",
      projects: [
        %{id: 1, name: "Project Alpha", status: "active"},
        %{id: 2, name: "Project Beta", status: "completed"}
      ]
    }

    render(conn, :show, user: user)
  end

  def edit(conn, %{"id" => id}) do
    # Mock user data for editing
    user = %{
      id: String.to_integer(id),
      name: "User #{id}",
      email: "user#{id}@example.com",
      role: "user",
      status: "active"
    }

    render(conn, :edit, user: user)
  end

  def update(conn, %{"id" => id} = params) do
    # Mock update logic
    updated_user = %{
      id: String.to_integer(id),
      name: params["name"] || "Updated User",
      email: params["email"] || "updated@example.com",
      role: params["role"] || "user",
      status: "active"
    }

    conn
    |> put_flash(:info, "User updated successfully")
    |> redirect(to: ~p"/users/#{id}")
  end

  def delete(conn, %{"id" => id}) do
    # Mock delete logic
    conn
    |> put_flash(:info, "User deleted successfully")
    |> redirect(to: ~p"/users")
  end
end
