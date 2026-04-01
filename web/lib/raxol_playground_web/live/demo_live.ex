defmodule RaxolPlaygroundWeb.DemoLive do
  @moduledoc """
  Individual component demo page with TEALive-hosted rendering.
  Each demo runs the real Catalog demo app through the Lifecycle bridge.
  """

  use RaxolPlaygroundWeb, :live_view

  require Logger

  alias Raxol.Playground.Catalog
  alias RaxolPlaygroundWeb.Playground.{DemoLifecycle, Helpers}

  import RaxolPlaygroundWeb.PlaygroundComponents

  @demo_timeout_ms :timer.minutes(30)

  # -- Mount --

  @impl true
  def mount(%{"demo" => name}, _session, socket) do
    component = Catalog.get_component(name)

    socket =
      socket
      |> assign(:component, component)
      |> assign(:terminal_html, "")
      |> assign(:lifecycle_pid, nil)
      |> assign(:topic, nil)
      |> assign(:terminal_theme, :synthwave84)
      |> assign(:themes, Helpers.themes())
      |> assign(:show_code, false)
      |> assign(:demo_error, nil)
      |> assign(:demo_timer, nil)
      |> then(
        &DemoLifecycle.start_demo(&1, component, timeout_ms: @demo_timeout_ms)
      )

    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    components = Catalog.list_components()

    socket =
      socket
      |> assign(:component, nil)
      |> assign(:components, components)
      |> assign(:total_count, length(components))

    {:ok, socket}
  end

  # -- Events --

  @impl true
  def handle_event("select_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :terminal_theme, String.to_existing_atom(theme))}
  rescue
    ArgumentError -> {:noreply, socket}
  end

  def handle_event("toggle_code", _params, socket) do
    {:noreply, assign(socket, :show_code, !socket.assigns.show_code)}
  end

  def handle_event("keydown", params, socket) do
    if socket.assigns[:lifecycle_pid] do
      event = Raxol.LiveView.InputAdapter.translate_key_event(params)
      DemoLifecycle.dispatch_to_lifecycle(socket.assigns.lifecycle_pid, event)
    end

    {:noreply, socket}
  end

  def handle_event("retry_demo", _params, socket) do
    comp = socket.assigns.component

    socket =
      socket
      |> DemoLifecycle.stop_demo()
      |> assign(:demo_error, nil)
      |> assign(:terminal_html, "")
      |> DemoLifecycle.start_demo(comp, timeout_ms: @demo_timeout_ms)

    {:noreply, socket}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # -- Info --

  @impl true
  def handle_info({:render_update, html}, socket) do
    {:noreply, assign(socket, :terminal_html, html)}
  end

  def handle_info(:demo_timeout, socket) do
    Logger.info("Demo session timed out")
    socket = DemoLifecycle.stop_demo(socket)

    {:noreply,
     assign(socket, demo_error: "Session timed out. Click Retry to restart.")}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, socket) do
    if pid == socket.assigns[:lifecycle_pid] do
      name =
        if socket.assigns[:component],
          do: socket.assigns.component.name,
          else: "unknown"

      Logger.warning("Demo #{name} crashed: #{inspect(reason)}")

      {:noreply,
       assign(socket,
         lifecycle_pid: nil,
         demo_error: "Demo crashed. Click Retry."
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    _ = DemoLifecycle.stop_demo(socket)
    :ok
  end

  # -- Render: Index --

  @impl true
  def render(%{component: nil} = assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-100 mb-4">
            <a href="/" class="hover:text-blue-400 transition-colors">Raxol</a> Interactive Demos
          </h1>
          <p class="text-xl text-gray-400">
            <%= @total_count %> widget demos. Click to try.
          </p>
        </div>

        <.ssh_callout variant={:banner} class="mb-8" />

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          <%= for comp <- @components do %>
            <a
              href={"/demos/#{comp.name}"}
              class="block bg-gray-900 rounded-lg border border-gray-800 hover:border-gray-700 transition-colors duration-200 p-4"
            >
              <div class="flex items-start justify-between mb-2">
                <h3 class="text-lg font-semibold text-gray-100"><%= comp.name %></h3>
                <.complexity_badge level={comp.complexity} />
              </div>
              <p class="text-gray-400 text-sm mb-2"><%= comp.description %></p>
              <span class="text-xs text-gray-500"><%= Helpers.category_label(comp.category) %></span>
            </a>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # -- Render: Show --

  def render(assigns) do
    theme_bg = Helpers.theme_bg(assigns.terminal_theme)

    assigns = assign(assigns, :theme_bg, theme_bg)

    ~H"""
    <div class="h-screen flex flex-col bg-gray-950">
      <!-- Header -->
      <div class="bg-gray-900 border-b border-gray-800 px-6 py-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <a href="/demos" class="text-gray-400 hover:text-gray-100">&larr; All Demos</a>
            <div>
              <h1 class="text-2xl font-bold text-gray-100"><%= @component.name %></h1>
              <p class="text-gray-400"><%= @component.description %></p>
            </div>
            <.complexity_badge level={@component.complexity} />
          </div>

          <div class="flex items-center space-x-3">
            <.theme_selector
              theme={@terminal_theme}
              themes={@themes}
              form_id="theme-select"
            />
            <button
              phx-click="toggle_code"
              class={"px-4 py-2 border rounded-lg text-sm #{if @show_code, do: "bg-blue-900/50 border-blue-700 text-blue-300", else: "border-gray-700 text-gray-300 hover:bg-gray-800"}"}
            >
              Code
            </button>
          </div>
        </div>
      </div>

      <!-- Terminal + Code -->
      <div class="flex-1 flex overflow-hidden">
        <div class="flex-1 flex flex-col">
          <.terminal_chrome title={"#{@component.name} Demo"} />
          <div
            id="demo-terminal"
            phx-hook="RaxolTerminal"
            phx-keydown="keydown"
            class="flex-1 overflow-auto p-4 font-mono text-sm"
            style={"background: #{@theme_bg};"}
            data-theme={@terminal_theme}
            tabindex="0"
            role="application"
            aria-label={"#{@component.name} interactive demo"}
          >
            <%= if @demo_error do %>
              <div class="text-gray-400 py-8 text-center">
                <p class="text-red-400 mb-4"><%= @demo_error %></p>
                <button
                  phx-click="retry_demo"
                  class="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-lg text-sm"
                >
                  Retry
                </button>
              </div>
            <% else %>
              <%= if @terminal_html != "" do %>
                <%= Phoenix.HTML.raw(@terminal_html) %>
                <div class="mt-2 text-xs text-gray-500 opacity-70 select-none">
                  Click here and use keyboard to interact
                </div>
              <% else %>
                <%= if @lifecycle_pid do %>
                  <div class="text-gray-500 py-8 text-center" role="status">
                    <div class="inline-block w-5 h-5 border-2 border-gray-600 border-t-blue-400 rounded-full animate-spin mb-3"></div>
                    <p>Starting demo...</p>
                  </div>
                <% else %>
                  <.terminal_fallback description={@component.description} />
                <% end %>
              <% end %>
            <% end %>
          </div>
        </div>

        <.code_panel show={@show_code} code={@component.code_snippet} />
      </div>

      <.ssh_callout variant={:footer} />
    </div>
    """
  end
end
