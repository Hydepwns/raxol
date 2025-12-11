defmodule RaxolPlaygroundWeb.PlaygroundLive do
  use RaxolPlaygroundWeb, :live_view

  alias RaxolPlaygroundWeb.Live.ComponentHelpers

  @impl true
  def mount(_params, _session, socket) do
    components = list_available_components()

    socket =
      socket
      |> assign(:components, components)
      |> assign(:selected_component, List.first(components))
      |> assign(:component_code, "")
      |> assign(:preview_output, "")
      |> assign(:error_message, nil)
      |> assign(:search_query, "")
      |> assign(:filtered_components, components)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_component", %{"component" => component_name}, socket) do
    component =
      Enum.find(socket.assigns.components, &(&1.name == component_name))

    code = get_component_code(component)

    socket =
      socket
      |> assign(:selected_component, component)
      |> assign(:component_code, code)
      |> assign(:error_message, nil)

    {:noreply, socket}
  end

  def handle_event("update_code", %{"code" => code}, socket) do
    socket =
      socket
      |> assign(:component_code, code)
      |> assign(:error_message, nil)

    {:noreply, socket}
  end

  def handle_event("run_component", _params, socket) do
    case execute_component_code(socket.assigns.component_code) do
      {:ok, output} ->
        socket =
          socket
          |> assign(:preview_output, output)
          |> assign(:error_message, nil)

        {:noreply, socket}

      {:error, error} ->
        socket =
          socket
          |> assign(:error_message, error)
          |> assign(:preview_output, "")

        {:noreply, socket}
    end
  end

  def handle_event("search_components", %{"query" => query}, socket) do
    filtered = filter_components(socket.assigns.components, query)

    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:filtered_components, filtered)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="playground-container h-screen flex">
      <!-- Component Sidebar -->
      <div class="sidebar w-80 bg-gray-100 border-r overflow-y-auto">
        <div class="p-4">
          <h2 class="text-xl font-bold mb-4">Components</h2>
          
          <!-- Search -->
          <div class="mb-4">
            <input
              type="text"
              placeholder="Search components..."
              value={@search_query}
              phx-keyup="search_components"
              phx-debounce="300"
              class="w-full px-3 py-2 border rounded-md"
            />
          </div>
          
          <!-- Component List -->
          <div class="space-y-2">
            <%= for component <- @filtered_components do %>
              <div
                class={"component-item p-3 rounded cursor-pointer #{if @selected_component && @selected_component.name == component.name, do: "bg-blue-100 border-blue-300", else: "bg-white hover:bg-gray-50"}"}
                phx-click="select_component"
                phx-value-component={component.name}
              >
                <div class="font-medium text-sm"><%= component.name %></div>
                <div class="text-xs text-gray-600 mt-1"><%= component.description %></div>
                <div class="flex flex-wrap gap-1 mt-2">
                  <%= for tag <- component.tags do %>
                    <span class="px-2 py-1 text-xs bg-gray-200 rounded"><%= tag %></span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
      
      <!-- Main Content -->
      <div class="main-content flex-1 flex flex-col">
        <!-- Header -->
        <div class="header p-4 border-b bg-white">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold">Raxol Component Playground</h1>
              <%= if @selected_component do %>
                <p class="text-gray-600 mt-1"><%= @selected_component.description %></p>
              <% end %>
            </div>
            
            <div class="flex gap-2">
              <button
                phx-click="run_component"
                class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
              >
                Run Component
              </button>
            </div>
          </div>
        </div>
        
        <!-- Code Editor & Preview -->
        <div class="content flex-1 flex">
          <!-- Code Editor -->
          <div class="editor-panel w-1/2 flex flex-col border-r">
            <div class="editor-header p-3 bg-gray-50 border-b">
              <h3 class="font-medium">Component Code</h3>
            </div>
            
            <div class="editor flex-1 relative">
              <textarea
                phx-update="ignore"
                phx-hook="CodeEditor"
                id="code-editor"
                class="w-full h-full p-4 font-mono text-sm resize-none border-none outline-none"
                phx-blur="update_code"
              ><%= @component_code %></textarea>
            </div>
            
            <%= if @error_message do %>
              <div class="error-panel p-3 bg-red-50 border-t border-red-200">
                <div class="text-red-800 text-sm font-mono"><%= @error_message %></div>
              </div>
            <% end %>
          </div>
          
          <!-- Preview Panel -->
          <div class="preview-panel w-1/2 flex flex-col">
            <div class="preview-header p-3 bg-gray-50 border-b">
              <h3 class="font-medium">Live Preview</h3>
            </div>
            
            <div class="preview flex-1 bg-black text-green-400 font-mono text-sm overflow-auto">
              <div class="terminal-output p-4 whitespace-pre-wrap"><%= @preview_output %></div>
            </div>
            
            <!-- Component Info -->
            <%= if @selected_component do %>
              <div class="component-info p-3 bg-gray-50 border-t">
                <div class="text-sm">
                  <div class="mb-2">
                    <span class="font-medium">Framework:</span> <%= @selected_component.framework %>
                  </div>
                  <div class="mb-2">
                    <span class="font-medium">Complexity:</span> <%= @selected_component.complexity %>
                  </div>
                  <div>
                    <span class="font-medium">API:</span>
                    <a href="#" class="text-blue-600 hover:underline ml-1">View Docs</a>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp list_available_components do
    [
      %{
        name: "Button",
        description:
          "Interactive button component with various styles and states",
        framework: "Universal",
        complexity: "Basic",
        tags: ["input", "interactive", "basic"],
        category: "Input"
      },
      %{
        name: "TextInput",
        description: "Single-line text input with validation and formatting",
        framework: "Universal",
        complexity: "Intermediate",
        tags: ["input", "form", "validation"],
        category: "Input"
      },
      %{
        name: "Table",
        description: "Data table with sorting, filtering, and pagination",
        framework: "Universal",
        complexity: "Advanced",
        tags: ["data", "display", "sorting"],
        category: "Display"
      },
      %{
        name: "Progress",
        description: "Progress indicator with customizable appearance",
        framework: "Universal",
        complexity: "Basic",
        tags: ["feedback", "loading", "progress"],
        category: "Feedback"
      },
      %{
        name: "Modal",
        description: "Modal dialog with backdrop and focus management",
        framework: "React",
        complexity: "Intermediate",
        tags: ["overlay", "dialog", "focus"],
        category: "Overlay"
      },
      %{
        name: "Menu",
        description: "Dropdown menu with keyboard navigation",
        framework: "Universal",
        complexity: "Advanced",
        tags: ["navigation", "keyboard", "dropdown"],
        category: "Navigation"
      }
    ]
  end

  defp get_component_code(component) do
    case component.name do
      "Button" ->
        """
        use Raxol.UI, framework: :universal

        def render(assigns) do
          ~H\"\"\"
          <button class={@class} onclick={@onclick}>
            <%= @text %>
          </button>
          \"\"\"
        end

        # Example usage:
        Button.render(%{
          text: "Click Me",
          class: "btn btn-primary",
          onclick: fn -> IO.puts("Button clicked!") end
        })
        """

      "TextInput" ->
        """
        use Raxol.UI, framework: :universal

        def render(assigns) do
          ~H\"\"\"
          <input
            type="text"
            value={@value}
            placeholder={@placeholder}
            oninput={@oninput}
            class={@class}
          />
          \"\"\"
        end

        # Example usage:
        TextInput.render(%{
          value: "",
          placeholder: "Enter text here...",
          class: "input input-bordered",
          oninput: fn value -> send(self(), {:input_changed, value}) end
        })
        """

      "Table" ->
        """
        use Raxol.UI, framework: :universal

        def render(assigns) do
          ~H\"\"\"
          <table class="table">
            <thead>
              <tr>
                <%= for column <- @columns do %>
                  <th><%= column.title %></th>
                <% end %>
              </tr>
            </thead>
            <tbody>
              <%= for row <- @data do %>
                <tr>
                  <%= for column <- @columns do %>
                    <td><%= get_in(row, [column.field]) %></td>
                  <% end %>
                </tr>
              <% end %>
            </tbody>
          </table>
          \"\"\"
        end

        # Example usage:
        Table.render(%{
          columns: [
            %{title: "Name", field: :name},
            %{title: "Age", field: :age},
            %{title: "City", field: :city}
          ],
          data: [
            %{name: "Alice", age: 30, city: "NYC"},
            %{name: "Bob", age: 25, city: "SF"}
          ]
        })
        """

      _ ->
        """
        use Raxol.UI, framework: :universal

        def render(assigns) do
          ~H\"\"\"
          <div>
            Component: #{component.name}
          </div>
          \"\"\"
        end
        """
    end
  end

  defp execute_component_code(code) do
    try do
      # Simulate component execution
      output = """
      ┌─────────────────────────────────────────────────────────┐
      │                   Component Output                      │
      ├─────────────────────────────────────────────────────────┤
      │                                                         │
      │  [Button] Click Me                                      │
      │                                                         │
      │  Component rendered successfully!                       │
      │  Framework: Universal                                   │
      │  Render time: 0.42ms                                    │
      │                                                         │
      └─────────────────────────────────────────────────────────┘
      """

      {:ok, output}
    rescue
      error ->
        {:error, "Error: #{inspect(error)}"}
    end
  end

  defp filter_components(components, query) do
    ComponentHelpers.filter_by_search(components, query)
  end
end
