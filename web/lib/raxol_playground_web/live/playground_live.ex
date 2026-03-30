defmodule RaxolPlaygroundWeb.PlaygroundLive do
  @moduledoc """
  Main playground LiveView. Sidebar with Catalog components, TEALive-hosted
  demo rendering, code snippets, theme selector, and multi-user presence.
  """

  use RaxolPlaygroundWeb, :live_view

  require Logger

  alias Raxol.Playground.Catalog
  alias Raxol.Core.Runtime.Lifecycle
  alias RaxolPlaygroundWeb.Playground.Helpers
  alias RaxolPlaygroundWeb.Presence, as: PlaygroundPresence

  @themes Helpers.themes()
  @demo_timeout_ms :timer.minutes(30)

  # =========================================================================
  # Mount
  # =========================================================================

  @impl true
  def mount(params, _session, socket) do
    components = Catalog.list_components()

    initial_name = params["component"]
    selected = (initial_name && Catalog.get_component(initial_name)) || List.first(components)

    {socket, user_id} = init_presence(socket, selected)

    socket =
      socket
      |> assign(:components, components)
      |> assign(:selected, selected)
      |> assign(:search_query, "")
      |> assign(:terminal_html, "")
      |> assign(:lifecycle_pid, nil)
      |> assign(:topic, nil)
      |> assign(:show_code, false)
      |> assign(:show_shortcuts, false)
      |> assign(:show_users_panel, false)
      |> assign(:sync_enabled, false)
      |> assign(:sidebar_collapsed, false)
      |> assign(:terminal_theme, :synthwave84)
      |> assign(:themes, @themes)
      |> assign(:demo_error, nil)
      |> assign(:demo_timer, nil)
      |> start_demo()

    {:ok, socket}
  end

  # =========================================================================
  # Event Handlers
  # =========================================================================

  @impl true
  def handle_event("select_component", %{"component" => name}, socket) do
    component = Catalog.get_component(name)

    if component do
      if socket.assigns.user_id do
        PlaygroundPresence.update_component(socket.assigns.user_id, name)
      end

      if socket.assigns.sync_enabled do
        PlaygroundPresence.broadcast_event_from(self(), :component_selected, %{
          component: name,
          user_id: socket.assigns.user_id
        })
      end

      {:noreply, switch_demo(socket, component)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("search_components", %{"query" => query}, socket) do
    search = if query == "", do: nil, else: query
    components = Catalog.filter(search: search)

    {:noreply, socket |> assign(:search_query, query) |> assign(:components, components)}
  end

  def handle_event("toggle_code", _params, socket) do
    {:noreply, assign(socket, :show_code, !socket.assigns.show_code)}
  end

  def handle_event("toggle_shortcuts", _params, socket) do
    {:noreply, assign(socket, :show_shortcuts, !socket.assigns.show_shortcuts)}
  end

  def handle_event("toggle_users_panel", _params, socket) do
    {:noreply, assign(socket, :show_users_panel, !socket.assigns.show_users_panel)}
  end

  def handle_event("toggle_sync", _params, socket) do
    {:noreply, assign(socket, :sync_enabled, !socket.assigns.sync_enabled)}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, !socket.assigns.sidebar_collapsed)}
  end

  def handle_event("select_theme", %{"theme" => theme}, socket) do
    atom = String.to_existing_atom(theme)
    {:noreply, assign(socket, :terminal_theme, atom)}
  rescue
    ArgumentError -> {:noreply, socket}
  end

  def handle_event("retry_demo", _params, socket) do
    socket =
      socket
      |> stop_demo()
      |> assign(:demo_error, nil)
      |> assign(:terminal_html, "")
      |> start_demo()

    {:noreply, socket}
  end

  def handle_event("keydown", params, socket) do
    if socket.assigns[:lifecycle_pid] do
      event = Raxol.LiveView.InputAdapter.translate_key_event(params)
      dispatch_to_lifecycle(socket.assigns.lifecycle_pid, event)
    end

    {:noreply, socket}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # =========================================================================
  # Handle Info
  # =========================================================================

  @impl true
  def handle_info({:render_update, html}, socket) do
    {:noreply, assign(socket, :terminal_html, html)}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{event: "presence_diff"},
        socket
      ) do
    {:noreply, assign(socket, :online_users, PlaygroundPresence.list_users())}
  end

  def handle_info(
        {:playground_event, :component_selected, %{component: name, user_id: from}},
        socket
      ) do
    if socket.assigns.sync_enabled and from != socket.assigns.user_id do
      case Catalog.get_component(name) do
        nil -> {:noreply, socket}
        comp -> {:noreply, switch_demo(socket, comp)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(:demo_timeout, socket) do
    Logger.info("Playground session timed out after #{div(@demo_timeout_ms, 60_000)} minutes")
    socket = stop_demo(socket)
    {:noreply, assign(socket, demo_error: "Session timed out -- click Retry to restart")}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, socket) do
    if pid == socket.assigns[:lifecycle_pid] do
      name = if socket.assigns[:selected], do: socket.assigns.selected.name, else: "unknown"
      Logger.warning("Playground demo #{name} crashed: #{inspect(reason)}")
      {:noreply, assign(socket, lifecycle_pid: nil, demo_error: "Demo crashed -- click Retry")}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    stop_demo(socket)
    :ok
  end

  # =========================================================================
  # Render
  # =========================================================================

  @impl true
  def render(assigns) do
    theme_bg =
      Enum.find_value(@themes, "#241b2f", fn {key, _name, bg} ->
        if key == assigns.terminal_theme, do: bg
      end)

    assigns = assign(assigns, :theme_bg, theme_bg)

    ~H"""
    <div class="playground-container h-screen flex flex-col bg-gray-50">
      <!-- Header -->
      <div class="bg-white shadow-sm border-b px-6 py-3">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-4">
            <h1 class="text-xl font-bold text-gray-900">Raxol Playground</h1>
            <span class="text-sm text-gray-500">
              <a href="/" class="hover:underline">Home</a>
              <span class="mx-2">|</span>
              <a href="/gallery" class="hover:underline">Gallery</a>
              <span class="mx-2">|</span>
              <a href="/demos" class="hover:underline">Demos</a>
            </span>
          </div>

          <div class="flex items-center gap-3">
            <!-- SSH Callout -->
            <span class="text-xs text-gray-500 font-mono hidden lg:block">
              ssh playground@raxol.io
            </span>

            <!-- Users Button -->
            <button
              phx-click="toggle_users_panel"
              class={"flex items-center gap-2 px-3 py-1.5 border rounded-lg text-sm #{if @show_users_panel, do: "bg-blue-50 border-blue-300 text-blue-600", else: "border-gray-300 hover:bg-gray-100"}"}
            >
              <span><%= length(@online_users) %> online</span>
              <%= if length(@online_users) > 1 do %>
                <span class="w-2 h-2 rounded-full bg-green-400 animate-pulse"></span>
              <% end %>
            </button>

            <button
              phx-click="toggle_shortcuts"
              class="px-3 py-1.5 border border-gray-300 rounded-lg hover:bg-gray-100 text-sm"
            >
              ?
            </button>
          </div>
        </div>
      </div>

      <!-- Main Area -->
      <div class="flex-1 flex overflow-hidden">
        <!-- Sidebar -->
        <.sidebar {assigns} />

        <!-- Content -->
        <div class="flex-1 flex flex-col">
          <!-- Toolbar -->
          <.toolbar {assigns} />

          <!-- Demo + Code -->
          <div class="flex-1 flex overflow-hidden">
            <!-- Terminal Preview -->
            <div class="flex-1 flex flex-col">
              <div class="bg-gray-800 px-4 py-2 flex items-center space-x-2 border-b border-gray-700">
                <div class="w-3 h-3 bg-red-500 rounded-full"></div>
                <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
                <div class="w-3 h-3 bg-green-500 rounded-full"></div>
                <span class="text-gray-400 text-sm ml-4">
                  <%= if @selected, do: @selected.name <> " Demo", else: "Terminal" %>
                </span>
              </div>
              <div
                id="playground-terminal"
                phx-hook="RaxolTerminal"
                phx-window-keydown="keydown"
                class="flex-1 overflow-auto p-4 font-mono text-sm"
                style={"background: #{@theme_bg}; color: #e0e0e0;"}
                tabindex="0"
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
                    <p class="mt-4 text-gray-500 text-sm">Or try: ssh playground@raxol.io</p>
                  </div>
                <% else %>
                  <%= if @terminal_html != "" do %>
                    <%= Phoenix.HTML.raw(@terminal_html) %>
                  <% else %>
                    <div class="text-gray-500 py-8 text-center">
                      <%= if @selected do %>
                        <p class="mb-2 text-gray-400"><%= @selected.description %></p>
                      <% end %>
                      <p class="mb-4">For the full interactive experience:</p>
                      <p class="text-green-400">$ mix raxol.playground</p>
                      <p class="text-green-400 mt-1">$ ssh playground@raxol.io</p>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>

            <!-- Code Panel -->
            <%= if @show_code && @selected do %>
              <div class="w-1/3 border-l bg-gray-900 flex flex-col">
                <div class="px-4 py-2 bg-gray-800 text-gray-300 text-sm font-medium border-b border-gray-700">
                  Code Snippet
                </div>
                <div class="flex-1 overflow-auto p-4">
                  <pre class="text-green-400 font-mono text-sm whitespace-pre-wrap"><%= String.trim(@selected.code_snippet) %></pre>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Shortcuts Overlay -->
      <%= if @show_shortcuts do %>
        <.shortcuts_overlay {assigns} />
      <% end %>

      <!-- Users Panel -->
      <%= if @show_users_panel do %>
        <.users_panel {assigns} />
      <% end %>
    </div>
    """
  end

  # =========================================================================
  # Render Components
  # =========================================================================

  defp sidebar(assigns) do
    ~H"""
    <div class={"bg-white border-r overflow-y-auto shadow-sm transition-all duration-200 #{if @sidebar_collapsed, do: "w-16", else: "w-72"}"}>
      <div class="p-3">
        <div class="flex items-center justify-between mb-3">
          <%= if not @sidebar_collapsed do %>
            <h2 class="text-lg font-bold text-gray-800">Components</h2>
          <% end %>
          <button
            phx-click="toggle_sidebar"
            class="p-2 rounded hover:bg-gray-200 text-gray-500 text-lg leading-none"
            title={if @sidebar_collapsed, do: "Expand sidebar", else: "Collapse sidebar"}
          >
            <%= if @sidebar_collapsed, do: ">", else: "<" %>
          </button>
        </div>

        <%= if not @sidebar_collapsed do %>
          <form phx-change="search_components" id="sidebar-search" class="mb-3">
            <input
              type="text"
              name="query"
              placeholder="Search..."
              value={@search_query}
              phx-debounce="300"
              class="w-full px-3 py-1.5 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </form>

          <div class="space-y-1">
            <%= for comp <- @components do %>
              <div
                class={"p-2 rounded cursor-pointer text-sm #{if @selected && @selected.name == comp.name, do: "bg-blue-50 border border-blue-200", else: "hover:bg-gray-50"}"}
                phx-click="select_component"
                phx-value-component={comp.name}
              >
                <div class="font-medium text-gray-900"><%= comp.name %></div>
                <div class="text-xs text-gray-500"><%= comp.description %></div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="space-y-1">
            <%= for comp <- @components do %>
              <div
                class={"p-2 rounded cursor-pointer text-center #{if @selected && @selected.name == comp.name, do: "bg-blue-50 border border-blue-200", else: "hover:bg-gray-50"}"}
                phx-click="select_component"
                phx-value-component={comp.name}
                title={comp.name}
              >
                <span class="font-bold text-sm text-gray-700"><%= String.first(comp.name) %></span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp toolbar(assigns) do
    ~H"""
    <div class="border-b bg-gray-50 px-4 py-2">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <%= if @selected do %>
            <span class="font-semibold text-gray-900"><%= @selected.name %></span>
            <span class={"px-2 py-0.5 text-xs font-medium rounded-full #{Helpers.complexity_class(@selected.complexity)}"}>
              <%= Helpers.complexity_label(@selected.complexity) %>
            </span>
            <span class="text-xs text-gray-500"><%= Helpers.category_label(@selected.category) %></span>
          <% end %>
        </div>

        <div class="flex items-center gap-2">
          <form phx-change="select_theme" id="theme-selector">
            <select
              name="theme"
              class="border border-gray-300 rounded px-2 py-1 text-xs"
            >
              <%= for {key, label, _bg} <- @themes do %>
                <option value={key} selected={@terminal_theme == key}><%= label %></option>
              <% end %>
            </select>
          </form>

          <button
            phx-click="toggle_code"
            class={"px-3 py-1 border rounded text-xs #{if @show_code, do: "bg-blue-50 border-blue-300 text-blue-600", else: "border-gray-300 hover:bg-gray-100"}"}
          >
            Code
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp shortcuts_overlay(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      phx-click="toggle_shortcuts"
    >
      <div class="bg-white rounded-lg shadow-xl p-6 max-w-md">
        <h3 class="text-lg font-bold mb-4">Keyboard Shortcuts</h3>
        <div class="space-y-2 text-sm">
          <div class="flex justify-between gap-8">
            <span>Navigate components</span>
            <span class="font-mono text-gray-600">j / k</span>
          </div>
          <div class="flex justify-between gap-8">
            <span>Select component</span>
            <span class="font-mono text-gray-600">Enter</span>
          </div>
          <div class="flex justify-between gap-8">
            <span>Toggle code panel</span>
            <span class="font-mono text-gray-600">c</span>
          </div>
          <div class="flex justify-between gap-8">
            <span>Search</span>
            <span class="font-mono text-gray-600">/</span>
          </div>
          <div class="flex justify-between gap-8">
            <span>Toggle shortcuts</span>
            <span class="font-mono text-gray-600">?</span>
          </div>
        </div>
        <div class="mt-4 pt-4 border-t text-xs text-gray-500">
          Click anywhere to close
        </div>
      </div>
    </div>
    """
  end

  defp users_panel(assigns) do
    ~H"""
    <div class="fixed right-4 top-16 w-72 bg-white rounded-lg shadow-xl border z-50">
      <div class="p-4 border-b flex justify-between items-center">
        <h3 class="font-semibold text-gray-800">Online (<%= length(@online_users) %>)</h3>
        <button phx-click="toggle_users_panel" class="text-gray-400 hover:text-gray-600">
          &times;
        </button>
      </div>

      <div class="p-3 border-b">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={@sync_enabled}
            phx-click="toggle_sync"
            class="rounded text-blue-600"
          />
          <span class="text-sm text-gray-700">Sync with others</span>
        </label>
        <p class="text-xs text-gray-500 mt-1">
          Selections sync across sessions when enabled
        </p>
      </div>

      <div class="max-h-64 overflow-y-auto">
        <%= if @online_users == [] do %>
          <div class="p-4 text-center text-gray-500 text-sm">No other users online</div>
        <% else %>
          <ul class="divide-y divide-gray-100">
            <%= for user <- @online_users do %>
              <li class="p-3 flex items-center gap-3">
                <div
                  class="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-medium"
                  style={"background-color: #{user.color}"}
                >
                  <%= String.first(user.name) %>
                </div>
                <div class="flex-1 min-w-0">
                  <span class={"text-sm font-medium #{if user.user_id == @user_id, do: "text-blue-600", else: "text-gray-800"}"}>
                    <%= user.name %>
                    <%= if user.user_id == @user_id, do: "(you)" %>
                  </span>
                  <%= if user.current_component do %>
                    <div class="text-xs text-gray-500 truncate">
                      Viewing: <%= user.current_component %>
                    </div>
                  <% end %>
                </div>
                <div class="w-2 h-2 rounded-full bg-green-400"></div>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>
    </div>
    """
  end

  # =========================================================================
  # Private Helpers
  # =========================================================================

  defp init_presence(socket, selected) do
    if connected?(socket) do
      PlaygroundPresence.subscribe()
      {:ok, user_id, user_meta} = PlaygroundPresence.track_user(socket)

      if selected do
        PlaygroundPresence.update_component(user_id, selected.name)
      end

      socket =
        socket
        |> assign(:user_id, user_id)
        |> assign(:user_meta, user_meta)
        |> assign(:online_users, PlaygroundPresence.list_users())

      {socket, user_id}
    else
      socket =
        socket
        |> assign(:user_id, nil)
        |> assign(:user_meta, %{})
        |> assign(:online_users, [])

      {socket, nil}
    end
  end

  defp switch_demo(socket, comp) do
    socket
    |> stop_demo()
    |> assign(:selected, comp)
    |> assign(:terminal_html, "")
    |> assign(:demo_error, nil)
    |> start_demo()
  end

  defp start_demo(socket) do
    comp = socket.assigns.selected

    if comp && connected?(socket) do
      topic = "playground:#{inspect(self())}:#{System.unique_integer([:positive])}"

      try do
        Phoenix.PubSub.subscribe(Raxol.PubSub, topic)

        case Lifecycle.start_link(comp.module,
               environment: :liveview,
               liveview_topic: topic,
               width: 80,
               height: 24
             ) do
          {:ok, pid} ->
            Process.monitor(pid)
            timer = Process.send_after(self(), :demo_timeout, @demo_timeout_ms)
            assign(socket, lifecycle_pid: pid, topic: topic, demo_timer: timer)

          {:error, reason} ->
            Logger.warning("Playground demo #{comp.name} failed: #{inspect(reason)}")
            assign(socket, demo_error: "Failed to start demo")
        end
      rescue
        e ->
          Logger.warning("Playground demo #{comp.name} failed: #{Exception.message(e)}")
          assign(socket, demo_error: "Failed to start demo")
      catch
        :exit, reason ->
          Logger.warning("Playground demo #{comp.name} exit: #{inspect(reason)}")
          assign(socket, demo_error: "Failed to start demo")
      end
    else
      socket
    end
  end

  defp stop_demo(socket) do
    if socket.assigns[:demo_timer] do
      Process.cancel_timer(socket.assigns.demo_timer)
    end

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

    assign(socket, lifecycle_pid: nil, topic: nil, demo_timer: nil)
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
