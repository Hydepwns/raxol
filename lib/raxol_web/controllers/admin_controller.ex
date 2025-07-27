defmodule RaxolWeb.AdminController do
  use RaxolWeb, :controller

  def index(conn, _params) do
    # Admin dashboard data
    admin_stats = %{
      total_users: 150,
      total_projects: 25,
      system_health: "excellent",
      recent_activities: [
        %{type: "user_registration", count: 5, period: "last_24h"},
        %{type: "project_creation", count: 3, period: "last_24h"},
        %{type: "system_errors", count: 0, period: "last_24h"}
      ]
    }

    render(conn, :index, stats: admin_stats)
  end

  def users(conn, _params) do
    # Admin user management
    users = [
      %{
        id: 1,
        name: "John Doe",
        email: "john@example.com",
        role: "admin",
        status: "active",
        last_login: "2024-01-15T10:30:00Z"
      },
      %{
        id: 2,
        name: "Jane Smith",
        email: "jane@example.com",
        role: "user",
        status: "active",
        last_login: "2024-01-15T09:15:00Z"
      },
      %{
        id: 3,
        name: "Bob Johnson",
        email: "bob@example.com",
        role: "user",
        status: "inactive",
        last_login: "2024-01-10T14:20:00Z"
      }
    ]

    render(conn, :users, users: users)
  end

  def projects(conn, _params) do
    # Admin project management
    projects = [
      %{
        id: 1,
        name: "Raxol Web App",
        owner: "John Doe",
        status: "active",
        created_at: "2024-01-01"
      },
      %{
        id: 2,
        name: "Mobile Dashboard",
        owner: "Jane Smith",
        status: "active",
        created_at: "2024-01-05"
      },
      %{
        id: 3,
        name: "API Gateway",
        owner: "Bob Johnson",
        status: "completed",
        created_at: "2023-12-15"
      }
    ]

    render(conn, :projects, projects: projects)
  end

  def system(conn, _params) do
    # System monitoring and management
    system_info = %{
      server_status: %{
        cpu_usage: "45%",
        memory_usage: "67%",
        disk_usage: "23%",
        uptime: "15 days, 8 hours"
      },
      database_status: %{
        connections: 25,
        queries_per_second: 150,
        slow_queries: 2
      },
      application_metrics: %{
        response_time_avg: "45ms",
        error_rate: "0.1%",
        requests_per_minute: 1200
      }
    }

    render(conn, :system, info: system_info)
  end
end
