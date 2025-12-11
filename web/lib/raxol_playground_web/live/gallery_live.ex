defmodule RaxolPlaygroundWeb.GalleryLive do
  use RaxolPlaygroundWeb, :live_view

  alias RaxolPlaygroundWeb.Live.ComponentHelpers

  @impl true
  def mount(_params, _session, socket) do
    categories = get_component_categories()

    socket =
      socket
      |> assign(:categories, categories)
      |> assign(:active_category, "all")
      |> assign(:search_query, "")
      # grid or list
      |> assign(:view_mode, "grid")
      |> assign(:difficulty_filter, "all")

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :active_category, category)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  def handle_event("toggle_view", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, mode)}
  end

  def handle_event("filter_difficulty", %{"level" => level}, socket) do
    {:noreply, assign(socket, :difficulty_filter, level)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="gallery-container min-h-screen bg-gray-50">
      <!-- Header -->
      <div class="bg-white shadow-sm border-b">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Raxol Component Gallery</h1>
              <p class="mt-2 text-gray-600">Explore interactive terminal UI components</p>
            </div>

            <div class="flex items-center space-x-4">
              <!-- View Toggle -->
              <div class="flex bg-gray-100 rounded-lg p-1">
                <button
                  phx-click="toggle_view"
                  phx-value-mode="grid"
                  class={"px-3 py-1 rounded text-sm font-medium #{if @view_mode == "grid", do: "bg-white shadow text-gray-900", else: "text-gray-500"}"}
                >
                  Grid
                </button>
                <button
                  phx-click="toggle_view"
                  phx-value-mode="list"
                  class={"px-3 py-1 rounded text-sm font-medium #{if @view_mode == "list", do: "bg-white shadow text-gray-900", else: "text-gray-500"}"}
                >
                  List
                </button>
              </div>

              <!-- Search -->
              <div class="relative">
                <input
                  type="text"
                  placeholder="Search components..."
                  value={@search_query}
                  phx-keyup="search"
                  phx-debounce="300"
                  class="w-64 pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
                <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Filters -->
      <div class="bg-white border-b">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div class="flex items-center space-x-6">
            <!-- Category Filter -->
            <div class="flex items-center space-x-2">
              <span class="text-sm font-medium text-gray-700">Category:</span>
              <div class="flex space-x-2">
                <%= for {category, _} <- @categories do %>
                  <button
                    phx-click="filter_category"
                    phx-value-category={category}
                    class={"px-3 py-1 rounded-full text-sm #{if @active_category == category, do: "bg-blue-100 text-blue-800", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
                  >
                    <%= String.capitalize(category) %>
                  </button>
                <% end %>
              </div>
            </div>

            <!-- Difficulty Filter -->
            <div class="flex items-center space-x-2">
              <span class="text-sm font-medium text-gray-700">Difficulty:</span>
              <select
                phx-change="filter_difficulty"
                class="border border-gray-300 rounded px-3 py-1 text-sm"
              >
                <option value="all" selected={@difficulty_filter == "all"}>All Levels</option>
                <option value="basic" selected={@difficulty_filter == "basic"}>Basic</option>
                <option value="intermediate" selected={@difficulty_filter == "intermediate"}>Intermediate</option>
                <option value="advanced" selected={@difficulty_filter == "advanced"}>Advanced</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- Component Grid/List -->
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= if @view_mode == "grid" do %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            <%= for component <- get_filtered_components(@categories, @active_category, @search_query, @difficulty_filter) do %>
              <.component_card component={component} />
            <% end %>
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for component <- get_filtered_components(@categories, @active_category, @search_query, @difficulty_filter) do %>
              <.component_list_item component={component} />
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Component card for grid view
  defp component_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border hover:shadow-md transition-shadow duration-200">
      <!-- Preview -->
      <div class="aspect-video bg-gray-900 rounded-t-lg p-4 flex items-center justify-center">
        <div class="text-green-400 font-mono text-sm">
          <.component_preview component={@component} />
        </div>
      </div>

      <!-- Content -->
      <div class="p-4">
        <div class="flex items-start justify-between mb-2">
          <h3 class="text-lg font-semibold text-gray-900"><%= @component.name %></h3>
          <.difficulty_badge level={@component.complexity} />
        </div>

        <p class="text-gray-600 text-sm mb-3"><%= @component.description %></p>

        <!-- Tags -->
        <div class="flex flex-wrap gap-1 mb-3">
          <%= for tag <- @component.tags do %>
            <span class="px-2 py-1 text-xs bg-gray-100 text-gray-700 rounded"><%= tag %></span>
          <% end %>
        </div>

        <!-- Actions -->
        <div class="flex space-x-2">
          <button class="flex-1 px-3 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 transition-colors">
            Try Live
          </button>
          <button class="px-3 py-2 border border-gray-300 text-gray-700 text-sm rounded hover:bg-gray-50 transition-colors">
            View Code
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Component list item for list view
  defp component_list_item(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border p-6 hover:shadow-md transition-shadow duration-200">
      <div class="flex items-start space-x-6">
        <!-- Preview -->
        <div class="flex-shrink-0 w-32 h-20 bg-gray-900 rounded p-2 flex items-center justify-center">
          <div class="text-green-400 font-mono text-xs">
            <.component_preview component={@component} />
          </div>
        </div>

        <!-- Content -->
        <div class="flex-1 min-w-0">
          <div class="flex items-start justify-between mb-2">
            <h3 class="text-xl font-semibold text-gray-900"><%= @component.name %></h3>
            <.difficulty_badge level={@component.complexity} />
          </div>

          <p class="text-gray-600 mb-3"><%= @component.description %></p>

          <!-- Meta info -->
          <div class="flex items-center space-x-4 text-sm text-gray-500 mb-3">
            <span>Framework: <%= @component.framework %></span>
            <span>Category: <%= @component.category %></span>
          </div>

          <!-- Tags -->
          <div class="flex flex-wrap gap-1 mb-4">
            <%= for tag <- @component.tags do %>
              <span class="px-2 py-1 text-xs bg-gray-100 text-gray-700 rounded"><%= tag %></span>
            <% end %>
          </div>

          <!-- Actions -->
          <div class="flex space-x-3">
            <button class="px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 transition-colors">
              Try Live
            </button>
            <button class="px-4 py-2 border border-gray-300 text-gray-700 text-sm rounded hover:bg-gray-50 transition-colors">
              View Code
            </button>
            <button class="px-4 py-2 border border-gray-300 text-gray-700 text-sm rounded hover:bg-gray-50 transition-colors">
              Documentation
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp difficulty_badge(assigns) do
    class =
      case assigns.level do
        "Basic" -> "bg-green-100 text-green-800"
        "Intermediate" -> "bg-yellow-100 text-yellow-800"
        "Advanced" -> "bg-red-100 text-red-800"
        _ -> "bg-gray-100 text-gray-800"
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <span class={"px-2 py-1 text-xs font-medium rounded-full #{@class}"}>
      <%= @level %>
    </span>
    """
  end

  defp component_preview(assigns) do
    case assigns.component.name do
      "Button" ->
        ~H"[████████] Click Me"

      "TextInput" ->
        ~H"┌─────────────────┐\n│ Enter text...   │\n└─────────────────┘"

      "Table" ->
        ~H"┌─────┬─────┬─────┐\n│ A   │ B   │ C   │\n├─────┼─────┼─────┤\n│ 1   │ 2   │ 3   │\n└─────┴─────┴─────┘"

      "Progress" ->
        ~H"Progress: ████████░░ 80%"

      "Modal" ->
        ~H"┌─ Dialog ──────────┐\n│ Modal content... │\n│ [OK] [Cancel]    │\n└──────────────────┘"

      "Menu" ->
        ~H"File ▼\n├ New\n├ Open\n├ Save\n└ Exit"

      _ ->
        ~H"Preview\nLoading..."
    end
  end

  # Helper functions
  defp get_component_categories do
    [
      {"all", "All Components"},
      {"input", "Input & Forms"},
      {"display", "Data Display"},
      {"feedback", "Feedback & Status"},
      {"navigation", "Navigation"},
      {"overlay", "Overlays & Modals"},
      {"layout", "Layout & Structure"}
    ]
  end

  defp get_filtered_components(
         categories,
         active_category,
         search_query,
         difficulty_filter
       ) do
    # This would typically fetch from your component registry
    # For now, returning the example components
    base_components = [
      %{
        name: "Button",
        description:
          "Interactive button component with various styles and states",
        framework: "Universal",
        complexity: "Basic",
        tags: ["input", "interactive", "basic"],
        category: "input"
      },
      %{
        name: "TextInput",
        description: "Single-line text input with validation and formatting",
        framework: "Universal",
        complexity: "Intermediate",
        tags: ["input", "form", "validation"],
        category: "input"
      },
      %{
        name: "Table",
        description: "Data table with sorting, filtering, and pagination",
        framework: "Universal",
        complexity: "Advanced",
        tags: ["data", "display", "sorting"],
        category: "display"
      },
      %{
        name: "Progress",
        description: "Progress indicator with customizable appearance",
        framework: "Universal",
        complexity: "Basic",
        tags: ["feedback", "loading", "progress"],
        category: "feedback"
      },
      %{
        name: "Modal",
        description: "Modal dialog with backdrop and focus management",
        framework: "React",
        complexity: "Intermediate",
        tags: ["overlay", "dialog", "focus"],
        category: "overlay"
      },
      %{
        name: "Menu",
        description: "Dropdown menu with keyboard navigation",
        framework: "Universal",
        complexity: "Advanced",
        tags: ["navigation", "keyboard", "dropdown"],
        category: "navigation"
      }
    ]

    base_components
    |> filter_by_category(active_category)
    |> filter_by_search(search_query)
    |> filter_by_difficulty(difficulty_filter)
  end

  defp filter_by_category(components, "all"), do: components

  defp filter_by_category(components, category) do
    Enum.filter(components, &(&1.category == category))
  end

  defp filter_by_search(components, query) do
    ComponentHelpers.filter_by_search(components, query)
  end

  defp filter_by_difficulty(components, "all"), do: components

  defp filter_by_difficulty(components, level) do
    target_level = String.capitalize(level)
    Enum.filter(components, &(&1.complexity == target_level))
  end
end
