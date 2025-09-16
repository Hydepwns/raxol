defmodule RaxolWeb.Router do
  @moduledoc """
  Router for RaxolWeb.
  """

  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", RaxolWeb do
    pipe_through(:api)
    # API routes would go here
  end
end
