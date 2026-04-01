defmodule RaxolPlaygroundWeb.GalleryLive do
  @moduledoc """
  Component gallery backed by the shared Raxol.Playground.Catalog.
  Displays all widgets with filtering by category and complexity.
  """

  use RaxolPlaygroundWeb, :live_view

  alias Raxol.Playground.Catalog
  alias RaxolPlaygroundWeb.Playground.Helpers

  @impl true
  def mount(_params, _session, socket) do
    components = Catalog.list_components()

    socket =
      socket
      |> assign(:components, components)
      |> assign(:total_count, length(components))
      |> assign(:categories, Catalog.list_categories())
      |> assign(:active_category, nil)
      |> assign(:search_query, "")
      |> assign(:view_mode, "grid")
      |> assign(:complexity_filter, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_category", %{"category" => "all"}, socket) do
    {:noreply, refilter(assign(socket, :active_category, nil))}
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    {:noreply,
     refilter(
       assign(socket, :active_category, String.to_existing_atom(category))
     )}
  rescue
    ArgumentError -> {:noreply, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, refilter(assign(socket, :search_query, query))}
  end

  def handle_event("toggle_view", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, mode)}
  end

  def handle_event("filter_complexity", %{"level" => "all"}, socket) do
    {:noreply, refilter(assign(socket, :complexity_filter, nil))}
  end

  def handle_event("filter_complexity", %{"level" => level}, socket) do
    {:noreply,
     refilter(
       assign(socket, :complexity_filter, String.to_existing_atom(level))
     )}
  rescue
    ArgumentError -> {:noreply, socket}
  end

  defp refilter(socket) do
    a = socket.assigns
    search = if a.search_query == "", do: nil, else: a.search_query

    components =
      Catalog.filter(
        category: a.active_category,
        complexity: a.complexity_filter,
        search: search
      )

    assign(socket, :components, components)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="gallery-container min-h-screen bg-gray-950 text-gray-100">
      <!-- Header -->
      <div class="bg-gray-900 border-b border-gray-800">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-100">
                <a href="/" class="hover:text-blue-400 transition-colors">Raxol</a> Component Gallery
              </h1>
              <p class="mt-2 text-gray-400">
                <%= @total_count %> interactive terminal UI components --
                <a href="/playground" class="text-blue-400 hover:underline">open playground</a>
              </p>
            </div>

            <div class="flex items-center space-x-4">
              <div class="flex bg-gray-800 rounded-lg p-1">
                <button
                  phx-click="toggle_view"
                  phx-value-mode="grid"
                  class={"px-3 py-1 rounded text-sm font-medium #{if @view_mode == "grid", do: "bg-gray-700 shadow text-gray-100", else: "text-gray-400"}"}
                >
                  Grid
                </button>
                <button
                  phx-click="toggle_view"
                  phx-value-mode="list"
                  class={"px-3 py-1 rounded text-sm font-medium #{if @view_mode == "list", do: "bg-gray-700 shadow text-gray-100", else: "text-gray-400"}"}
                >
                  List
                </button>
              </div>

              <form phx-change="search" id="gallery-search">
                <input
                  type="text"
                  name="query"
                  placeholder="Search components..."
                  value={@search_query}
                  phx-debounce="300"
                  class="w-64 px-4 py-2 bg-gray-800 border border-gray-700 text-gray-100 placeholder-gray-500 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </form>
            </div>
          </div>
        </div>
      </div>

      <!-- Filters -->
      <div class="bg-gray-900 border-b border-gray-800">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div class="flex items-center space-x-6">
            <div class="flex items-center space-x-2">
              <span class="text-sm font-medium text-gray-400">Category:</span>
              <div class="flex flex-wrap gap-2">
                <button
                  phx-click="filter_category"
                  phx-value-category="all"
                  class={"px-3 py-1 rounded-full text-sm #{if @active_category == nil, do: "bg-blue-900/50 text-blue-300", else: "bg-gray-800 text-gray-400 hover:bg-gray-700"}"}
                >
                  All
                </button>
                <%= for cat <- @categories do %>
                  <button
                    phx-click="filter_category"
                    phx-value-category={cat}
                    class={"px-3 py-1 rounded-full text-sm #{if @active_category == cat, do: "bg-blue-900/50 text-blue-300", else: "bg-gray-800 text-gray-400 hover:bg-gray-700"}"}
                  >
                    <%= Helpers.category_label(cat) %>
                  </button>
                <% end %>
              </div>
            </div>

            <form phx-change="filter_complexity" id="complexity-filter">
              <div class="flex items-center space-x-2">
                <span class="text-sm font-medium text-gray-400">Complexity:</span>
                <select
                  name="level"
                  class="bg-gray-800 border border-gray-700 text-gray-100 rounded px-3 py-1 text-sm"
                >
                  <option value="all" selected={@complexity_filter == nil}>All Levels</option>
                  <option value="basic" selected={@complexity_filter == :basic}>Basic</option>
                  <option value="intermediate" selected={@complexity_filter == :intermediate}>Intermediate</option>
                  <option value="advanced" selected={@complexity_filter == :advanced}>Advanced</option>
                </select>
              </div>
            </form>
          </div>
        </div>
      </div>

      <!-- SSH Callout -->
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-6">
        <div class="bg-gray-900 border border-gray-800 text-green-400 rounded-lg p-4 font-mono text-sm">
          Try the real terminal experience:
          <span class="text-white ml-2">ssh -p 2222 playground@raxol.io</span>
          <span class="text-gray-500 mx-2">|</span>
          <span class="text-white">mix raxol.playground</span>
        </div>
      </div>

      <!-- Component Grid/List -->
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= if @view_mode == "grid" do %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            <%= for comp <- @components do %>
              <.component_card component={comp} />
            <% end %>
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for comp <- @components do %>
              <.component_list_item component={comp} />
            <% end %>
          </div>
        <% end %>

        <%= if @components == [] do %>
          <div class="text-center py-12 text-gray-500">
            No components match your filters.
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp component_card(assigns) do
    ~H"""
    <div class="bg-gray-900 rounded-lg border border-gray-800 hover:border-gray-700 transition-colors duration-200">
      <div class="p-4">
        <div class="flex items-start justify-between mb-2">
          <h3 class="text-lg font-semibold text-gray-100"><%= @component.name %></h3>
          <.complexity_badge level={@component.complexity} />
        </div>
        <p class="text-gray-400 text-sm mb-3"><%= @component.description %></p>
        <div class="flex flex-wrap gap-1 mb-3">
          <%= for tag <- @component.tags do %>
            <span class="px-2 py-1 text-xs bg-gray-800 text-gray-400 rounded"><%= tag %></span>
          <% end %>
        </div>
        <div class="flex space-x-2">
          <a
            href={"/demos/#{@component.name}"}
            class="flex-1 px-3 py-2 bg-blue-600 text-white text-sm text-center rounded hover:bg-blue-500 transition-colors"
          >
            Try Live
          </a>
          <a
            href={"/playground?component=#{@component.name}"}
            class="px-3 py-2 border border-gray-700 text-gray-300 text-sm rounded hover:border-gray-500 transition-colors"
          >
            Code
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp component_list_item(assigns) do
    ~H"""
    <div class="bg-gray-900 rounded-lg border border-gray-800 p-6 hover:border-gray-700 transition-colors duration-200">
      <div class="flex items-start space-x-6">
        <div class="flex-1 min-w-0">
          <div class="flex items-start justify-between mb-2">
            <h3 class="text-xl font-semibold text-gray-100"><%= @component.name %></h3>
            <.complexity_badge level={@component.complexity} />
          </div>
          <p class="text-gray-400 mb-3"><%= @component.description %></p>
          <div class="flex items-center space-x-4 text-sm text-gray-500 mb-3">
            <span>Category: <%= Helpers.category_label(@component.category) %></span>
          </div>
          <div class="flex flex-wrap gap-1 mb-4">
            <%= for tag <- @component.tags do %>
              <span class="px-2 py-1 text-xs bg-gray-800 text-gray-400 rounded"><%= tag %></span>
            <% end %>
          </div>
          <div class="flex space-x-3">
            <a
              href={"/demos/#{@component.name}"}
              class="px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-500 transition-colors"
            >
              Try Live
            </a>
            <a
              href={"/playground?component=#{@component.name}"}
              class="px-4 py-2 border border-gray-700 text-gray-300 text-sm rounded hover:border-gray-500 transition-colors"
            >
              View Code
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp complexity_badge(assigns) do
    class = Helpers.complexity_class(assigns.level)
    assigns = assign(assigns, :class, class)

    ~H"""
    <span class={"px-2 py-1 text-xs font-medium rounded-full #{@class}"}>
      <%= Helpers.complexity_label(@level) %>
    </span>
    """
  end
end
