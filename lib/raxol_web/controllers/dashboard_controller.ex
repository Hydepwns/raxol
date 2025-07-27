defmodule RaxolWeb.DashboardController do
  use RaxolWeb, :controller

  def index(conn, _params) do
    # Get dashboard data
    stats = %{
      total_users: 150,
      active_projects: 25,
      total_revenue: "$45,230",
      growth_rate: "+12.5%"
    }

    render(conn, :index, stats: stats)
  end

  def overview(conn, _params) do
    # Get overview data
    overview_data = %{
      recent_activities: [
        %{
          id: 1,
          type: "user_registration",
          message: "New user registered",
          timestamp: "2024-01-15T10:30:00Z"
        },
        %{
          id: 2,
          type: "project_created",
          message: "Project 'Raxol Web App' created",
          timestamp: "2024-01-15T09:15:00Z"
        },
        %{
          id: 3,
          type: "system_update",
          message: "System updated to v1.2.0",
          timestamp: "2024-01-15T08:45:00Z"
        }
      ],
      system_status: %{
        database: "healthy",
        cache: "healthy",
        api: "healthy",
        storage: "healthy"
      }
    }

    render(conn, :overview, data: overview_data)
  end

  def analytics(conn, _params) do
    # Get analytics data
    analytics_data = %{
      user_growth: [
        %{month: "Jan", users: 120},
        %{month: "Feb", users: 135},
        %{month: "Mar", users: 150},
        %{month: "Apr", users: 165}
      ],
      project_stats: %{
        total: 25,
        active: 18,
        completed: 7,
        pending: 5
      },
      performance_metrics: %{
        response_time: "45ms",
        uptime: "99.9%",
        error_rate: "0.1%"
      }
    }

    render(conn, :analytics, data: analytics_data)
  end
end
