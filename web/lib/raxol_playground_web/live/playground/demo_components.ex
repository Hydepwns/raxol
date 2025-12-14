defmodule RaxolPlaygroundWeb.Playground.DemoComponents do
  @moduledoc """
  Interactive demo components for the Raxol playground.
  These render the visual/interactive demos for each component type.
  """

  use Phoenix.Component
  import Raxol.HEEx.Components

  @doc """
  Renders the appropriate interactive demo based on the selected component.
  """
  def render_interactive_demo(assigns) do
    case assigns.selected_component && assigns.selected_component.name do
      "Button" -> button_demo(assigns)
      "TextInput" -> text_input_demo(assigns)
      "Progress" -> progress_demo(assigns)
      "Table" -> table_demo(assigns)
      "Modal" -> modal_demo(assigns)
      "Menu" -> menu_demo(assigns)
      _ -> generic_demo(assigns)
    end
  end

  def button_demo(assigns) do
    ~H"""
    <div class="demo-container space-y-6">
      <!-- Primary Button -->
      <div class="demo-section">
        <h4 class="text-sm font-medium text-gray-500 mb-3">Primary Button</h4>
        <.terminal_box border="single" padding={2}>
          <.terminal_row gap={2}>
            <.terminal_button phx-click="demo_button_click" role="primary">
              Click Me
            </.terminal_button>
            <.terminal_text>Clicked: <%= @demo_state.button_clicks %> times</.terminal_text>
          </.terminal_row>
        </.terminal_box>
      </div>

      <!-- Button Variants -->
      <div class="demo-section">
        <h4 class="text-sm font-medium text-gray-500 mb-3">Button Variants</h4>
        <div class="flex gap-3 flex-wrap">
          <button
            phx-click="demo_button_click"
            class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
          >
            Primary
          </button>
          <button
            phx-click="demo_button_click"
            class="px-4 py-2 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300 transition-colors"
          >
            Secondary
          </button>
          <button
            phx-click="demo_button_click"
            class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors"
          >
            Success
          </button>
          <button
            phx-click="demo_button_click"
            class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors"
          >
            Danger
          </button>
        </div>
      </div>

      <!-- Click Counter Display -->
      <div class="demo-section bg-gray-50 p-4 rounded-lg">
        <div class="text-center">
          <div class="text-4xl font-bold text-blue-600"><%= @demo_state.button_clicks %></div>
          <div class="text-sm text-gray-500 mt-1">Total Clicks</div>
        </div>
      </div>
    </div>
    """
  end

  def text_input_demo(assigns) do
    ~H"""
    <div class="demo-container space-y-6">
      <!-- Text Input -->
      <div class="demo-section">
        <h4 class="text-sm font-medium text-gray-500 mb-3">Text Input</h4>
        <.terminal_box border="single" padding={2}>
          <form phx-change="demo_input_change" class="w-full">
            <.terminal_input
              name="value"
              value={@demo_state.input_value}
              placeholder="Type something..."
            />
          </form>
        </.terminal_box>
      </div>

      <!-- Live Value Display -->
      <div class="demo-section">
        <h4 class="text-sm font-medium text-gray-500 mb-3">Live Value</h4>
        <div class="bg-gray-50 p-4 rounded-lg font-mono text-sm">
          <div class="text-gray-600">Current value:</div>
          <div class="text-blue-600 mt-1">
            "<%= @demo_state.input_value %>"
          </div>
          <div class="text-gray-400 text-xs mt-2">
            Length: <%= String.length(@demo_state.input_value) %> characters
          </div>
        </div>
      </div>

      <!-- Styled Input with Label -->
      <div class="demo-section">
        <h4 class="text-sm font-medium text-gray-500 mb-3">Styled Input</h4>
        <form phx-change="demo_input_change" class="space-y-2">
          <label class="block text-sm font-medium text-gray-700">Username</label>
          <input
            type="text"
            name="value"
            value={@demo_state.input_value}
            class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="Enter username..."
          />
        </form>
      </div>
    </div>
    """
  end

  def progress_demo(assigns) do
    ~H"""
    <div class="demo-container space-y-6">
      <!-- Progress Bar with Slider -->
      <div class="demo-section">
        <h4 class="text-sm font-medium text-gray-500 mb-3">Progress Bar</h4>
        <.terminal_box border="single" padding={2}>
          <.terminal_progress value={@demo_state.progress_value} color="green" width={30} />
        </.terminal_box>
      </div>

      <!-- Slider Control -->
      <div class="demo-section">
        <h4 class="text-sm font-medium text-gray-500 mb-3">Adjust Progress</h4>
        <form phx-change="demo_progress_change" class="flex items-center gap-4">
          <input
            type="range"
            name="value"
            min="0"
            max="100"
            value={@demo_state.progress_value}
            class="flex-1"
          />
          <span class="text-lg font-bold text-blue-600 w-16 text-right">
            <%= @demo_state.progress_value %>%
          </span>
        </form>
      </div>

      <!-- Visual Progress Bars -->
      <div class="demo-section">
        <h4 class="text-sm font-medium text-gray-500 mb-3">Visual Styles</h4>
        <div class="space-y-3">
          <!-- Default -->
          <div>
            <div class="text-xs text-gray-500 mb-1">Default</div>
            <div class="w-full bg-gray-200 rounded-full h-4 overflow-hidden">
              <div
                class="bg-blue-600 h-full transition-all duration-300"
                style={"width: #{@demo_state.progress_value}%"}
              />
            </div>
          </div>
          <!-- Success -->
          <div>
            <div class="text-xs text-gray-500 mb-1">Success</div>
            <div class="w-full bg-gray-200 rounded-full h-4 overflow-hidden">
              <div
                class="bg-green-500 h-full transition-all duration-300"
                style={"width: #{@demo_state.progress_value}%"}
              />
            </div>
          </div>
          <!-- Warning -->
          <div>
            <div class="text-xs text-gray-500 mb-1">Warning</div>
            <div class="w-full bg-gray-200 rounded-full h-4 overflow-hidden">
              <div
                class="bg-yellow-500 h-full transition-all duration-300"
                style={"width: #{@demo_state.progress_value}%"}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def table_demo(assigns) do
    # Sample data
    data = [
      %{id: 1, name: "Alice Johnson", email: "alice@example.com", role: "Admin"},
      %{id: 2, name: "Bob Smith", email: "bob@example.com", role: "User"},
      %{id: 3, name: "Carol White", email: "carol@example.com", role: "Editor"},
      %{id: 4, name: "David Brown", email: "david@example.com", role: "User"}
    ]

    sorted_data =
      case assigns.demo_state.table_sort_column do
        nil ->
          data

        column ->
          col_atom = String.to_existing_atom(column)
          sorted = Enum.sort_by(data, &Map.get(&1, col_atom))

          case assigns.demo_state.table_sort_direction do
            :desc -> Enum.reverse(sorted)
            :asc -> sorted
          end
      end

    assigns = assign(assigns, :table_data, sorted_data)

    ~H"""
    <div class="demo-container space-y-6">
      <!-- Table -->
      <div class="demo-section">
        <h4 class="text-sm font-medium text-gray-500 mb-3">Sortable Table</h4>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th
                  phx-click="demo_table_sort"
                  phx-value-column="name"
                  class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                >
                  Name <%= sort_indicator(@demo_state, "name") %>
                </th>
                <th
                  phx-click="demo_table_sort"
                  phx-value-column="email"
                  class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                >
                  Email <%= sort_indicator(@demo_state, "email") %>
                </th>
                <th
                  phx-click="demo_table_sort"
                  phx-value-column="role"
                  class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                >
                  Role <%= sort_indicator(@demo_state, "role") %>
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for row <- @table_data do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">
                    <%= row.name %>
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-500">
                    <%= row.email %>
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap">
                    <span class={"px-2 py-1 text-xs rounded-full #{role_class(row.role)}"}>
                      <%= row.role %>
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  def modal_demo(assigns) do
    ~H"""
    <div class="demo-container space-y-6">
      <!-- Modal Trigger -->
      <div class="demo-section">
        <h4 class="text-sm font-medium text-gray-500 mb-3">Modal Dialog</h4>
        <button
          phx-click="demo_modal_toggle"
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
        >
          Open Modal
        </button>
      </div>

      <!-- Modal State -->
      <div class="demo-section bg-gray-50 p-4 rounded-lg">
        <div class="text-sm text-gray-600">
          Modal is: <span class={"font-bold #{if @demo_state.modal_open, do: "text-green-600", else: "text-gray-400"}"}>
            <%= if @demo_state.modal_open, do: "Open", else: "Closed" %>
          </span>
        </div>
      </div>

      <!-- Modal (when open) -->
      <%= if @demo_state.modal_open do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center">
          <!-- Backdrop -->
          <div
            phx-click="demo_modal_toggle"
            class="absolute inset-0 bg-black bg-opacity-50"
          />
          <!-- Modal Content -->
          <div class="relative bg-white rounded-lg shadow-xl max-w-md w-full mx-4 p-6">
            <h3 class="text-lg font-bold text-gray-900 mb-2">Modal Title</h3>
            <p class="text-gray-600 mb-4">
              This is a modal dialog. Click the backdrop or the button below to close it.
            </p>
            <div class="flex justify-end gap-2">
              <button
                phx-click="demo_modal_toggle"
                class="px-4 py-2 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300"
              >
                Cancel
              </button>
              <button
                phx-click="demo_modal_toggle"
                class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
              >
                Confirm
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def menu_demo(assigns) do
    menu_items = ["File", "Edit", "View", "Help"]
    assigns = assign(assigns, :menu_items, menu_items)

    ~H"""
    <div class="demo-container space-y-6">
      <!-- Menu -->
      <div class="demo-section">
        <h4 class="text-sm font-medium text-gray-500 mb-3">Menu Navigation</h4>
        <.terminal_box border="single" padding={1}>
          <div class="flex gap-1">
            <%= for item <- @menu_items do %>
              <div
                phx-click="demo_menu_select"
                phx-value-item={item}
                class={"px-3 py-1 cursor-pointer rounded #{if @demo_state.selected_menu_item == item, do: "bg-blue-600 text-white", else: "hover:bg-gray-100"}"}
              >
                <%= item %>
              </div>
            <% end %>
          </div>
        </.terminal_box>
      </div>

      <!-- Selection Display -->
      <div class="demo-section bg-gray-50 p-4 rounded-lg">
        <div class="text-sm text-gray-600">
          Selected: <span class="font-bold text-blue-600">
            <%= @demo_state.selected_menu_item || "None" %>
          </span>
        </div>
      </div>

      <!-- Vertical Menu -->
      <div class="demo-section">
        <h4 class="text-sm font-medium text-gray-500 mb-3">Vertical Menu</h4>
        <div class="bg-white border rounded-lg overflow-hidden w-48">
          <%= for item <- @menu_items do %>
            <div
              phx-click="demo_menu_select"
              phx-value-item={item}
              class={"px-4 py-2 cursor-pointer border-b last:border-b-0 #{if @demo_state.selected_menu_item == item, do: "bg-blue-50 text-blue-600 border-l-2 border-l-blue-600", else: "hover:bg-gray-50"}"}
            >
              <%= item %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def generic_demo(assigns) do
    ~H"""
    <div class="demo-container">
      <div class="text-center text-gray-500 py-8">
        <p>Select a component from the sidebar to see an interactive demo.</p>
      </div>
    </div>
    """
  end

  # Helper for sort indicator
  def sort_indicator(demo_state, column) do
    case demo_state.table_sort_column do
      ^column ->
        if demo_state.table_sort_direction == :asc, do: " ^", else: " v"

      _ ->
        ""
    end
  end

  # Helper for role badge colors
  def role_class("Admin"), do: "bg-purple-100 text-purple-800"
  def role_class("Editor"), do: "bg-blue-100 text-blue-800"
  def role_class("User"), do: "bg-gray-100 text-gray-800"
  def role_class(_), do: "bg-gray-100 text-gray-800"
end
