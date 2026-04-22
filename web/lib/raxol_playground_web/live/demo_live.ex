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
    {prev_comp, next_comp} = neighbor_components(name)

    socket =
      socket
      |> assign(:component, component)
      |> assign(:prev_component, prev_comp)
      |> assign(:next_component, next_comp)
      |> assign(:terminal_html, "")
      |> assign(:lifecycle_pid, nil)
      |> assign(:topic, nil)
      |> assign(:terminal_theme, :synthwave84)
      |> assign(:themes, Helpers.themes())
      |> assign(:show_code, false)
      |> assign(:demo_error, nil)
      |> assign(:demo_timer, nil)
      |> then(&DemoLifecycle.start_demo(&1, component, timeout_ms: @demo_timeout_ms))

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

    {:noreply, assign(socket, demo_error: "Session timed out. Click Retry to restart.")}
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
    <div class="atmosphere" aria-hidden="true">
      <div class="pearl-bg"></div>
      <div class="dark-overlay"></div>
    </div>

    <div class="relative min-h-screen" style="z-index: 2;">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="text-center mb-8">
          <h1 class="font-mono font-bold tracking-wide mb-4" style="font-size: clamp(1.5rem, 1.25rem + 1vw, 2.5rem); color: #e8e4dc;">
            <a href="/" class="brand-link">Raxol</a> Interactive Demos
          </h1>
          <p class="font-mono body-text">
            <%= @total_count %> widget demos. Click to try.
          </p>
        </div>

        <.ssh_callout variant={:banner} class="mb-8" />

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          <%= for comp <- @components do %>
            <a href={"/demos/#{comp.name}"} class="panel panel--glow block p-4 transition-all duration-200">
              <div class="flex items-start justify-between mb-2">
                <h3 class="font-mono font-semibold name-sky"><%= comp.name %></h3>
                <.complexity_badge level={comp.complexity} />
              </div>
              <p class="font-mono mb-2 detail-text"><%= comp.description %></p>
              <span class="font-mono label-text"><%= Helpers.category_label(comp.category) %></span>
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
    <div class="h-screen flex flex-col" style="background: var(--obsidian);">
      <!-- Header -->
      <div class="px-6 py-4 surface-bar">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <a href="/demos" class="font-mono text-sm subtle-link">&larr; All Demos</a>
            <div>
              <div class="flex items-center gap-3">
                <h1 class="font-mono font-semibold" style="font-size: clamp(1rem, 0.9rem + 0.5vw, 1.25rem); color: #e8e4dc;"><%= @component.name %></h1>
                <.complexity_badge level={@component.complexity} />
              </div>
              <p class="font-mono detail-text"><%= @component.description %></p>
            </div>
          </div>

          <div class="flex items-center space-x-3">
            <%!-- Prev/Next navigation --%>
            <nav class="hidden md:flex items-center gap-2 font-mono" style="font-size: clamp(0.7rem, 0.65rem + 0.25vw, 0.75rem);" aria-label="Demo navigation">
              <%= if @prev_component do %>
                <a href={"/demos/#{@prev_component}"} class="btn-secondary" style="padding: 0.375rem 0.75rem; font-size: inherit;" aria-label={"Previous demo: #{@prev_component}"}>
                  &larr; <%= @prev_component %>
                </a>
              <% end %>
              <%= if @next_component do %>
                <a href={"/demos/#{@next_component}"} class="btn-secondary" style="padding: 0.375rem 0.75rem; font-size: inherit;" aria-label={"Next demo: #{@next_component}"}>
                  <%= @next_component %> &rarr;
                </a>
              <% end %>
            </nav>

            <.theme_selector
              theme={@terminal_theme}
              themes={@themes}
              form_id="theme-select"
            />
            <button
              phx-click="toggle_code"
              class={"toggle-btn #{if @show_code, do: "toggle-btn--active"}"}
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
              <div class="py-8 text-center font-mono">
                <p class="mb-4 text-coral-red"><%= @demo_error %></p>
                <button phx-click="retry_demo" class="btn-primary">
                  Retry
                </button>
              </div>
            <% else %>
              <%= if @terminal_html != "" do %>
                <%= Phoenix.HTML.raw(@terminal_html) %>
                <div class="mt-2 select-none font-mono text-pearl-25" style="font-size: 0.65rem;">
                  Click here and use keyboard to interact
                </div>
              <% else %>
                <%= if @lifecycle_pid do %>
                  <div class="py-8 text-center font-mono text-pearl-40" role="status">
                    <div class="loading-spinner mb-3 mx-auto"></div>
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

      <%!-- Mobile prev/next (hidden on desktop, shown at bottom) --%>
      <div class="md:hidden flex items-center justify-between px-6 py-3 font-mono border-t border-subtle bg-panel" style="font-size: clamp(0.7rem, 0.65rem + 0.25vw, 0.75rem);">
        <%= if @prev_component do %>
          <a href={"/demos/#{@prev_component}"} class="text-pearl-50">&larr; <%= @prev_component %></a>
        <% else %>
          <span></span>
        <% end %>
        <%= if @next_component do %>
          <a href={"/demos/#{@next_component}"} class="text-pearl-50"><%= @next_component %> &rarr;</a>
        <% else %>
          <span></span>
        <% end %>
      </div>

      <.ssh_callout variant={:footer} />
    </div>
    """
  end

  # -- Helpers --

  defp neighbor_components(name) do
    all = Catalog.list_components()
    names = Enum.map(all, & &1.name)
    idx = Enum.find_index(names, &(&1 == name))

    prev_name = if idx && idx > 0, do: Enum.at(names, idx - 1)
    next_name = if idx && idx < length(names) - 1, do: Enum.at(names, idx + 1)

    {prev_name, next_name}
  end
end
