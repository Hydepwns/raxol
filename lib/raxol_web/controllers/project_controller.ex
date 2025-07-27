defmodule RaxolWeb.ProjectController do
  use RaxolWeb, :controller

  def index(conn, _params) do
    # Mock project data
    projects = [
      %{
        id: 1,
        name: "Raxol Web App",
        description: "Modern web application built with Phoenix",
        status: "active",
        progress: 75
      },
      %{
        id: 2,
        name: "Mobile Dashboard",
        description: "React Native mobile app",
        status: "active",
        progress: 45
      },
      %{
        id: 3,
        name: "API Gateway",
        description: "Microservices API gateway",
        status: "completed",
        progress: 100
      },
      %{
        id: 4,
        name: "Data Analytics",
        description: "Real-time analytics platform",
        status: "pending",
        progress: 0
      }
    ]

    render(conn, :index, projects: projects)
  end

  def new(conn, _params) do
    render(conn, :new)
  end

  def create(conn, params) do
    # Mock project creation
    new_project = %{
      id: 5,
      name: params["name"] || "New Project",
      description: params["description"] || "Project description",
      status: "active",
      progress: 0
    }

    conn
    |> put_flash(:info, "Project created successfully")
    |> redirect(to: ~p"/projects/#{new_project.id}")
  end

  def show(conn, %{"id" => id}) do
    # Mock project data by ID
    project = %{
      id: String.to_integer(id),
      name: "Project #{id}",
      description: "Detailed description of project #{id}",
      status: "active",
      progress: 65,
      team_members: [
        %{id: 1, name: "John Doe", role: "Lead Developer"},
        %{id: 2, name: "Jane Smith", role: "UI/UX Designer"}
      ],
      tasks: [
        %{id: 1, title: "Setup development environment", status: "completed"},
        %{id: 2, title: "Design database schema", status: "in_progress"},
        %{id: 3, title: "Implement authentication", status: "pending"}
      ]
    }

    render(conn, :show, project: project)
  end

  def edit(conn, %{"id" => id}) do
    # Mock project data for editing
    project = %{
      id: String.to_integer(id),
      name: "Project #{id}",
      description: "Description for project #{id}",
      status: "active"
    }

    render(conn, :edit, project: project)
  end

  def update(conn, %{"id" => id} = params) do
    # Mock update logic
    _updated_project = %{
      id: String.to_integer(id),
      name: params["name"] || "Updated Project",
      description: params["description"] || "Updated description",
      status: "active"
    }

    conn
    |> put_flash(:info, "Project updated successfully")
    |> redirect(to: ~p"/projects/#{id}")
  end

  def delete(conn, %{"id" => _id}) do
    # Mock delete logic
    conn
    |> put_flash(:info, "Project deleted successfully")
    |> redirect(to: ~p"/projects")
  end
end
