defmodule RaxolWeb.Router do
  @moduledoc """
  Router for RaxolWeb.
  """

  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RaxolWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RaxolWeb do
    pipe_through(:browser)

    live("/", DemoLive)
    live("/demo", DemoLive)
  end

  scope "/api", RaxolWeb do
    pipe_through(:api)
    # API routes would go here
  end
end
