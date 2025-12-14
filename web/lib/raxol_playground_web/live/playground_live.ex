defmodule RaxolPlaygroundWeb.PlaygroundLive do
  @moduledoc """
  LiveView for the Raxol Component Playground.
  Provides interactive demos and code examples for Raxol UI components.

  ## Multi-User Features

  When multiple users are connected, they can:
  - See who else is viewing the playground
  - See which component others are viewing
  - Optionally sync demo state across sessions
  """

  use RaxolPlaygroundWeb, :live_view

  import Raxol.HEEx.Components

  alias RaxolPlaygroundWeb.Playground.{
    CodeExecutor,
    CodeExamples,
    DemoComponents,
    Helpers,
    TerminalView
  }

  alias RaxolPlaygroundWeb.Presence, as: PlaygroundPresence

  @impl true
  def mount(_params, _session, socket) do
    components = CodeExamples.list_components()
    first_component = List.first(components)

    # Use streams for efficient component list rendering
    # Each component needs a unique DOM ID for stream management
    components_with_ids =
      components
      |> Enum.with_index()
      |> Enum.map(fn {component, idx} ->
        Map.put(component, :dom_id, "component-#{idx}-#{component.name}")
      end)

    # Initialize multi-user presence tracking
    {socket, user_id} =
      if connected?(socket) do
        PlaygroundPresence.subscribe()

        {:ok, user_id, user_meta} = PlaygroundPresence.track_user(socket)

        # Update component on initial mount
        if first_component do
          PlaygroundPresence.update_component(user_id, first_component.name)
        end

        online_users = PlaygroundPresence.list_users()

        socket =
          socket
          |> assign(:user_id, user_id)
          |> assign(:user_meta, user_meta)
          |> assign(:online_users, online_users)
          |> assign(:show_users_panel, false)
          |> assign(:sync_enabled, false)

        {socket, user_id}
      else
        socket =
          socket
          |> assign(:user_id, nil)
          |> assign(:user_meta, %{})
          |> assign(:online_users, [])
          |> assign(:show_users_panel, false)
          |> assign(:sync_enabled, false)

        {socket, nil}
      end

    socket =
      socket
      |> assign(:all_components, components_with_ids)
      |> stream(:components, components_with_ids)
      |> assign(:selected_component, first_component)
      |> assign(:component_code, CodeExamples.get_code(first_component))
      |> assign(:preview_output, "")
      |> assign(:error_message, nil)
      |> assign(:search_query, "")
      |> assign(:selected_framework, "universal")
      |> assign(:auto_run, true)
      |> assign(:show_shortcuts, false)
      |> assign(:is_running, false)
      |> assign(:view_mode, :demo)
      |> assign(:sidebar_collapsed, false)
      |> assign(:demo_state, Helpers.initial_demo_state())
      |> assign(:terminal_theme, :dracula)
      |> assign(:current_user_id, user_id)

    {:ok, socket}
  end

  # ===========================================================================
  # Event Handlers - Component Selection
  # ===========================================================================

  @impl true
  def handle_event("select_component", %{"component" => component_name}, socket) do
    component = Enum.find(socket.assigns.all_components, &(&1.name == component_name))
    code = CodeExamples.get_code(component)

    # Update presence to show current component
    if socket.assigns.user_id do
      PlaygroundPresence.update_component(socket.assigns.user_id, component_name)
    end

    # Broadcast to other users if sync enabled
    if socket.assigns.sync_enabled do
      PlaygroundPresence.broadcast_event_from(
        self(),
        :component_selected,
        %{component: component_name, user_id: socket.assigns.user_id}
      )
    end

    socket =
      socket
      |> assign(:selected_component, component)
      |> assign(:component_code, code)
      |> assign(:error_message, nil)
      |> run_if_auto_run()

    {:noreply, socket}
  end

  def handle_event("select_framework", %{"framework" => framework}, socket) do
    code = CodeExamples.get_code_for_framework(socket.assigns.selected_component, framework)

    socket =
      socket
      |> assign(:selected_framework, framework)
      |> assign(:component_code, code)
      |> run_if_auto_run()

    {:noreply, socket}
  end

  def handle_event("search_components", %{"query" => query}, socket) do
    filtered = Helpers.filter_components(socket.assigns.all_components, query)

    # Use stream_reset for efficient DOM updates when filtering
    socket =
      socket
      |> assign(:search_query, query)
      |> stream(:components, filtered, reset: true)

    {:noreply, socket}
  end

  # ===========================================================================
  # Event Handlers - Code Execution
  # ===========================================================================

  def handle_event("update_code", %{"code" => code}, socket) do
    socket =
      socket
      |> assign(:component_code, code)
      |> assign(:error_message, nil)
      |> run_if_auto_run()

    {:noreply, socket}
  end

  def handle_event("run_component", _params, socket) do
    socket = assign(socket, :is_running, true)

    case CodeExecutor.execute(socket.assigns.component_code, socket.assigns.selected_component) do
      {:ok, output} ->
        {:noreply,
         socket
         |> assign(:preview_output, output)
         |> assign(:error_message, nil)
         |> assign(:is_running, false)}

      {:error, error} ->
        {:noreply,
         socket
         |> assign(:error_message, error)
         |> assign(:preview_output, "")
         |> assign(:is_running, false)}
    end
  end

  def handle_event("toggle_auto_run", _params, socket) do
    {:noreply, assign(socket, :auto_run, !socket.assigns.auto_run)}
  end

  # ===========================================================================
  # Event Handlers - UI State
  # ===========================================================================

  def handle_event("toggle_shortcuts", _params, socket) do
    {:noreply, assign(socket, :show_shortcuts, !socket.assigns.show_shortcuts)}
  end

  def handle_event("toggle_view_mode", _params, socket) do
    new_mode = if socket.assigns.view_mode == :demo, do: :edit, else: :demo
    {:noreply, assign(socket, :view_mode, new_mode)}
  end

  def handle_event("set_view_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, String.to_existing_atom(mode))}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, !socket.assigns.sidebar_collapsed)}
  end

  def handle_event("select_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :terminal_theme, String.to_existing_atom(theme))}
  end

  # ===========================================================================
  # Event Handlers - Demo Interactions
  # ===========================================================================

  def handle_event("demo_button_click", _params, socket) do
    demo_state = socket.assigns.demo_state
    new_demo_state = %{demo_state | button_clicks: demo_state.button_clicks + 1}

    socket = assign(socket, :demo_state, new_demo_state)
    broadcast_demo_state_if_enabled(socket, new_demo_state)

    {:noreply, socket}
  end

  def handle_event("demo_input_change", params, socket) do
    demo_state = socket.assigns.demo_state

    new_value =
      case params do
        %{"value" => v} when is_binary(v) -> v
        %{"target" => %{"value" => v}} -> v
        _ -> demo_state.input_value
      end

    new_demo_state = %{demo_state | input_value: new_value}
    socket = assign(socket, :demo_state, new_demo_state)
    broadcast_demo_state_if_enabled(socket, new_demo_state)

    {:noreply, socket}
  end

  def handle_event("demo_progress_change", %{"value" => value}, socket) do
    progress = String.to_integer(value)
    demo_state = socket.assigns.demo_state
    new_demo_state = %{demo_state | progress_value: progress}

    socket = assign(socket, :demo_state, new_demo_state)
    broadcast_demo_state_if_enabled(socket, new_demo_state)

    {:noreply, socket}
  end

  def handle_event("demo_checkbox_toggle", _params, socket) do
    demo_state = socket.assigns.demo_state
    new_demo_state = %{demo_state | checkbox_checked: !demo_state.checkbox_checked}

    socket = assign(socket, :demo_state, new_demo_state)
    broadcast_demo_state_if_enabled(socket, new_demo_state)

    {:noreply, socket}
  end

  def handle_event("demo_menu_select", %{"item" => item}, socket) do
    demo_state = socket.assigns.demo_state
    new_demo_state = %{demo_state | selected_menu_item: item}

    socket = assign(socket, :demo_state, new_demo_state)
    broadcast_demo_state_if_enabled(socket, new_demo_state)

    {:noreply, socket}
  end

  def handle_event("demo_modal_toggle", _params, socket) do
    demo_state = socket.assigns.demo_state
    new_demo_state = %{demo_state | modal_open: !demo_state.modal_open}

    socket = assign(socket, :demo_state, new_demo_state)
    broadcast_demo_state_if_enabled(socket, new_demo_state)

    {:noreply, socket}
  end

  def handle_event("demo_table_sort", %{"column" => column}, socket) do
    demo_state = socket.assigns.demo_state

    {new_column, new_direction} =
      if demo_state.table_sort_column == column do
        {column, if(demo_state.table_sort_direction == :asc, do: :desc, else: :asc)}
      else
        {column, :asc}
      end

    new_demo_state = %{
      demo_state
      | table_sort_column: new_column,
        table_sort_direction: new_direction
    }

    socket = assign(socket, :demo_state, new_demo_state)
    broadcast_demo_state_if_enabled(socket, new_demo_state)

    {:noreply, socket}
  end

  def handle_event("demo_reset", _params, socket) do
    new_demo_state = Helpers.initial_demo_state()
    socket = assign(socket, :demo_state, new_demo_state)
    broadcast_demo_state_if_enabled(socket, new_demo_state)

    {:noreply, socket}
  end

  # ===========================================================================
  # Event Handlers - Multi-User Features
  # ===========================================================================

  def handle_event("toggle_users_panel", _params, socket) do
    {:noreply, assign(socket, :show_users_panel, !socket.assigns.show_users_panel)}
  end

  def handle_event("toggle_sync", _params, socket) do
    {:noreply, assign(socket, :sync_enabled, !socket.assigns.sync_enabled)}
  end

  # ===========================================================================
  # Handle Info - Presence & PubSub
  # ===========================================================================

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    # Update online users list when presence changes
    online_users = PlaygroundPresence.list_users()
    {:noreply, assign(socket, :online_users, online_users)}
  end

  @impl true
  def handle_info({:playground_event, :component_selected, %{component: component_name, user_id: from_user}}, socket) do
    # Another user selected a component - update if sync is enabled
    if socket.assigns.sync_enabled and from_user != socket.assigns.user_id do
      component = Enum.find(socket.assigns.all_components, &(&1.name == component_name))

      if component do
        code = CodeExamples.get_code(component)

        socket =
          socket
          |> assign(:selected_component, component)
          |> assign(:component_code, code)
          |> run_if_auto_run()

        {:noreply, socket}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:playground_event, :demo_state_changed, %{state: new_state, user_id: from_user}}, socket) do
    # Another user changed demo state - update if sync is enabled
    if socket.assigns.sync_enabled and from_user != socket.assigns.user_id do
      {:noreply, assign(socket, :demo_state, new_state)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # ===========================================================================
  # Render
  # ===========================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="playground-container h-screen flex flex-col bg-gray-50">
      <!-- Hero Header -->
      <div class="hero-section">
        <h1 class="hero-title">Raxol Component Playground</h1>
        <p class="hero-subtitle">Build terminal UIs with any framework - React, LiveView, or Raw</p>
      </div>

      <!-- Main Playground Area -->
      <div class="flex-1 flex overflow-hidden">
        <!-- Component Sidebar -->
        <%= render_sidebar(assigns) %>

        <!-- Main Content -->
        <div class="main-content flex-1 flex flex-col bg-white">
          <!-- Toolbar -->
          <%= render_toolbar(assigns) %>

          <!-- Content Area -->
          <div class="content flex-1 flex overflow-hidden">
            <%= if @view_mode == :demo do %>
              <%= render_demo_mode(assigns) %>
            <% else %>
              <%= render_edit_mode(assigns) %>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Keyboard Shortcuts Overlay -->
      <%= if @show_shortcuts do %>
        <%= render_shortcuts_overlay(assigns) %>
      <% end %>

      <!-- Online Users Panel -->
      <%= if @show_users_panel do %>
        <%= render_users_panel(assigns) %>
      <% end %>
    </div>
    """
  end

  # ===========================================================================
  # Render Helpers
  # ===========================================================================

  defp render_sidebar(assigns) do
    ~H"""
    <div class={"sidebar bg-white border-r overflow-y-auto shadow-lg transition-all duration-200 #{if @sidebar_collapsed, do: "w-16", else: "w-80"}"}>
      <div class="p-4">
        <!-- Sidebar Header with Collapse Button -->
        <div class="flex items-center justify-between mb-4">
          <%= if not @sidebar_collapsed do %>
            <h2 class="text-xl font-bold text-gray-800">Components</h2>
          <% end %>
          <button
            phx-click="toggle_sidebar"
            class="p-2 rounded hover:bg-gray-100 text-gray-600"
            title={if @sidebar_collapsed, do: "Expand sidebar", else: "Collapse sidebar"}
          >
            <%= if @sidebar_collapsed do %>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 5l7 7-7 7M5 5l7 7-7 7" />
              </svg>
            <% else %>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 19l-7-7 7-7m8 14l-7-7 7-7" />
              </svg>
            <% end %>
          </button>
        </div>

        <%= if not @sidebar_collapsed do %>
          <!-- Search -->
          <div class="mb-4">
            <input
              type="text"
              placeholder="Search components..."
              value={@search_query}
              phx-keyup="search_components"
              phx-debounce="300"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>

          <!-- Component List using Streams for efficient updates -->
          <div id="component-list" phx-update="stream" class="component-stream-container">
            <%= for {dom_id, component} <- @streams.components do %>
              <div id={dom_id} class="component-category-item">
                <div
                  class={"component-item p-3 rounded-lg cursor-pointer border mb-2 #{if @selected_component && @selected_component.name == component.name, do: "bg-blue-50 border-blue-300 shadow-sm", else: "bg-gray-50 hover:bg-gray-100 border-transparent"}"}
                  phx-click="select_component"
                  phx-value-component={component.name}
                >
                  <div class="flex items-center gap-2 mb-1">
                    <span class="text-xs text-gray-500 uppercase font-semibold"><%= component.category %></span>
                  </div>
                  <div class="font-medium text-sm text-gray-900"><%= component.name %></div>
                  <div class="text-xs text-gray-600 mt-1"><%= component.description %></div>
                  <div class="flex flex-wrap gap-1 mt-2">
                    <%= for tag <- component.tags do %>
                      <span class="px-2 py-1 text-xs bg-white border border-gray-200 rounded"><%= tag %></span>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <!-- Collapsed: Show only component icons/initials (also using streams) -->
          <div id="component-list-collapsed" phx-update="stream" class="space-y-2">
            <%= for {dom_id, component} <- @streams.components do %>
              <div
                id={"collapsed-#{dom_id}"}
                class={"p-2 rounded-lg cursor-pointer text-center #{if @selected_component && @selected_component.name == component.name, do: "bg-blue-50 border border-blue-300", else: "hover:bg-gray-100"}"}
                phx-click="select_component"
                phx-value-component={component.name}
                title={component.name}
              >
                <div class="font-bold text-sm text-gray-700"><%= String.first(component.name) %></div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_toolbar(assigns) do
    ~H"""
    <div class="border-b bg-gray-50 p-4">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-4">
          <div>
            <%= if @selected_component do %>
              <h2 class="text-lg font-bold text-gray-900"><%= @selected_component.name %></h2>
              <p class="text-sm text-gray-600"><%= @selected_component.description %></p>
            <% end %>
          </div>

          <!-- View Mode Toggle -->
          <div class="flex bg-gray-200 rounded-lg p-1">
            <button
              phx-click="set_view_mode"
              phx-value-mode="demo"
              class={"px-4 py-1.5 rounded-md text-sm font-medium transition-colors #{if @view_mode == :demo, do: "bg-white shadow text-blue-600", else: "text-gray-600 hover:text-gray-800"}"}
            >
              Demo
            </button>
            <button
              phx-click="set_view_mode"
              phx-value-mode="edit"
              class={"px-4 py-1.5 rounded-md text-sm font-medium transition-colors #{if @view_mode == :edit, do: "bg-white shadow text-blue-600", else: "text-gray-600 hover:text-gray-800"}"}
            >
              Edit Code
            </button>
          </div>

          <!-- Framework Selector (only in edit mode) -->
          <%= if @view_mode == :edit do %>
            <div class="framework-tabs">
              <%= for framework <- ["universal", "react", "liveview", "raw"] do %>
                <div
                  class={"framework-tab #{if @selected_framework == framework, do: "active", else: ""}"}
                  phx-click="select_framework"
                  phx-value-framework={framework}
                >
                  <%= String.capitalize(framework) %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="flex items-center gap-3">
          <%= if @view_mode == :demo do %>
            <button
              phx-click="demo_reset"
              class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-100 text-sm"
            >
              Reset
            </button>
          <% else %>
            <label class="auto-run-indicator flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={@auto_run}
                phx-click="toggle_auto_run"
                class="rounded text-blue-600 focus:ring-blue-500"
              />
              <span class="text-sm">Auto-run</span>
              <%= if @auto_run do %>
                <div class="auto-run-dot"></div>
              <% end %>
            </label>

            <button
              phx-click="run_component"
              disabled={@is_running}
              class="btn-run px-6 py-2 text-white rounded-lg hover:bg-blue-700 font-medium shadow-md"
            >
              <%= if @is_running do %>
                <span class="flex items-center gap-2">
                  <div class="loading-spinner"></div>
                  Running...
                </span>
              <% else %>
                Run (Cmd+Enter)
              <% end %>
            </button>
          <% end %>

          <!-- Online Users Button -->
          <button
            phx-click="toggle_users_panel"
            class={"flex items-center gap-2 px-3 py-2 border rounded-lg #{if @show_users_panel, do: "bg-blue-50 border-blue-300 text-blue-600", else: "border-gray-300 hover:bg-gray-100"}"}
            title="Online users"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
            </svg>
            <span class="text-sm font-medium"><%= length(@online_users) %></span>
            <%= if length(@online_users) > 1 do %>
              <span class="w-2 h-2 rounded-full bg-green-400 animate-pulse"></span>
            <% end %>
          </button>

          <button
            phx-click="toggle_shortcuts"
            class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-100"
          >
            ?
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp render_demo_mode(assigns) do
    ~H"""
    <div class="demo-area flex-1 flex flex-col lg:flex-row">
      <!-- Interactive Component Preview -->
      <div class="interactive-preview flex-1 flex flex-col border-r">
        <div class="p-3 bg-gray-50 border-b">
          <h3 class="font-medium text-gray-800">Interactive Component</h3>
        </div>
        <div class="flex-1 p-6 overflow-auto bg-white">
          <%= DemoComponents.render_interactive_demo(assigns) %>
        </div>
      </div>

      <!-- Terminal View -->
      <div class="terminal-preview flex-1 flex flex-col">
        <div class="p-3 bg-gray-800 text-gray-200 border-b border-gray-700 flex justify-between items-center">
          <h3 class="font-medium">Terminal View</h3>
          <form phx-change="select_theme">
            <select
              name="theme"
              class="bg-gray-700 text-gray-200 text-sm rounded px-2 py-1 border border-gray-600 focus:outline-none focus:ring-1 focus:ring-blue-500"
            >
              <option value="dracula" selected={@terminal_theme == :dracula}>Dracula</option>
              <option value="nord" selected={@terminal_theme == :nord}>Nord</option>
              <option value="monokai" selected={@terminal_theme == :monokai}>Monokai</option>
              <option value="solarized_dark" selected={@terminal_theme == :solarized_dark}>Solarized Dark</option>
              <option value="solarized_light" selected={@terminal_theme == :solarized_light}>Solarized Light</option>
              <option value="synthwave84" selected={@terminal_theme == :synthwave84}>Synthwave '84</option>
              <option value="gruvbox_dark" selected={@terminal_theme == :gruvbox_dark}>Gruvbox Dark</option>
              <option value="one_dark" selected={@terminal_theme == :one_dark}>One Dark</option>
              <option value="tokyo_night" selected={@terminal_theme == :tokyo_night}>Tokyo Night</option>
              <option value="catppuccin" selected={@terminal_theme == :catppuccin}>Catppuccin</option>
            </select>
          </form>
        </div>
        <div class={"flex-1 overflow-auto p-4 #{theme_bg(@terminal_theme)}"}>
          <%= TerminalView.render_terminal_demo(assigns) %>
        </div>
      </div>
    </div>
    """
  end

  defp theme_bg(:dracula), do: "bg-[#282a36]"
  defp theme_bg(:nord), do: "bg-[#2e3440]"
  defp theme_bg(:monokai), do: "bg-[#272822]"
  defp theme_bg(:solarized_dark), do: "bg-[#002b36]"
  defp theme_bg(:solarized_light), do: "bg-[#fdf6e3]"
  defp theme_bg(:synthwave84), do: "bg-[#241b2f]"
  defp theme_bg(:gruvbox_dark), do: "bg-[#282828]"
  defp theme_bg(:one_dark), do: "bg-[#282c34]"
  defp theme_bg(:tokyo_night), do: "bg-[#1a1b26]"
  defp theme_bg(:catppuccin), do: "bg-[#1e1e2e]"
  defp theme_bg(_), do: "bg-gray-900"

  defp render_edit_mode(assigns) do
    ~H"""
    <!-- Code Editor -->
    <div class="editor-panel w-1/2 flex flex-col border-r">
      <div class="editor-header p-3 text-white">
        <h3 class="font-medium">Component Code</h3>
      </div>

      <div class="editor flex-1 relative overflow-hidden">
        <textarea
          id="code-editor"
          phx-hook="CodeEditor"
          name="code"
          class="w-full h-full p-4 font-mono text-sm resize-none border-none outline-none"
          phx-blur="update_code"
        ><%= @component_code %></textarea>
      </div>

      <%= if @error_message do %>
        <div class="error-panel p-3 text-red-300 text-sm">
          <div class="font-bold mb-1">Error:</div>
          <div class="font-mono"><%= @error_message %></div>
        </div>
      <% end %>
    </div>

    <!-- Preview Panel -->
    <div class="preview-panel w-1/2 flex flex-col">
      <div class="preview-header p-3 bg-gray-50 border-b">
        <h3 class="font-medium text-gray-800">Live Preview</h3>
      </div>

      <div class="preview flex-1 overflow-auto relative">
        <div class="terminal-output p-4 whitespace-pre-wrap"><%= @preview_output %></div>
      </div>

      <%= if @selected_component do %>
        <div class="component-info p-4 bg-gray-50 border-t">
          <div class="text-sm space-y-2">
            <div class="flex items-center gap-2">
              <span class="font-medium text-gray-700">Framework:</span>
              <span class="px-2 py-1 bg-blue-100 text-blue-800 rounded text-xs font-medium">
                <%= @selected_component.framework %>
              </span>
            </div>
            <div class="flex items-center gap-2">
              <span class="font-medium text-gray-700">Complexity:</span>
              <span class={"px-2 py-1 rounded text-xs font-medium #{Helpers.complexity_class(@selected_component.complexity)}"}>
                <%= @selected_component.complexity %>
              </span>
            </div>
            <div>
              <span class="font-medium text-gray-700">API:</span>
              <a href="#" class="text-blue-600 hover:underline ml-1">View Docs -></a>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_shortcuts_overlay(assigns) do
    ~H"""
    <div class="shortcuts-hint">
      <div class="text-white font-bold mb-2">Keyboard Shortcuts</div>
      <div class="space-y-1">
        <div class="flex items-center justify-between gap-4">
          <span>Run component</span>
          <div class="shortcut-combo">
            <span class="shortcut-key">Cmd</span>
            <span>+</span>
            <span class="shortcut-key">Enter</span>
          </div>
        </div>
        <div class="flex items-center justify-between gap-4">
          <span>Search</span>
          <div class="shortcut-combo">
            <span class="shortcut-key">Cmd</span>
            <span>+</span>
            <span class="shortcut-key">K</span>
          </div>
        </div>
        <div class="flex items-center justify-between gap-4">
          <span>Toggle shortcuts</span>
          <div class="shortcut-combo">
            <span class="shortcut-key">?</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_users_panel(assigns) do
    ~H"""
    <div class="fixed right-4 top-20 w-72 bg-white rounded-lg shadow-xl border border-gray-200 z-50">
      <div class="p-4 border-b border-gray-200 flex justify-between items-center">
        <h3 class="font-semibold text-gray-800">Online Users (<%= length(@online_users) %>)</h3>
        <button
          phx-click="toggle_users_panel"
          class="text-gray-400 hover:text-gray-600"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <div class="p-4 border-b border-gray-100">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={@sync_enabled}
            phx-click="toggle_sync"
            class="rounded text-blue-600 focus:ring-blue-500"
          />
          <span class="text-sm text-gray-700">Sync with others</span>
        </label>
        <p class="text-xs text-gray-500 mt-1">
          When enabled, component selections will sync across sessions
        </p>
      </div>

      <div class="max-h-64 overflow-y-auto">
        <%= if length(@online_users) == 0 do %>
          <div class="p-4 text-center text-gray-500 text-sm">
            No other users online
          </div>
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
                  <div class="flex items-center gap-2">
                    <span class={"text-sm font-medium #{if user.user_id == @user_id, do: "text-blue-600", else: "text-gray-800"}"}>
                      <%= user.name %>
                      <%= if user.user_id == @user_id do %>
                        <span class="text-xs text-gray-400">(you)</span>
                      <% end %>
                    </span>
                  </div>
                  <%= if user.current_component do %>
                    <div class="text-xs text-gray-500 truncate">
                      Viewing: <%= user.current_component %>
                    </div>
                  <% end %>
                </div>
                <div class="w-2 h-2 rounded-full bg-green-400" title="Online"></div>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>
    </div>
    """
  end

  # ===========================================================================
  # Private Helpers
  # ===========================================================================

  defp broadcast_demo_state_if_enabled(socket, new_state) do
    if socket.assigns.sync_enabled do
      PlaygroundPresence.broadcast_event_from(
        self(),
        :demo_state_changed,
        %{state: new_state, user_id: socket.assigns.user_id}
      )
    end
  end

  defp run_if_auto_run(socket) do
    if socket.assigns.auto_run do
      case CodeExecutor.execute(socket.assigns.component_code, socket.assigns.selected_component) do
        {:ok, output} ->
          socket
          |> assign(:preview_output, output)
          |> assign(:error_message, nil)

        {:error, error} ->
          socket
          |> assign(:error_message, error)
          |> assign(:preview_output, "")
      end
    else
      socket
    end
  end
end
