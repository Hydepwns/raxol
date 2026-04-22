defmodule RaxolPlaygroundWeb.ReplLive do
  @moduledoc "Redirects /repl to /playground."
  use RaxolPlaygroundWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: "/playground")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div></div>
    """
  end
end
