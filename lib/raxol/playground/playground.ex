defmodule Raxol.Playground do
  @moduledoc """
  Interactive component playground for Raxol.

  This module provides a live environment for exploring and testing Raxol components,
  with real-time preview, property editing, and code generation.

  Features:
  * Component catalog with categorized examples
  * Live preview with hot-reloading
  * Interactive property editors
  * Code generation and export
  * Theme switching
  * Responsive layout testing
  """

  use GenServer
  require Logger

  alias Raxol.Playground.{
    Catalog,
    Preview,
    PropertyEditor,
    CodeGenerator,
    Examples,
    State
  }

  @default_port 4444

  # Client API

  @doc """
  Starts the component playground.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Launches the playground in the terminal.
  """
  def launch(opts \\ []) do
    port = Keyword.get(opts, :port, @default_port)

    case start_link(port: port) do
      {:ok, _pid} ->
        Logger.info("Raxol Playground started on port #{port}")
        run_playground()

      {:error, {:already_started, _pid}} ->
        Logger.info("Playground already running")
        run_playground()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the current component catalog.
  """
  def get_catalog do
    GenServer.call(__MODULE__, :get_catalog)
  end

  @doc """
  Selects a component for preview.
  """
  def select_component(component_id) do
    GenServer.call(__MODULE__, {:select_component, component_id})
  end

  @doc """
  Updates component properties.
  """
  def update_props(props) do
    GenServer.call(__MODULE__, {:update_props, props})
  end

  @doc """
  Updates component state.
  """
  def update_state(state) do
    GenServer.call(__MODULE__, {:update_state, state})
  end

  @doc """
  Switches the theme.
  """
  def switch_theme(theme) do
    GenServer.call(__MODULE__, {:switch_theme, theme})
  end

  @doc """
  Exports the current component code.
  """
  def export_code do
    GenServer.call(__MODULE__, :export_code)
  end

  @doc """
  Gets the current preview.
  """
  def get_preview do
    GenServer.call(__MODULE__, :get_preview)
  end

  @doc """
  Refreshes the preview.
  """
  def refresh_preview do
    GenServer.call(__MODULE__, :refresh_preview)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    port = Keyword.get(opts, :port, @default_port)

    state = %State{
      port: port,
      catalog: Catalog.load_components(),
      selected_component: nil,
      current_props: %{},
      current_state: %{},
      theme: :default,
      preview_mode: :terminal,
      layout: :split,
      code_visible: true
    }

    # Start preview server if web mode
    if Keyword.get(opts, :web, false) do
      start_web_server(port)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:get_catalog, _from, state) do
    {:reply, state.catalog, state}
  end

  @impl true
  def handle_call({:select_component, component_id}, _from, state) do
    case Catalog.get_component(state.catalog, component_id) do
      nil ->
        {:reply, {:error, "Component not found"}, state}

      component ->
        new_state = %{
          state
          | selected_component: component,
            current_props: component.default_props || %{},
            current_state: Map.get(component, :default_state, %{})
        }

        preview =
          Preview.generate(
            component,
            new_state.current_props,
            new_state.current_state
          )

        {:reply, {:ok, preview}, new_state}
    end
  end

  @impl true
  def handle_call({:update_props, props}, _from, state) do
    new_state = %{state | current_props: Map.merge(state.current_props, props)}

    if state.selected_component do
      preview =
        Preview.generate(
          state.selected_component,
          new_state.current_props,
          new_state.current_state
        )

      {:reply, {:ok, preview}, new_state}
    else
      {:reply, {:error, "No component selected"}, new_state}
    end
  end

  @impl true
  def handle_call({:update_state, new_component_state}, _from, state) do
    new_state = %{
      state
      | current_state: Map.merge(state.current_state, new_component_state)
    }

    if state.selected_component do
      preview =
        Preview.generate(
          state.selected_component,
          new_state.current_props,
          new_state.current_state
        )

      {:reply, {:ok, preview}, new_state}
    else
      {:reply, {:error, "No component selected"}, new_state}
    end
  end

  @impl true
  def handle_call({:switch_theme, theme}, _from, state) do
    new_state = %{state | theme: theme}

    if state.selected_component do
      preview =
        Preview.generate(
          state.selected_component,
          state.current_props,
          state.current_state,
          theme: theme
        )

      {:reply, {:ok, preview}, new_state}
    else
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:export_code, _from, state) do
    if state.selected_component do
      code =
        CodeGenerator.generate(
          state.selected_component,
          state.current_props,
          state.current_state
        )

      {:reply, {:ok, code}, state}
    else
      {:reply, {:error, "No component selected"}, state}
    end
  end

  @impl true
  def handle_call(:get_preview, _from, state) do
    if state.selected_component do
      preview =
        Preview.generate(
          state.selected_component,
          state.current_props,
          state.current_state,
          theme: state.theme
        )

      {:reply, {:ok, preview}, state}
    else
      {:reply, {:error, "No component selected"}, state}
    end
  end

  @impl true
  def handle_call(:refresh_preview, _from, state) do
    if state.selected_component do
      preview =
        Preview.generate(
          state.selected_component,
          state.current_props,
          state.current_state,
          theme: state.theme,
          force_refresh: true
        )

      {:reply, {:ok, preview}, state}
    else
      {:reply, {:error, "No component selected"}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Private Functions

  defp run_playground do
    IO.puts("""

    #{IO.ANSI.cyan()}╔════════════════════════════════════════════════════╗
    ║        Raxol Component Playground 🎨               ║
    ╚════════════════════════════════════════════════════╝#{IO.ANSI.reset()}

    Welcome to the interactive component showcase!

    Commands:
      #{IO.ANSI.green()}list [category]#{IO.ANSI.reset()}     - List components (optionally by category)
      #{IO.ANSI.green()}select <id>#{IO.ANSI.reset()}         - Select a component to preview
      #{IO.ANSI.green()}props#{IO.ANSI.reset()}               - Show current props editor
      #{IO.ANSI.green()}set <prop> <value>#{IO.ANSI.reset()}  - Update a property
      #{IO.ANSI.green()}theme <name>#{IO.ANSI.reset()}        - Switch theme (dark, light, default)
      #{IO.ANSI.green()}export#{IO.ANSI.reset()}              - Export component code
      #{IO.ANSI.green()}preview#{IO.ANSI.reset()}             - Show current preview
      #{IO.ANSI.green()}refresh#{IO.ANSI.reset()}             - Refresh preview
      #{IO.ANSI.green()}examples#{IO.ANSI.reset()}            - List interactive examples
      #{IO.ANSI.green()}run <example_id>#{IO.ANSI.reset()}    - Run an interactive example
      #{IO.ANSI.green()}help#{IO.ANSI.reset()}                - Show help
      #{IO.ANSI.green()}exit#{IO.ANSI.reset()}                - Exit playground

    Type 'list' to see available components.
    """)

    playground_loop()
  end

  defp playground_loop do
    input =
      IO.gets("\n#{IO.ANSI.green()}playground>#{IO.ANSI.reset()} ")
      |> String.trim()

    case parse_command(input) do
      {:exit} ->
        IO.puts("Goodbye! Thanks for using Raxol Playground! 🎨")
        :ok

      {:error, message} ->
        IO.puts("#{IO.ANSI.red()}Error: #{message}#{IO.ANSI.reset()}")
        playground_loop()

      :ok ->
        playground_loop()
    end
  end

  defp parse_command("exit"), do: {:exit}
  defp parse_command("quit"), do: {:exit}

  defp parse_command("list") do
    catalog = get_catalog()
    display_catalog(catalog)
    :ok
  end

  defp parse_command("list " <> category) do
    catalog = get_catalog()
    filtered = Catalog.filter_by_category(catalog, String.to_atom(category))
    display_catalog(filtered)
    :ok
  end

  defp parse_command("select " <> component_id) do
    case select_component(component_id) do
      {:ok, preview} ->
        IO.puts(
          "\n#{IO.ANSI.bright()}Selected: #{component_id}#{IO.ANSI.reset()}\n"
        )

        display_preview(preview)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_command("props") do
    state = GenServer.call(__MODULE__, :get_state)

    if state.selected_component do
      editor_output =
        PropertyEditor.render_terminal_editor(
          state.selected_component,
          state.current_props
        )

      IO.puts(editor_output)
      :ok
    else
      {:error, "No component selected"}
    end
  end

  defp parse_command("set " <> rest) do
    state = GenServer.call(__MODULE__, :get_state)

    case String.split(rest, " ", parts: 2) do
      [prop, value] ->
        if state.selected_component do
          case PropertyEditor.parse_property_value(
                 state.selected_component,
                 prop,
                 value
               ) do
            {:ok, parsed_value} ->
              case update_props(%{String.to_atom(prop) => parsed_value}) do
                {:ok, preview} ->
                  IO.puts(
                    "#{IO.ANSI.green()}✓ Updated #{prop} = #{inspect(parsed_value)}#{IO.ANSI.reset()}"
                  )

                  display_preview(preview)
                  :ok

                {:error, reason} ->
                  {:error, reason}
              end

            {:error, reason} ->
              help =
                PropertyEditor.get_property_help(state.selected_component, prop)

              {:error,
               "Invalid value for #{prop}: #{reason}\nExpected: #{help}"}
          end
        else
          {:error, "No component selected"}
        end

      _ ->
        {:error, "Usage: set <prop> <value>"}
    end
  end

  defp parse_command("theme " <> theme_name) do
    case switch_theme(String.to_atom(theme_name)) do
      {:ok, preview} ->
        IO.puts(
          "#{IO.ANSI.green()}✓ Theme switched to: #{theme_name}#{IO.ANSI.reset()}"
        )

        display_preview(preview)
        :ok

      _ ->
        :ok
    end
  end

  defp parse_command("export") do
    case export_code() do
      {:ok, code} ->
        display_code(code)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_command("preview") do
    case get_preview() do
      {:ok, preview} ->
        display_preview(preview)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_command("refresh") do
    case refresh_preview() do
      {:ok, preview} ->
        display_preview(preview)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_command("examples") do
    examples = Examples.list_examples()
    display_examples(examples)
    :ok
  end

  defp parse_command("run " <> example_id) do
    case Examples.run_example(example_id) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_command("help") do
    display_help()
    :ok
  end

  defp parse_command(_) do
    {:error, "Unknown command. Type 'help' for available commands."}
  end

  defp display_catalog(catalog) do
    IO.puts("\n#{IO.ANSI.bright()}Component Catalog:#{IO.ANSI.reset()}\n")

    catalog
    |> Enum.group_by(& &1.category)
    |> Enum.each(fn {category, components} ->
      IO.puts("#{IO.ANSI.cyan()}#{category}:#{IO.ANSI.reset()}")

      Enum.each(components, fn comp ->
        IO.puts(
          "  #{IO.ANSI.green()}#{comp.id}#{IO.ANSI.reset()} - #{comp.description}"
        )
      end)

      IO.puts("")
    end)
  end

  defp display_preview(preview) do
    IO.puts("\n#{IO.ANSI.bright()}Preview:#{IO.ANSI.reset()}")
    IO.puts("#{String.duplicate("─", 60)}")
    IO.puts(preview)
    IO.puts("#{String.duplicate("─", 60)}\n")
  end

  defp display_props(props) do
    IO.puts("\n#{IO.ANSI.bright()}Current Props:#{IO.ANSI.reset()}")

    if map_size(props) == 0 do
      IO.puts("  (none)")
    else
      Enum.each(props, fn {key, value} ->
        IO.puts("  #{key}: #{inspect(value)}")
      end)
    end
  end

  defp display_code(code) do
    IO.puts("\n#{IO.ANSI.bright()}Generated Code:#{IO.ANSI.reset()}")
    IO.puts("#{IO.ANSI.light_black()}```elixir#{IO.ANSI.reset()}")
    IO.puts(code)
    IO.puts("#{IO.ANSI.light_black()}```#{IO.ANSI.reset()}\n")
  end

  defp display_examples(examples) do
    IO.puts("\n#{IO.ANSI.bright()}Interactive Examples:#{IO.ANSI.reset()}\n")

    examples
    |> Enum.each(fn {category, example_list} ->
      category_name =
        category
        |> to_string()
        |> String.capitalize()

      IO.puts("#{IO.ANSI.cyan()}#{category_name}:#{IO.ANSI.reset()}")

      Enum.each(example_list, fn example ->
        IO.puts(
          "  #{IO.ANSI.green()}#{example.id}#{IO.ANSI.reset()} - #{example.title}"
        )

        IO.puts("    #{example.description}")
      end)

      IO.puts("")
    end)

    IO.puts(
      "#{IO.ANSI.light_black()}Use 'run <example_id>' to start an interactive example.#{IO.ANSI.reset()}"
    )
  end

  defp display_help do
    IO.puts("""

    #{IO.ANSI.bright()}Available Commands:#{IO.ANSI.reset()}

    #{IO.ANSI.green()}Component Selection:#{IO.ANSI.reset()}
      list [category]    - List all components or by category
      select <id>        - Select a component for preview

    #{IO.ANSI.green()}Property Management:#{IO.ANSI.reset()}
      props              - Show current properties editor
      set <prop> <value> - Set a property value (with type validation)

    #{IO.ANSI.green()}Theming:#{IO.ANSI.reset()}
      theme <name>       - Switch theme (default, dark, light)

    #{IO.ANSI.green()}Preview & Export:#{IO.ANSI.reset()}
      preview            - Show current component preview
      refresh            - Force refresh the preview
      export             - Export component code

    #{IO.ANSI.green()}Learning:#{IO.ANSI.reset()}
      examples           - List interactive examples and tutorials
      run <example_id>   - Start an interactive example

    #{IO.ANSI.green()}Navigation:#{IO.ANSI.reset()}
      help               - Show this help message
      exit               - Exit the playground

    #{IO.ANSI.yellow()}Tips:#{IO.ANSI.reset()}
    • Start with 'examples' to see guided tutorials
    • Use 'props' to see available properties and their types
    • Export code generates ready-to-use Elixir components
    • Try different themes to see how components adapt
    """)
  end

  defp parse_value("true"), do: true
  defp parse_value("false"), do: false
  defp parse_value("nil"), do: nil
  defp parse_value(":" <> atom), do: String.to_atom(atom)

  defp parse_value(value) do
    case Integer.parse(value) do
      {int, ""} ->
        int

      _ ->
        case Float.parse(value) do
          {float, ""} -> float
          _ -> value
        end
    end
  end

  defp start_web_server(_port) do
    # Web server implementation would go here
    :ok
  end
end
