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
      |> assign(:component_code, get_component_code(List.first(components)))
      |> assign(:preview_output, "")
      |> assign(:error_message, nil)
      |> assign(:search_query, "")
      |> assign(:filtered_components, components)
      |> assign(:selected_framework, "universal")
      |> assign(:auto_run, true)
      |> assign(:show_shortcuts, false)
      |> assign(:is_running, false)

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
      |> run_if_auto_run()

    {:noreply, socket}
  end

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

    case execute_component_code(socket.assigns.component_code, socket.assigns.selected_component) do
      {:ok, output} ->
        socket =
          socket
          |> assign(:preview_output, output)
          |> assign(:error_message, nil)
          |> assign(:is_running, false)

        {:noreply, socket}

      {:error, error} ->
        socket =
          socket
          |> assign(:error_message, error)
          |> assign(:preview_output, "")
          |> assign(:is_running, false)

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

  def handle_event("select_framework", %{"framework" => framework}, socket) do
    code = get_component_code_for_framework(socket.assigns.selected_component, framework)

    socket =
      socket
      |> assign(:selected_framework, framework)
      |> assign(:component_code, code)
      |> run_if_auto_run()

    {:noreply, socket}
  end

  def handle_event("toggle_auto_run", _params, socket) do
    {:noreply, assign(socket, :auto_run, !socket.assigns.auto_run)}
  end

  def handle_event("toggle_shortcuts", _params, socket) do
    {:noreply, assign(socket, :show_shortcuts, !socket.assigns.show_shortcuts)}
  end

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
        <div class="sidebar w-80 bg-white border-r overflow-y-auto shadow-lg">
          <div class="p-4">
            <h2 class="text-xl font-bold mb-4 text-gray-800">Components</h2>

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

            <!-- Component List by Category -->
            <%= for category <- get_categories(@filtered_components) do %>
              <div class="category-header"><%= category %></div>
              <div class="space-y-2 mb-4">
                <%= for component <- get_components_by_category(@filtered_components, category) do %>
                  <div
                    class={"component-item p-3 rounded-lg cursor-pointer border #{if @selected_component && @selected_component.name == component.name, do: "bg-blue-50 border-blue-300 shadow-sm", else: "bg-gray-50 hover:bg-gray-100 border-transparent"}"}
                    phx-click="select_component"
                    phx-value-component={component.name}
                  >
                    <div class="font-medium text-sm text-gray-900"><%= component.name %></div>
                    <div class="text-xs text-gray-600 mt-1"><%= component.description %></div>
                    <div class="flex flex-wrap gap-1 mt-2">
                      <%= for tag <- component.tags do %>
                        <span class="px-2 py-1 text-xs bg-white border border-gray-200 rounded"><%= tag %></span>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Main Content -->
        <div class="main-content flex-1 flex flex-col bg-white">
          <!-- Toolbar -->
          <div class="border-b bg-gray-50 p-4">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-4">
                <div>
                  <%= if @selected_component do %>
                    <h2 class="text-lg font-bold text-gray-900"><%= @selected_component.name %></h2>
                    <p class="text-sm text-gray-600"><%= @selected_component.description %></p>
                  <% end %>
                </div>

                <!-- Framework Selector -->
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
              </div>

              <div class="flex items-center gap-3">
                <!-- Auto-run Toggle -->
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

                <!-- Run Button -->
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

                <!-- Shortcuts Button -->
                <button
                  phx-click="toggle_shortcuts"
                  class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-100"
                >
                  ?
                </button>
              </div>
            </div>
          </div>

          <!-- Code Editor & Preview -->
          <div class="content flex-1 flex overflow-hidden">
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

              <!-- Component Info -->
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
                      <span class={"px-2 py-1 rounded text-xs font-medium #{complexity_class(@selected_component.complexity)}"}>
                        <%= @selected_component.complexity %>
                      </span>
                    </div>
                    <div>
                      <span class="font-medium text-gray-700">API:</span>
                      <a href="#" class="text-blue-600 hover:underline ml-1">View Docs →</a>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Keyboard Shortcuts Overlay -->
      <%= if @show_shortcuts do %>
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
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp run_if_auto_run(socket) do
    if socket.assigns.auto_run do
      case execute_component_code(socket.assigns.component_code, socket.assigns.selected_component) do
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

  defp complexity_class("Basic"), do: "bg-green-100 text-green-800"
  defp complexity_class("Intermediate"), do: "bg-yellow-100 text-yellow-800"
  defp complexity_class("Advanced"), do: "bg-red-100 text-red-800"
  defp complexity_class(_), do: "bg-gray-100 text-gray-800"

  defp get_categories(components) do
    components
    |> Enum.map(& &1.category)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp get_components_by_category(components, category) do
    Enum.filter(components, &(&1.category == category))
  end

  defp list_available_components do
    [
      %{
        name: "Button",
        description: "Interactive button component with various styles and states",
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

        # Example:
        Table.render(%{
          columns: [
            %{title: "Name", field: :name},
            %{title: "Age", field: :age}
          ],
          data: [
            %{name: "Alice", age: 30},
            %{name: "Bob", age: 25}
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

  defp get_component_code_for_framework(component, framework) do
    case {component.name, framework} do
      {"Menu", "react"} -> get_menu_react_code()
      {"Menu", "liveview"} -> get_menu_liveview_code()
      {"Menu", "raw"} -> get_menu_raw_code()
      {"Button", "react"} -> get_button_react_code()
      {"Button", "liveview"} -> get_button_liveview_code()
      {"Button", "raw"} -> get_button_raw_code()
      {_, "react"} -> get_generic_react_code(component)
      {_, "liveview"} -> get_generic_liveview_code(component)
      {_, "raw"} -> get_generic_raw_code(component)
      _ -> get_component_code(component)
    end
  end

  # React-style Menu component
  defp get_menu_react_code do
    """
    use Raxol.UI, framework: :react

    def render(assigns) do
      ~H\"\"\"
      <div>
        Component: Menu
      </div>
      \"\"\"
    end
    """
  end

  # LiveView-style Menu component
  defp get_menu_liveview_code do
    """
    use Raxol.UI, framework: :liveview

    def mount(_params, _session, socket) do
      {:ok, assign(socket,
        items: ["File", "Edit", "View", "Help"],
        selected: nil,
        is_open: false
      )}
    end

    def handle_event("toggle", _params, socket) do
      {:noreply, assign(socket, :is_open, !socket.assigns.is_open)}
    end

    def handle_event("select", %{"item" => item}, socket) do
      {:noreply, assign(socket, selected: item, is_open: false)}
    end

    def render(assigns) do
      ~H\"\"\"
      <div>
        <button phx-click="toggle" class="menu-button">
          Menu
        </button>

        <%= if @is_open do %>
          <div class="menu-dropdown">
            <%= for item <- @items do %>
              <div phx-click="select" phx-value-item={item} class="menu-item">
                <%= item %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      \"\"\"
    end
    """
  end

  # Raw terminal buffer Menu component
  defp get_menu_raw_code do
    """
    use Raxol.UI, framework: :raw

    alias Raxol.Terminal.Buffer
    alias Raxol.Terminal.Commands

    def render(buffer, x, y, items, selected) do
      buffer
      |> Commands.move_cursor(x, y)
      |> Commands.set_fg_color(:white)
      |> Commands.set_bg_color(:blue)
      |> Commands.write_text(" Menu ")
      |> Commands.reset_colors()
      |> render_items(x, y + 1, items, selected)
    end

    defp render_items(buffer, _x, _y, [], _selected), do: buffer

    defp render_items(buffer, x, y, [item | rest], selected) do
      is_selected = item == selected

      buffer
      |> Commands.move_cursor(x, y)
      |> Commands.set_fg_color(if is_selected, do: :black, else: :white)
      |> Commands.set_bg_color(if is_selected, do: :cyan, else: :black)
      |> Commands.write_text("  " <> item <> "  ")
      |> Commands.reset_colors()
      |> render_items(x, y + 1, rest, selected)
    end

    # Usage:
    # buffer = Buffer.new(80, 24)
    # buffer = render(buffer, 2, 2, ["File", "Edit", "View"], "Edit")
    """
  end

  # React-style Button component
  defp get_button_react_code do
    """
    use Raxol.UI, framework: :react

    def render(assigns) do
      ~H\"\"\"
      <button
        class={@class}
        disabled={@disabled}
        onclick={@onclick}
      >
        <%= @label %>
      </button>
      \"\"\"
    end

    # Example usage:
    # Button.render(%{
    #   label: "Click Me",
    #   class: "btn btn-primary",
    #   disabled: false,
    #   onclick: fn -> IO.puts("Clicked!") end
    # })
    """
  end

  # LiveView-style Button component
  defp get_button_liveview_code do
    """
    use Raxol.UI, framework: :liveview

    def mount(_params, _session, socket) do
      {:ok, assign(socket,
        label: "Click Me",
        count: 0,
        disabled: false
      )}
    end

    def handle_event("click", _params, socket) do
      new_count = socket.assigns.count + 1
      {:noreply, assign(socket, :count, new_count)}
    end

    def render(assigns) do
      ~H\"\"\"
      <button
        phx-click="click"
        disabled={@disabled}
        class="btn btn-primary"
      >
        <%= @label %> (Clicked: <%= @count %>)
      </button>
      \"\"\"
    end
    """
  end

  # Raw terminal buffer Button component
  defp get_button_raw_code do
    """
    use Raxol.UI, framework: :raw

    alias Raxol.Terminal.Buffer
    alias Raxol.Terminal.Commands

    def render(buffer, x, y, label, is_focused) do
      fg = if is_focused, do: :black, else: :white
      bg = if is_focused, do: :cyan, else: :blue

      buffer
      |> Commands.move_cursor(x, y)
      |> Commands.set_fg_color(fg)
      |> Commands.set_bg_color(bg)
      |> Commands.write_text(" " <> label <> " ")
      |> Commands.reset_colors()
    end

    # Usage:
    # buffer = Buffer.new(80, 24)
    # buffer = render(buffer, 10, 5, "Click Me", true)
    """
  end

  # Generic React component template
  defp get_generic_react_code(component) do
    """
    use Raxol.UI, framework: :react

    def render(assigns) do
      ~H\"\"\"
      <div>
        Component: #{component.name}
      </div>
      \"\"\"
    end
    """
  end

  # Generic LiveView component template
  defp get_generic_liveview_code(component) do
    """
    use Raxol.UI, framework: :liveview

    def mount(_params, _session, socket) do
      {:ok, assign(socket, component: "#{component.name}")}
    end

    def render(assigns) do
      ~H\"\"\"
      <div>
        Component: <%= @component %>
      </div>
      \"\"\"
    end
    """
  end

  # Generic Raw terminal buffer template
  defp get_generic_raw_code(component) do
    """
    use Raxol.UI, framework: :raw

    alias Raxol.Terminal.Buffer
    alias Raxol.Terminal.Commands

    def render(buffer, x, y) do
      buffer
      |> Commands.move_cursor(x, y)
      |> Commands.set_fg_color(:cyan)
      |> Commands.write_text("Component: #{component.name}")
      |> Commands.reset_colors()
    end

    # Usage:
    # buffer = Buffer.new(80, 24)
    # buffer = render(buffer, 0, 0)
    """
  end

  defp execute_component_code(code, component) do
    start_time = System.monotonic_time(:microsecond)

    case compile_and_execute(code, component) do
      {:ok, output} ->
        elapsed = (System.monotonic_time(:microsecond) - start_time) / 1000.0

        result = """
        ╔═══════════════════════════════════════════════════════════╗
        ║              Component Rendered Successfully              ║
        ╠═══════════════════════════════════════════════════════════╣
        ║                                                           ║
        #{output}
        ║                                                           ║
        ║   Render time: #{Float.round(elapsed, 2)}ms                                      ║
        ╚═══════════════════════════════════════════════════════════╝
        """

        {:ok, result}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  rescue
    error ->
      {:error, "Unexpected error: #{Exception.message(error)}"}
  end

  defp compile_and_execute(code, component) do
    module_name = :"PlaygroundComponent#{:erlang.unique_integer([:positive])}"

    full_code = """
    defmodule #{module_name} do
      #{code}
    end
    """

    case Code.compile_string(full_code) do
      [{^module_name, _bytecode}] ->
        render_component(module_name, component)

      [] ->
        {:error, "Failed to compile module"}

      _other ->
        {:error, "Unexpected compilation result"}
    end
  rescue
    e in CompileError ->
      {:error, {:compile_error, e.description}}

    e ->
      {:error, {:exception, Exception.message(e)}}
  after
    if Code.ensure_loaded?(module_name) do
      :code.delete(module_name)
      :code.purge(module_name)
    end
  end

  defp render_component(module, component) do
    cond do
      function_exported?(module, :render, 1) ->
        render_template_component(module, component)

      function_exported?(module, :render, 2) ->
        render_buffer_component(module, component)

      function_exported?(module, :render, 4) ->
        render_raw_component(module, component)

      true ->
        {:error, "No valid render function found"}
    end
  end

  defp render_template_component(module, component) do
    assigns = %{
      component: component.name,
      framework: component.framework
    }

    case module.render(assigns) do
      {:safe, iodata} ->
        html = IO.iodata_to_binary(iodata)
        output = """
        ║   Component: #{String.pad_trailing(component.name, 43)} ║
        ║   Framework: #{String.pad_trailing(component.framework, 43)} ║
        ║                                                           ║
        ║   Template Output (simplified):                          ║
        ║   #{String.pad_trailing(extract_text(html), 53)} ║
        """
        {:ok, output}

      other ->
        {:ok, "║   Output: #{inspect(other) |> String.slice(0, 50)}"}
    end
  rescue
    e ->
      {:error, "Render failed: #{Exception.message(e)}"}
  end

  defp render_buffer_component(_module, component) do
    output = """
    ║   Component: #{String.pad_trailing(component.name, 43)} ║
    ║   Framework: Raw (buffer)                                 ║
    ║                                                           ║
    ║   Note: Buffer rendering requires terminal context       ║
    """
    {:ok, output}
  end

  defp render_raw_component(_module, component) do
    output = """
    ║   Component: #{String.pad_trailing(component.name, 43)} ║
    ║   Framework: Raw                                          ║
    ║                                                           ║
    ║   Note: Raw rendering requires terminal buffer           ║
    """
    {:ok, output}
  end

  defp extract_text(html) do
    html
    |> String.replace(~r/<[^>]+>/, "")
    |> String.trim()
    |> String.slice(0, 50)
  end

  defp format_error({:compile_error, description}) do
    """
    Compilation Error:

    #{description}

    Check your syntax and make sure all modules are properly defined.
    """
  end

  defp format_error({:exception, message}) do
    """
    Runtime Error:

    #{message}
    """
  end

  defp format_error(other) do
    """
    Error:

    #{inspect(other)}
    """
  end

  defp filter_components(components, query) do
    if query == "" do
      components
    else
      query_lower = String.downcase(query)

      Enum.filter(components, fn component ->
        String.contains?(String.downcase(component.name), query_lower) ||
          String.contains?(String.downcase(component.description), query_lower) ||
          Enum.any?(component.tags, &String.contains?(String.downcase(&1), query_lower))
      end)
    end
  end
end
