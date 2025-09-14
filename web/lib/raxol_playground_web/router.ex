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

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RaxolPlaygroundWeb do
    pipe_through :browser

    live "/", PlaygroundLive, :index
    live "/components", ComponentsLive, :index
    live "/components/:component", ComponentsLive, :show
    live "/examples", ExamplesLive, :index
    live "/examples/:example", ExamplesLive, :show
    live "/docs", DocsLive, :index
    live "/docs/*path", DocsLive, :show
    live "/repl", ReplLive, :index
  end

  scope "/api", RaxolPlaygroundWeb do
    pipe_through :api

    post "/repl/eval", ReplController, :eval
    get "/components", ComponentController, :index
    get "/components/:id", ComponentController, :show
  end
end