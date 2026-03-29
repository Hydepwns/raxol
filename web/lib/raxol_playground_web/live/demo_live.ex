defmodule RaxolPlaygroundWeb.DemoLive do
  @moduledoc """
  Individual component demo page with TEALive-hosted rendering.
  Each demo runs the real Catalog demo app through the Lifecycle bridge.
  """

  use RaxolPlaygroundWeb, :live_view

  require Logger

  alias Raxol.Playground.Catalog
  alias Raxol.Core.Runtime.Lifecycle
  alias RaxolPlaygroundWeb.Playground.Helpers

  @themes %{
    synthwave84: "#241b2f",
    dracula: "#282a36",
    nord: "#2e3440",
    monokai: "#272822",
    tokyo_night: "#1a1b26",
    catppuccin: "#1e1e2e"
  }

  # Index: list all demos
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
      |> assign(:show_code, false)
      |> start_demo()

    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:component, nil)
      |> assign(:components, Catalog.list_components())

    {:ok, socket}
  end

  # -- Events --

  @impl true
  def handle_event("select_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :terminal_theme, String.to_existing_atom(theme))}
  end

  def handle_event("toggle_code", _params, socket) do
    {:noreply, assign(socket, :show_code, !socket.assigns.show_code)}
  end

  def handle_event("keydown", params, socket) do
    if socket.assigns[:lifecycle_pid] do
      event = Raxol.LiveView.InputAdapter.translate_key_event(params)
      dispatch_to_lifecycle(socket.assigns.lifecycle_pid, event)
    end

    {:noreply, socket}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:render_update, html}, socket) do
    {:noreply, assign(socket, :terminal_html, html)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    stop_demo(socket)
    :ok
  end

  # -- Render: Index --

  @impl true
  def render(%{component: nil} = assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-900 mb-4">
            <a href="/" class="hover:text-gray-600 transition-colors">Raxol</a> Interactive Demos
          </h1>
          <p class="text-xl text-gray-600">
            23 real Raxol widget demos -- click to try
          </p>
        </div>

        <!-- SSH Callout -->
        <div class="bg-gray-900 text-green-400 rounded-lg p-4 font-mono text-sm mb-8">
          Try the real terminal experience:
          <span class="text-white ml-2">ssh playground@raxol.io</span>
          <span class="text-gray-500 mx-2">|</span>
          <span class="text-white">mix raxol.playground</span>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          <%= for comp <- @components do %>
            <a
              href={"/demos/#{comp.name}"}
              class="block bg-white rounded-lg shadow-sm border hover:shadow-md transition-shadow duration-200 p-4"
            >
              <div class="flex items-start justify-between mb-2">
                <h3 class="text-lg font-semibold text-gray-900"><%= comp.name %></h3>
                <span class={"px-2 py-1 text-xs font-medium rounded-full #{Helpers.complexity_class(comp.complexity)}"}>
                  <%= Helpers.complexity_label(comp.complexity) %>
                </span>
              </div>
              <p class="text-gray-600 text-sm mb-2"><%= comp.description %></p>
              <span class="text-xs text-gray-400"><%= Helpers.category_label(comp.category) %></span>
            </a>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # -- Render: Show --

  def render(assigns) do
    bg = Map.get(@themes, assigns.terminal_theme, "#241b2f")
    assigns = assign(assigns, :theme_bg, bg)

    ~H"""
    <div class="demo-container h-screen flex flex-col bg-gray-100">
      <!-- Header -->
      <div class="bg-white shadow-sm border-b px-6 py-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <a href="/demos" class="text-gray-600 hover:text-gray-900">&larr; All Demos</a>
            <div>
              <h1 class="text-2xl font-bold text-gray-900"><%= @component.name %></h1>
              <p class="text-gray-600"><%= @component.description %></p>
            </div>
            <span class={"px-2 py-1 text-xs font-medium rounded-full #{Helpers.complexity_class(@component.complexity)}"}>
              <%= Helpers.complexity_label(@component.complexity) %>
            </span>
          </div>

          <div class="flex items-center space-x-3">
            <form phx-change="select_theme" id="theme-select">
              <select
                name="theme"
                class="border border-gray-300 rounded px-3 py-1 text-sm"
              >
                <%= for {name, _bg} <- @themes do %>
                  <option value={name} selected={@terminal_theme == name}>
                    <%= name |> to_string() |> String.replace("_", " ") |> String.capitalize() %>
                  </option>
                <% end %>
              </select>
            </form>

            <button
              phx-click="toggle_code"
              class={"px-4 py-2 border rounded-lg text-sm #{if @show_code, do: "bg-blue-50 border-blue-300 text-blue-600", else: "border-gray-300 hover:bg-gray-100"}"}
            >
              Code
            </button>
          </div>
        </div>
      </div>

      <!-- Terminal + Code -->
      <div class="flex-1 flex overflow-hidden">
        <!-- Terminal -->
        <div class="flex-1 flex flex-col">
          <div class="bg-gray-800 px-4 py-2 flex items-center space-x-2 border-b border-gray-700">
            <div class="w-3 h-3 bg-red-500 rounded-full"></div>
            <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
            <div class="w-3 h-3 bg-green-500 rounded-full"></div>
            <span class="text-gray-400 text-sm ml-4"><%= @component.name %> Demo</span>
          </div>
          <div
            id="demo-terminal"
            phx-hook="RaxolTerminal"
            phx-window-keydown="keydown"
            class="flex-1 overflow-auto p-4 font-mono text-sm"
            style={"background: #{@theme_bg}; color: #e0e0e0;"}
            tabindex="0"
          >
            <%= if @terminal_html != "" do %>
              <%= Phoenix.HTML.raw(@terminal_html) %>
            <% else %>
              <div class="text-gray-500 py-8 text-center">
                <p class="mb-4">For the full interactive experience:</p>
                <p class="text-green-400">$ mix raxol.playground</p>
                <p class="text-green-400 mt-1">$ ssh playground@raxol.io</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Code Panel -->
        <%= if @show_code do %>
          <div class="w-1/3 border-l bg-gray-900 flex flex-col">
            <div class="px-4 py-2 bg-gray-800 text-gray-300 text-sm font-medium border-b border-gray-700">
              Code Snippet
            </div>
            <div class="flex-1 overflow-auto p-4">
              <pre class="text-green-400 font-mono text-sm whitespace-pre-wrap"><%= String.trim(@component.code_snippet) %></pre>
            </div>
          </div>
        <% end %>
      </div>

      <!-- SSH Callout -->
      <div class="bg-gray-900 text-green-400 px-6 py-3 font-mono text-sm border-t border-gray-700">
        Try the real terminal:
        <span class="text-white ml-2">ssh playground@raxol.io</span>
        <span class="text-gray-500 mx-2">|</span>
        <span class="text-white">mix raxol.playground</span>
      </div>
    </div>
    """
  end

  # -- Lifecycle management --

  defp start_demo(socket) do
    comp = socket.assigns.component

    if comp && connected?(socket) do
      topic = "demo:#{inspect(self())}:#{System.unique_integer([:positive])}"

      try do
        Phoenix.PubSub.subscribe(Raxol.PubSub, topic)

        {:ok, pid} =
          Lifecycle.start_link(comp.module,
            environment: :liveview,
            liveview_topic: topic,
            width: 80,
            height: 24
          )

        assign(socket, lifecycle_pid: pid, topic: topic)
      rescue
        e ->
          Logger.debug("Demo lifecycle failed to start: #{Exception.message(e)}")
          socket
      catch
        :exit, reason ->
          Logger.debug("Demo lifecycle exit: #{inspect(reason)}")
          socket
      end
    else
      socket
    end
  end

  defp stop_demo(socket) do
    if socket.assigns[:lifecycle_pid] do
      try do
        Lifecycle.stop(socket.assigns.lifecycle_pid)
      catch
        :exit, _ -> :ok
      end
    end

    if socket.assigns[:topic] do
      Phoenix.PubSub.unsubscribe(Raxol.PubSub, socket.assigns.topic)
    end

    :ok
  end

  defp dispatch_to_lifecycle(pid, event) do
    case GenServer.call(pid, :get_full_state) do
      %{dispatcher_pid: dpid} when is_pid(dpid) ->
        GenServer.cast(dpid, {:dispatch, event})

      _ ->
        :ok
    end
  rescue
    _ -> :ok
  end
end
