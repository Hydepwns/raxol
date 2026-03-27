defmodule RaxolWeb.CounterLive do
  @moduledoc """
  LiveView that hosts the CounterExample TEA app in the browser.

  Delegates all callbacks to `Raxol.LiveView.TEALive`, which starts a
  Lifecycle process and renders the TEA app's output as HTML. Browser
  keydown events are translated to Raxol events via InputAdapter.

  Same CounterExample module, different target.
  """

  use RaxolWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    Raxol.LiveView.TEALive.mount(params, session, socket,
      app_module: CounterExample
    )
  end

  @impl true
  defdelegate handle_event(event, params, socket), to: Raxol.LiveView.TEALive

  @impl true
  defdelegate handle_info(msg, socket), to: Raxol.LiveView.TEALive

  @impl true
  defdelegate render(assigns), to: Raxol.LiveView.TEALive

  @impl true
  defdelegate terminate(reason, socket), to: Raxol.LiveView.TEALive
end
