defmodule Raxol.LiveView.TEALive do
  @moduledoc """
  A Phoenix LiveView that hosts a TEA (The Elm Architecture) application.

  This allows any Raxol TEA app to run in a browser with the same `init/1`,
  `update/2`, and `view/1` callbacks that work in the terminal.

  ## Usage

  In your Phoenix router:

      live "/counter", Raxol.LiveView.TEALive,
        session: %{"app_module" => "Elixir.CounterExample"}

  Or create a dedicated LiveView:

      defmodule MyAppWeb.CounterLive do
        use Phoenix.LiveView

        def mount(params, session, socket) do
          Raxol.LiveView.TEALive.mount(params, session, socket,
            app_module: CounterExample
          )
        end

        # Delegate remaining callbacks...
      end
  """

  use Phoenix.LiveView

  alias Raxol.Core.Runtime.Lifecycle
  alias Raxol.LiveView.InputAdapter

  @impl true
  def mount(params, session, socket) do
    mount(params, session, socket, [])
  end

  def mount(_params, session, socket, opts) do
    app_module =
      Keyword.get(opts, :app_module) ||
        session
        |> Map.get("app_module", "")
        |> String.to_existing_atom()

    topic = "tea_live:#{inspect(self())}"

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Raxol.PubSub, topic)

      {:ok, lifecycle_pid} =
        Lifecycle.start_link(app_module,
          environment: :liveview,
          liveview_topic: topic,
          width: 80,
          height: 24,
          name: :"tea_live_lifecycle_#{inspect(self())}"
        )

      socket =
        socket
        |> assign(:lifecycle_pid, lifecycle_pid)
        |> assign(:topic, topic)
        |> assign(:app_module, app_module)
        |> assign(:terminal_html, "")

      {:ok, socket}
    else
      socket =
        socket
        |> assign(:lifecycle_pid, nil)
        |> assign(:topic, topic)
        |> assign(:app_module, app_module)
        |> assign(:terminal_html, "")

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("keydown", params, socket) do
    event = InputAdapter.translate_key_event(params)

    if socket.assigns.lifecycle_pid do
      dispatcher_pid = find_dispatcher(socket.assigns.lifecycle_pid)

      if dispatcher_pid do
        GenServer.cast(dispatcher_pid, {:dispatch, event})
      end
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:render_update, html}, socket) do
    {:noreply, assign(socket, :terminal_html, html)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="raxol-terminal"
      phx-hook="RaxolTerminal"
      phx-window-keydown="keydown"
      class="raxol-terminal-container"
      style="font-family: monospace; background: #1a1a2e; color: #e0e0e0; padding: 1rem;"
      tabindex="0"
    >
      <%= Phoenix.HTML.raw(@terminal_html) %>
    </div>
    """
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:lifecycle_pid] do
      Lifecycle.stop(socket.assigns.lifecycle_pid)
    end

    :ok
  end

  defp find_dispatcher(lifecycle_pid) do
    state = GenServer.call(lifecycle_pid, :get_full_state)
    state.dispatcher_pid
  end
end
