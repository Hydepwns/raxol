defmodule RaxolWeb.Router do
  use RaxolWeb, :router

  import RaxolWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RaxolWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug :require_authenticated_user
  end

  scope "/", RaxolWeb do
    pipe_through(:browser)

    get("/", PageController, :home)

    # Authentication routes
    get("/register", UserRegistrationController, :new)
    post("/register", UserRegistrationController, :create)
    get("/login", UserSessionController, :new)
    post("/login", UserSessionController, :create)
    delete("/logout", UserSessionController, :delete)

    # Protected routes
    live("/settings", SettingsLive, :index)
    live("/monitoring", MonitoringLive, :index)
  end

  scope "/terminal", RaxolWeb do
    pipe_through([:browser, :auth])

    live("/:session_id", TerminalLive, :index)
  end

  # Other scopes may use custom stacks.
  # scope "/api", RaxolWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:raxol, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: RaxolWeb.Telemetry)
    end
  end

  # Expose Prometheus metrics endpoint
  forward "/metrics", TelemetryMetricsPrometheus
end
