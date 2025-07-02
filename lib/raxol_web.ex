defmodule RaxolWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use RaxolWeb, :controller
      use RaxolWeb, :live_view
      use RaxolWeb, :live_component
      use RaxolWeb, :channel

  The definitions below will be executed for every component,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.
  """

  import Raxol.Guards

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: RaxolWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: RaxolWeb.Gettext

      unquote(verified_routes())
    end
  end

  def view do
    quote do
      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {RaxolWeb.Layouts, :root}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import RaxolWeb.CoreComponents
      use Gettext, backend: RaxolWeb.Gettext

      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: RaxolWeb.Endpoint,
        router: RaxolWeb.Router,
        statics: RaxolWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
