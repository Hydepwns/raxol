defmodule RaxolPlaygroundWeb.Router do
  use RaxolPlaygroundWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RaxolPlaygroundWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", RaxolPlaygroundWeb do
    pipe_through :browser

    live "/", LandingLive, :index
    live "/playground", PlaygroundLive, :index
    live "/gallery", GalleryLive, :index
    live "/demos", DemoLive, :index
    live "/demos/:demo", DemoLive, :show
    live "/repl", ReplLive, :index
    get "/health", HealthController, :check
  end
end
