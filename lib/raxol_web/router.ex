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
    get("/about", PageController, :about)
    get("/contact", PageController, :contact)

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

  # Dashboard routes (protected)
  scope "/dashboard", RaxolWeb do
    pipe_through([:browser, :auth])

    get("/", DashboardController, :index)
    get("/overview", DashboardController, :overview)
    get("/analytics", DashboardController, :analytics)
  end

  # User management routes (protected)
  scope "/users", RaxolWeb do
    pipe_through([:browser, :auth])

    get("/", UserController, :index)
    get("/profile", UserController, :profile)
    get("/:id", UserController, :show)
    get("/:id/edit", UserController, :edit)
    put("/:id", UserController, :update)
    delete("/:id", UserController, :delete)
  end

  # Project management routes (protected)
  scope "/projects", RaxolWeb do
    pipe_through([:browser, :auth])

    get("/", ProjectController, :index)
    get("/new", ProjectController, :new)
    post("/", ProjectController, :create)
    get("/:id", ProjectController, :show)
    get("/:id/edit", ProjectController, :edit)
    put("/:id", ProjectController, :update)
    delete("/:id", ProjectController, :delete)
  end

  # Admin routes (protected)
  scope "/admin", RaxolWeb do
    pipe_through([:browser, :auth])

    get("/", AdminController, :index)
    get("/users", AdminController, :users)
    get("/projects", AdminController, :projects)
    get("/system", AdminController, :system)
  end

  scope "/terminal", RaxolWeb do
    pipe_through([:browser, :auth])

    live("/:session_id", TerminalLive, :index)
  end

  # API routes
  scope "/api", RaxolWeb do
    pipe_through :api

    # Public API endpoints
    get("/health", ApiController, :health)
    get("/status", ApiController, :status)

    # Protected API endpoints
    scope "/v1" do
      pipe_through :auth

      # User API
      get("/users", Api.UserController, :index)
      get("/users/:id", Api.UserController, :show)
      post("/users", Api.UserController, :create)
      put("/users/:id", Api.UserController, :update)
      delete("/users/:id", Api.UserController, :delete)

      # Project API
      get("/projects", Api.ProjectController, :index)
      get("/projects/:id", Api.ProjectController, :show)
      post("/projects", Api.ProjectController, :create)
      put("/projects/:id", Api.ProjectController, :update)
      delete("/projects/:id", Api.ProjectController, :delete)

      # Dashboard API
      get("/dashboard/stats", Api.DashboardController, :stats)
      get("/dashboard/analytics", Api.DashboardController, :analytics)
    end
  end

  # Enable LiveDashboard in development
  # Note: Commented out due to missing phoenix_live_dashboard dependency
  # if Application.compile_env(:raxol, :dev_routes) do
  #   import Phoenix.LiveDashboard.Router
  #
  #   scope "/dev" do
  #     pipe_through(:browser)
  #
  #     live_dashboard("/dashboard", metrics: RaxolWeb.Telemetry)
  #   end
  # end

  # Metrics endpoint
  forward("/metrics", TelemetryMetricsPrometheus.Router)
end
