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

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log

  alias Raxol.Playground.{
    Builder,
    Catalog,
    CodeGenerator,
    Errors,
    Examples,
    Preview,
    PropertyEditor,
    Scenarios,
    State
  }

  @default_port 4444

  # Client API

  # start_link is provided by BaseManager

  @doc """
  Launches the playground in the terminal.
  """
  def launch(opts \\ []) do
    port = Keyword.get(opts, :port, @default_port)

    case start_link(port: port) do
      {:ok, _pid} ->
        Log.info("Raxol Playground started on port #{port}")
        run_playground()

      {:error, {:already_started, _pid}} ->
        Log.info("Playground already running")
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
  def init_manager(opts) do
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
    maybe_start_web_server(Keyword.get(opts, :web, false), port)

    {:ok, state}
  end

  @impl true
  def handle_manager_call(:get_catalog, _from, state) do
    {:reply, state.catalog, state}
  end

  @impl true
  def handle_manager_call({:select_component, component_id}, _from, state) do
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
  def handle_manager_call({:update_props, props}, _from, state) do
    new_state = %{state | current_props: Map.merge(state.current_props, props)}

    handle_component_operation(
      state.selected_component,
      new_state,
      &generate_preview_for_props/2
    )
  end

  @impl true
  def handle_manager_call({:update_state, new_component_state}, _from, state) do
    new_state = %{
      state
      | current_state: Map.merge(state.current_state, new_component_state)
    }

    handle_component_operation(
      state.selected_component,
      new_state,
      &generate_preview_for_state/2
    )
  end

  @impl true
  def handle_manager_call({:switch_theme, theme}, _from, state) do
    new_state = %{state | theme: theme}

    handle_theme_operation(
      state.selected_component,
      state,
      new_state,
      theme
    )
  end

  @impl true
  def handle_manager_call(:export_code, _from, state) do
    handle_export_operation(
      state.selected_component,
      state
    )
  end

  @impl true
  def handle_manager_call(:get_preview, _from, state) do
    handle_preview_request(state.selected_component, state)
  end

  @impl true
  def handle_manager_call(:refresh_preview, _from, state) do
    handle_refresh_request(state.selected_component, state)
  end

  @impl true
  def handle_manager_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Private Functions

  defp run_playground do
    # Show instant demo on launch
    display_instant_demo()

    Log.console("""
    #{IO.ANSI.cyan()}+--[ Raxol Playground ]------------------------------------------+#{IO.ANSI.reset()}

    #{IO.ANSI.bright()}Quick Start:#{IO.ANSI.reset()}
      #{IO.ANSI.green()}n#{IO.ANSI.reset()}/#{IO.ANSI.green()}p#{IO.ANSI.reset()}  Next/Previous component   #{IO.ANSI.green()}s#{IO.ANSI.reset()}  Scenarios (guided builds)
      #{IO.ANSI.green()}e#{IO.ANSI.reset()}    Edit props                  #{IO.ANSI.green()}t#{IO.ANSI.reset()}  Switch theme
      #{IO.ANSI.green()}x#{IO.ANSI.reset()}    Export code                  #{IO.ANSI.green()}?#{IO.ANSI.reset()}  Full help

    #{IO.ANSI.bright()}Pipeable API (IEx):#{IO.ANSI.reset()}
      #{IO.ANSI.cyan()}Builder.demo(:button, label: "Click")#{IO.ANSI.reset()}
      #{IO.ANSI.cyan()}Builder.new() |> Builder.component(:table) |> Builder.preview()#{IO.ANSI.reset()}

    #{IO.ANSI.cyan()}+----------------------------------------------------------------+#{IO.ANSI.reset()}
    """)

    playground_loop()
  end

  defp display_instant_demo do
    # Select first component for instant gratification
    catalog = Catalog.load_components()

    featured =
      Enum.find(catalog, fn c -> c.id == "button" end) ||
        List.first(catalog)

    case featured do
      nil ->
        Log.console(render_welcome_ascii())

      component ->
        GenServer.call(__MODULE__, {:select_component, component.id})

        Log.console("""

        #{IO.ANSI.bright()}#{IO.ANSI.cyan()}Raxol#{IO.ANSI.reset()} #{IO.ANSI.bright()}Component Playground#{IO.ANSI.reset()}
        #{IO.ANSI.light_black()}Build terminal UIs with style#{IO.ANSI.reset()}

        #{render_featured_demo(component)}
        """)
    end
  end

  defp render_featured_demo(component) do
    # Render a beautiful ASCII preview of the featured component
    case component.id do
      "button" ->
        """
        +--[ Button Demo ]---------------------+
        |                                      |
        |   [ Click Me ]     Clicks: 0         |
        |                                      |
        |   Variants:                          |
        |   [ Primary ] [ Success ] [ Danger ] |
        |                                      |
        +--------------------------------------+
        """

      "table" ->
        """
        +--[ Table Demo ]----------------------------------+
        | Name           | Email              | Role       |
        +----------------+--------------------+------------+
        | Alice Johnson  | alice@example.com  | Admin      |
        | Bob Smith      | bob@example.com    | User       |
        +----------------+--------------------+------------+
        """

      "progress_bar" ->
        """
        +--[ Progress Demo ]------------------+
        |                                     |
        |  Loading:  [========>         ] 42% |
        |  Complete: [====================] ! |
        |                                     |
        +-------------------------------------+
        """

      _ ->
        preview =
          Preview.generate(component, component.default_props || %{}, %{})

        preview
    end
  end

  defp render_welcome_ascii do
    """

    #{IO.ANSI.cyan()}
    +--------------------------------------------------+
    |                                                  |
    |   ____                  _                        |
    |  |  _ \\ __ ___  _____  | |                       |
    |  | |_) / _` \\ \\/ / _ \\ | |                       |
    |  |  _ < (_| |>  < (_) || |___                    |
    |  |_| \\_\\__,_/_/\\_\\___/ |_____|                   |
    |                                                  |
    |        Terminal UI Framework                     |
    |                                                  |
    +--------------------------------------------------+
    #{IO.ANSI.reset()}
    """
  end

  defp playground_loop do
    input =
      IO.gets("\n#{IO.ANSI.green()}playground>#{IO.ANSI.reset()} ")
      |> String.trim()

    case parse_command(input) do
      {:exit} ->
        Log.console("Goodbye! [STYLE]")
        :ok

      {:error, message} ->
        Log.console("#{IO.ANSI.red()}Error: #{message}#{IO.ANSI.reset()}")
        playground_loop()

      :ok ->
        playground_loop()
    end
  end

  defp parse_command("exit"), do: {:exit}
  defp parse_command("quit"), do: {:exit}
  defp parse_command("q"), do: {:exit}

  # Navigation mode - single key commands
  defp parse_command("n"), do: navigate_next()
  defp parse_command("p"), do: navigate_prev()
  defp parse_command("e"), do: parse_command("props")
  defp parse_command("t"), do: show_theme_menu()
  defp parse_command("x"), do: parse_command("export")
  defp parse_command("?"), do: parse_command("help")
  defp parse_command("s"), do: show_scenarios_menu()

  # Scenario commands
  defp parse_command("scenarios"), do: show_scenarios_menu()

  defp parse_command("scenario " <> scenario_id) do
    run_scenario(String.to_atom(scenario_id))
  end

  # Builder shorthand commands
  defp parse_command("demo " <> component) do
    case Builder.demo(String.to_atom(component)) do
      {:ok, preview} ->
        display_preview(preview)
        :ok

      {:error, reason} ->
        {:error, Errors.format_error({:error, reason})}
    end
  end

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
        Log.console(
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
    handle_props_command(state.selected_component, state)
  end

  defp parse_command("set " <> rest) do
    state = GenServer.call(__MODULE__, :get_state)

    case String.split(rest, " ", parts: 2) do
      [prop, value] ->
        handle_set_property_command(
          state.selected_component,
          prop,
          value,
          state
        )

      _ ->
        {:error, "Usage: set <prop> <value>"}
    end
  end

  defp parse_command("theme " <> theme_name) do
    case switch_theme(String.to_atom(theme_name)) do
      {:ok, preview} ->
        Log.console(
          "#{IO.ANSI.green()}[OK] Theme switched to: #{theme_name}#{IO.ANSI.reset()}"
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
    Log.console("\n#{IO.ANSI.bright()}Component Catalog:#{IO.ANSI.reset()}\n")

    catalog
    |> Enum.group_by(& &1.category)
    |> Enum.each(fn {category, components} ->
      Log.console("#{IO.ANSI.cyan()}#{category}:#{IO.ANSI.reset()}")

      Enum.each(components, fn comp ->
        Log.console(
          "  #{IO.ANSI.green()}#{comp.id}#{IO.ANSI.reset()} - #{comp.description}"
        )
      end)

      Log.console("")
    end)
  end

  defp display_preview(preview) do
    Log.console("\n#{IO.ANSI.bright()}Preview:#{IO.ANSI.reset()}")
    Log.console("#{String.duplicate("─", 60)}")
    Log.console(preview)
    Log.console("#{String.duplicate("─", 60)}\n")
  end

  # Removed display_props - was unused

  defp display_code(code) do
    Log.console("\n#{IO.ANSI.bright()}Generated Code:#{IO.ANSI.reset()}")
    Log.console("#{IO.ANSI.light_black()}```elixir#{IO.ANSI.reset()}")
    Log.console(code)
    Log.console("#{IO.ANSI.light_black()}```#{IO.ANSI.reset()}\n")
  end

  defp display_examples(examples) do
    Log.console(
      "\n#{IO.ANSI.bright()}Interactive Examples:#{IO.ANSI.reset()}\n"
    )

    examples
    |> Enum.each(fn {category, example_list} ->
      category_name =
        category
        |> to_string()
        |> String.capitalize()

      Log.console("#{IO.ANSI.cyan()}#{category_name}:#{IO.ANSI.reset()}")

      Enum.each(example_list, fn example ->
        Log.console(
          "  #{IO.ANSI.green()}#{example.id}#{IO.ANSI.reset()} - #{example.title}"
        )

        Log.console("    #{example.description}")
      end)

      Log.console("")
    end)

    Log.console(
      "#{IO.ANSI.light_black()}Use 'run <example_id>' to start an interactive example.#{IO.ANSI.reset()}"
    )
  end

  defp display_help do
    Log.console("""

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

  # Removed parse_value - was unused

  defp start_web_server(_port) do
    # Web server implementation would go here
    :ok
  end

  # Missing helper functions for compilation
  defp maybe_start_web_server(false, _port), do: :ok
  defp maybe_start_web_server(true, port), do: start_web_server(port)

  defp handle_component_operation(nil, state, _gen_fun) do
    {:reply, {:error, "No component selected"}, state}
  end

  defp handle_component_operation(component, state, gen_fun) do
    preview = gen_fun.(component, state)
    {:reply, {:ok, preview}, state}
  end

  defp generate_preview_for_props(component, state) do
    Preview.generate(component, state.current_props, state.current_state)
  end

  defp generate_preview_for_state(component, state) do
    Preview.generate(component, state.current_props, state.current_state)
  end

  defp handle_theme_operation(nil, _old_state, new_state, _theme) do
    {:reply, {:error, "No component selected"}, new_state}
  end

  defp handle_theme_operation(_component, _old_state, new_state, _theme) do
    preview =
      Preview.generate(
        new_state.selected_component,
        new_state.current_props,
        new_state.current_state,
        theme: new_state.theme
      )

    {:reply, {:ok, preview}, new_state}
  end

  defp handle_export_operation(nil, state) do
    {:reply, {:error, "No component selected"}, state}
  end

  defp handle_export_operation(component, state) do
    code = CodeGenerator.generate(component, state.current_props)
    {:reply, {:ok, code}, state}
  end

  # Helper functions for if statement elimination

  defp handle_preview_request(nil, state) do
    {:reply, {:error, "No component selected"}, state}
  end

  defp handle_preview_request(component, state) do
    preview =
      Preview.generate(
        component,
        state.current_props,
        state.current_state,
        theme: state.theme
      )

    {:reply, {:ok, preview}, state}
  end

  defp handle_refresh_request(nil, state) do
    {:reply, {:error, "No component selected"}, state}
  end

  defp handle_refresh_request(component, state) do
    preview =
      Preview.generate(
        component,
        state.current_props,
        state.current_state,
        theme: state.theme,
        force_refresh: true
      )

    {:reply, {:ok, preview}, state}
  end

  defp handle_props_command(nil, _state) do
    {:error, "No component selected"}
  end

  defp handle_props_command(component, state) do
    editor_output =
      PropertyEditor.render_terminal_editor(component, state.current_props)

    Log.console(editor_output)
    :ok
  end

  defp handle_set_property_command(nil, _prop, _value, _state) do
    {:error, "No component selected"}
  end

  defp handle_set_property_command(component, prop, value, _state) do
    case PropertyEditor.parse_property_value(component, prop, value) do
      {:ok, parsed_value} ->
        case update_props(%{String.to_atom(prop) => parsed_value}) do
          {:ok, preview} ->
            Log.console(
              "#{IO.ANSI.green()}[OK] Updated #{prop} = #{inspect(parsed_value)}#{IO.ANSI.reset()}"
            )

            display_preview(preview)
            :ok

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        help = PropertyEditor.get_property_help(component, prop)
        {:error, "Invalid value for #{prop}: #{reason}\nExpected: #{help}"}
    end
  end

  # ============================================================================
  # Navigation Mode Helpers
  # ============================================================================

  defp navigate_next do
    state = GenServer.call(__MODULE__, :get_state)
    catalog = state.catalog
    current_id = state.selected_component && state.selected_component.id

    next_component = find_next_component(catalog, current_id)

    case next_component do
      nil ->
        {:error, "No more components"}

      component ->
        case select_component(component.id) do
          {:ok, preview} ->
            Log.console(
              "\n#{IO.ANSI.bright()}Component: #{component.id}#{IO.ANSI.reset()} (#{component.category})"
            )

            display_preview(preview)
            :ok

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp navigate_prev do
    state = GenServer.call(__MODULE__, :get_state)
    catalog = state.catalog
    current_id = state.selected_component && state.selected_component.id

    prev_component = find_prev_component(catalog, current_id)

    case prev_component do
      nil ->
        {:error, "No previous components"}

      component ->
        case select_component(component.id) do
          {:ok, preview} ->
            Log.console(
              "\n#{IO.ANSI.bright()}Component: #{component.id}#{IO.ANSI.reset()} (#{component.category})"
            )

            display_preview(preview)
            :ok

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp find_next_component(catalog, nil), do: List.first(catalog)

  defp find_next_component(catalog, current_id) do
    idx = Enum.find_index(catalog, &(&1.id == current_id))

    case idx do
      nil -> List.first(catalog)
      i -> Enum.at(catalog, rem(i + 1, length(catalog)))
    end
  end

  defp find_prev_component(catalog, nil), do: List.last(catalog)

  defp find_prev_component(catalog, current_id) do
    idx = Enum.find_index(catalog, &(&1.id == current_id))
    len = length(catalog)

    case idx do
      nil -> List.last(catalog)
      0 -> Enum.at(catalog, len - 1)
      i -> Enum.at(catalog, i - 1)
    end
  end

  defp show_theme_menu do
    themes = [
      :default,
      :dark,
      :light,
      :dracula,
      :nord,
      :monokai,
      :synthwave84,
      :gruvbox_dark,
      :one_dark,
      :tokyo_night,
      :catppuccin
    ]

    Log.console("""

    #{IO.ANSI.bright()}Available Themes:#{IO.ANSI.reset()}
    #{themes |> Enum.with_index(1) |> Enum.map_join("\n", fn {t, i} -> "  #{IO.ANSI.green()}#{i}#{IO.ANSI.reset()}. #{t}" end)}

    Enter theme name or number:
    """)

    input = IO.gets("") |> String.trim()

    theme =
      case Integer.parse(input) do
        {n, ""} when n > 0 and n <= length(themes) ->
          Enum.at(themes, n - 1)

        _ ->
          String.to_atom(input)
      end

    case switch_theme(theme) do
      {:ok, preview} ->
        Log.console(
          "#{IO.ANSI.green()}[OK] Theme switched to: #{theme}#{IO.ANSI.reset()}"
        )

        display_preview(preview)
        :ok

      {:error, :no_component_selected} ->
        Log.console(
          "#{IO.ANSI.green()}[OK] Theme set to: #{theme}#{IO.ANSI.reset()}"
        )

        :ok

      _ ->
        :ok
    end
  end

  defp show_scenarios_menu do
    scenarios = Scenarios.summary()

    Log.console("""

    #{IO.ANSI.bright()}Real-World Scenarios:#{IO.ANSI.reset()}
    #{IO.ANSI.light_black()}Build complete UIs step by step#{IO.ANSI.reset()}

    #{scenarios |> Enum.with_index(1) |> Enum.map_join("\n", fn {s, i} -> "  #{IO.ANSI.green()}#{i}#{IO.ANSI.reset()}. #{IO.ANSI.bright()}#{s.title}#{IO.ANSI.reset()} - #{s.tagline}\n     #{IO.ANSI.light_black()}#{s.description}#{IO.ANSI.reset()}" end)}

    Enter scenario number to preview, or 'run <number>' to build:
    """)

    input = IO.gets("") |> String.trim()

    case parse_scenario_input(input, scenarios) do
      {:preview, scenario} ->
        case Scenarios.preview(scenario.id) do
          {:ok, preview} ->
            Log.console(
              "\n#{IO.ANSI.bright()}Preview: #{scenario.title}#{IO.ANSI.reset()}\n"
            )

            Log.console(preview)
            :ok

          {:error, reason} ->
            {:error, "#{reason}"}
        end

      {:run, scenario} ->
        run_scenario(scenario.id)

      :cancel ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_scenario_input("", _scenarios), do: :cancel

  defp parse_scenario_input("run " <> rest, scenarios) do
    case Integer.parse(String.trim(rest)) do
      {n, ""} when n > 0 and n <= length(scenarios) ->
        {:run, Enum.at(scenarios, n - 1)}

      _ ->
        {:error, "Invalid scenario number"}
    end
  end

  defp parse_scenario_input(input, scenarios) do
    case Integer.parse(input) do
      {n, ""} when n > 0 and n <= length(scenarios) ->
        {:preview, Enum.at(scenarios, n - 1)}

      _ ->
        {:error, "Invalid input. Enter a number or 'run <number>'"}
    end
  end

  defp run_scenario(scenario_id) do
    case Scenarios.get(scenario_id) do
      nil ->
        available = Scenarios.list() |> Enum.join(", ")
        {:error, "Scenario '#{scenario_id}' not found. Available: #{available}"}

      scenario ->
        Log.console("""

        #{IO.ANSI.bright()}#{IO.ANSI.cyan()}Building: #{scenario.title}#{IO.ANSI.reset()}
        #{IO.ANSI.light_black()}#{scenario.tagline}#{IO.ANSI.reset()}

        """)

        case Scenarios.run(scenario_id) do
          {:ok, components} ->
            Log.console(
              "#{IO.ANSI.green()}[OK] Built #{length(components)} components#{IO.ANSI.reset()}\n"
            )

            # Show the result preview
            case Scenarios.preview(scenario_id) do
              {:ok, preview} ->
                Log.console(preview)

              _ ->
                :ok
            end

            Log.console(
              "\n#{IO.ANSI.light_black()}Use 'export' to generate code for this scenario#{IO.ANSI.reset()}"
            )

            :ok

          {:error, reason} ->
            {:error, "Failed to run scenario: #{reason}"}
        end
    end
  end
end
