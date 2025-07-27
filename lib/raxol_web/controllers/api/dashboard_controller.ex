defmodule RaxolWeb.Api.DashboardController do
  use RaxolWeb, :controller

  def stats(conn, _params) do
    stats = %{
      total_users: 150,
      active_projects: 25,
      total_revenue: 45_230,
      growth_rate: 12.5,
      chart_data: [
        %{month: "Jan", users: 120, projects: 20},
        %{month: "Feb", users: 135, projects: 22},
        %{month: "Mar", users: 150, projects: 25},
        %{month: "Apr", users: 165, projects: 28}
      ]
    }

    json(conn, stats)
  end

  def analytics(conn, _params) do
    analytics = %{
      user_growth: [
        %{date: "2025-01-01", new_users: 5},
        %{date: "2025-01-02", new_users: 8},
        %{date: "2025-01-03", new_users: 12},
        %{date: "2025-01-04", new_users: 7}
      ],
      project_activity: [
        %{date: "2025-01-01", created: 2, completed: 1},
        %{date: "2025-01-02", created: 3, completed: 0},
        %{date: "2025-01-03", created: 1, completed: 2},
        %{date: "2025-01-04", created: 4, completed: 1}
      ],
      performance_metrics: %{
        response_time_avg: 45,
        uptime_percentage: 99.9,
        error_rate: 0.1
      }
    }

    json(conn, analytics)
  end
end
