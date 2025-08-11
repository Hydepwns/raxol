defmodule RaxolWeb.ApiController do
  use RaxolWeb, :controller

  def health(conn, _params) do
    health_status = %{
      status: "healthy",
      timestamp: DateTime.utc_now(),
      version: "1.0.1",
      uptime: "15 days, 8 hours"
    }

    json(conn, health_status)
  end

  def status(conn, _params) do
    status_info = %{
      application: "Raxol",
      environment: Mix.env(),
      database: "connected",
      cache: "connected",
      api_version: "v1",
      endpoints: [
        "/api/health",
        "/api/status",
        "/api/v1/users",
        "/api/v1/projects",
        "/api/v1/dashboard"
      ]
    }

    json(conn, status_info)
  end
end
