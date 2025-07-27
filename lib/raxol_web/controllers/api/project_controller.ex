defmodule RaxolWeb.Api.ProjectController do
  use RaxolWeb, :controller

  def index(conn, _params) do
    projects = [
      %{
        id: 1,
        name: "Raxol Web App",
        description: "Modern web application",
        status: "active"
      },
      %{
        id: 2,
        name: "Mobile Dashboard",
        description: "React Native app",
        status: "active"
      },
      %{
        id: 3,
        name: "API Gateway",
        description: "Microservices gateway",
        status: "completed"
      }
    ]

    json(conn, %{projects: projects, total: length(projects)})
  end

  def show(conn, %{"id" => id}) do
    project = %{
      id: String.to_integer(id),
      name: "Project #{id}",
      description: "Description for project #{id}",
      status: "active",
      created_at: "2024-01-01T00:00:00Z"
    }

    json(conn, project)
  end

  def create(conn, params) do
    new_project = %{
      id: 4,
      name: params["name"],
      description: params["description"],
      status: "active",
      created_at: DateTime.utc_now()
    }

    conn
    |> put_status(:created)
    |> json(new_project)
  end

  def update(conn, %{"id" => id} = params) do
    updated_project = %{
      id: String.to_integer(id),
      name: params["name"],
      description: params["description"],
      status: params["status"],
      updated_at: DateTime.utc_now()
    }

    json(conn, updated_project)
  end

  def delete(conn, %{"id" => _id}) do
    conn
    |> put_status(:no_content)
    |> json(%{})
  end
end
