defmodule Raxol.Playground.CodeGenerator do
  @moduledoc """
  Generates Elixir code for components with their current configuration.

  This module takes a component definition, props, and state, and generates
  clean, readable Elixir code that can be copied and used in a real application.
  """

  @doc """
  Generates code for a component with current props and state.
  """
  def generate(component, props \\ %{}, state \\ %{}, opts \\ []) do
    format = Keyword.get(opts, :format, :component)
    include_imports = Keyword.get(opts, :include_imports, true)

    case format do
      :component ->
        generate_component_code(component, props, state, include_imports)

      :standalone ->
        generate_standalone_code(component, props, state, include_imports)

      :example ->
        generate_example_code(component, props, state, include_imports)

      _ ->
        generate_component_code(component, props, state, include_imports)
    end
  end

  defp generate_component_code(component, props, state, include_imports) do
    module_name = generate_module_name(component)

    imports =
      generate_component_imports(include_imports, module_name, component)

    init_function = generate_init_function(map_size(state) > 0, state)

    render_function = """

      @impl true
      def render(state, props) do
        #{generate_render_call(component, props)}
      end
    """

    event_handlers = generate_event_handlers(component, state)

    """
    #{imports}#{init_function}#{render_function}#{event_handlers}
    end
    """
  end

  defp generate_standalone_code(component, props, _state, include_imports) do
    imports = generate_standalone_imports(include_imports, component.module)

    """
    #{imports}#{generate_render_call(component, props)}
    """
  end

  defp generate_example_code(component, props, state, include_imports) do
    imports = generate_example_imports(include_imports, component.module)

    state_comment = generate_state_comment(map_size(state) > 0, state)

    """
    #{imports}# Example usage:
    #{state_comment}#{generate_render_call(component, props)}
    """
  end

  # Pattern matching helper functions for code generation

  defp generate_component_imports(false, module_name, _component) do
    """
    defmodule #{module_name} do
      use Raxol.Component
    """
  end

  defp generate_component_imports(true, module_name, component) do
    """
    defmodule #{module_name} do
      use Raxol.Component
      #{generate_aliases(component)}
    """
  end

  defp generate_init_function(false, _state), do: ""

  defp generate_init_function(true, state) do
    """

      @impl true
      def init(_props) do
        {:ok, #{format_map(state, 4)}}
      end
    """
  end

  defp generate_standalone_imports(false, _module), do: ""

  defp generate_standalone_imports(true, module) do
    "alias #{module}\n\n"
  end

  defp generate_example_imports(false, _module), do: ""

  defp generate_example_imports(true, module) do
    """
    # Add to your component or view:
    alias #{module}

    """
  end

  defp generate_state_comment(false, _state), do: ""

  defp generate_state_comment(true, state) do
    """
    # Component state (managed internally):
    # #{format_map(state, 0)}

    """
  end

  defp generate_render_call_with_props(true, module_alias, _props) do
    "#{module_alias}.render()"
  end

  defp generate_render_call_with_props(false, module_alias, props) do
    formatted_props = format_props(props)

    format_multiline_render_call(
      String.contains?(formatted_props, "\n"),
      module_alias,
      formatted_props
    )
  end

  defp format_multiline_render_call(true, module_alias, formatted_props) do
    """
    #{module_alias}.render(#{formatted_props})
    """
  end

  defp format_multiline_render_call(false, module_alias, formatted_props) do
    "#{module_alias}.render(#{formatted_props})"
  end

  defp format_string_value(true, value), do: ~s('#{value}')
  defp format_string_value(false, value), do: ~s("#{value}")

  defp format_list_value(true, value) do
    "[#{Enum.map_join(value, ", ", &format_value/1)}]"
  end

  defp format_list_value(false, value) do
    formatted_items =
      value
      |> Enum.map(&format_value/1)
      |> Enum.map_join(",\n", &("  " <> &1))

    "[\n#{formatted_items}\n]"
  end

  defp format_event_handlers(true, _handlers), do: ""

  defp format_event_handlers(false, handlers) do
    "\n" <> Enum.map_join(handlers, "\n", &generate_handler/1)
  end

  defp generate_handler_with_state_key(true, handler) do
    """

    @impl true
    def handle_event(#{handler.event}, state) do
      # #{handler.action}
      {:ok, %{state | #{handler.state_key}: not state.#{handler.state_key}}}
    end
    """
  end

  defp generate_handler_with_state_key(false, handler) do
    """

    @impl true
    def handle_event(#{handler.event}, state) do
      # #{handler.action}
      # Add your logic here
      {:ok, state}
    end
    """
  end

  defp generate_handler_tests(true, _handlers, _component), do: ""

  defp generate_handler_tests(false, handlers, component) do
    test_cases =
      Enum.map(handlers, fn handler ->
        """
        test "handles #{handler.event} event" do
          {:ok, initial_state} = #{generate_module_name(component)}.init(%{})
          {:ok, new_state} = #{generate_module_name(component)}.handle_event(#{handler.event}, initial_state)

          # Add assertions based on expected behavior
          assert new_state != initial_state
        end
        """
      end)

    Enum.join(test_cases, "\n")
  end

  # Private Functions

  defp generate_module_name(component) do
    base_name =
      component.name
      |> String.replace(" ", "")
      |> String.replace("_", "")

    "MyApp.Components.#{base_name}"
  end

  defp generate_aliases(component) do
    base_alias = "alias #{component.module}"

    # Add common aliases based on component type
    case component.category do
      :layout ->
        """
        #{base_alias}
        alias Raxol.UI.{Box, Flex, Grid}
        """

      :input ->
        """
        #{base_alias}
        alias Raxol.UI.{TextInput, TextArea, Select, Button}
        """

      :data ->
        """
        #{base_alias}
        alias Raxol.UI.{Table, List, ProgressBar}
        """

      _ ->
        base_alias
    end
  end

  defp generate_render_call(component, props) do
    module_alias = get_module_alias(component.module)

    generate_render_call_with_props(map_size(props) == 0, module_alias, props)
  end

  defp get_module_alias(full_module) do
    full_module
    |> to_string()
    |> String.split(".")
    |> List.last()
  end

  defp format_props(props) when map_size(props) == 0 do
    ""
  end

  defp format_props(props) when map_size(props) == 1 do
    [{key, value}] = Map.to_list(props)
    "#{key}: #{format_value(value)}"
  end

  defp format_props(props) when map_size(props) <= 3 do
    props
    |> Map.to_list()
    |> Enum.map_join(", ", fn {key, value} ->
      "#{key}: #{format_value(value)}"
    end)
  end

  defp format_props(props) do
    formatted_pairs =
      props
      |> Map.to_list()
      |> Enum.map_join(",\n", fn {key, value} ->
        "  #{key}: #{format_value(value)}"
      end)

    "\n#{formatted_pairs}\n"
  end

  defp format_map(map, _indent) when map_size(map) == 0 do
    "%{}"
  end

  defp format_map(map, _indent) when map_size(map) <= 2 do
    pairs =
      map
      |> Map.to_list()
      |> Enum.map_join(", ", fn {key, value} ->
        "#{key}: #{format_value(value)}"
      end)

    "%{#{pairs}}"
  end

  defp format_map(map, indent) do
    indent_str = String.duplicate(" ", indent)
    inner_indent = String.duplicate(" ", indent + 2)

    formatted_pairs =
      map
      |> Map.to_list()
      |> Enum.map_join(",\n", fn {key, value} ->
        "#{inner_indent}#{key}: #{format_value(value)}"
      end)

    "%{\n#{formatted_pairs}\n#{indent_str}}"
  end

  defp format_value(value) when is_binary(value) do
    format_string_value(String.contains?(value, "\""), value)
  end

  defp format_value(value) when is_atom(value) do
    ":#{value}"
  end

  defp format_value(value) when is_boolean(value) do
    to_string(value)
  end

  defp format_value(value) when is_number(value) do
    to_string(value)
  end

  defp format_value(value) when is_list(value) do
    format_list_value(
      Enum.all?(value, &is_binary/1) and length(value) <= 5,
      value
    )
  end

  defp format_value(value) when is_map(value) do
    format_map(value, 0)
  end

  defp format_value(value) do
    inspect(value)
  end

  defp generate_event_handlers(component, state) do
    handlers = get_common_handlers(component, state)

    format_event_handlers(Enum.empty?(handlers), handlers)
  end

  defp get_common_handlers(component, _state) do
    case component.category do
      :input ->
        [
          %{
            name: "handle_change",
            event: "{:change, value}",
            action: "update value",
            state_key: :value
          }
        ]

      :interactive when component.id == "button" ->
        [
          %{
            name: "handle_click",
            event: ":click",
            action: "handle button click"
          }
        ]

      :interactive when component.id == "checkbox" ->
        [
          %{
            name: "handle_toggle",
            event: ":toggle",
            action: "toggle checked state",
            state_key: :checked
          }
        ]

      _ ->
        []
    end
  end

  defp generate_handler(handler) do
    generate_handler_with_state_key(Map.has_key?(handler, :state_key), handler)
  end

  @doc """
  Generates code for multiple components (composition).
  """
  def generate_composition(components, layout \\ :vertical) do
    render_calls =
      Enum.map(components, fn {component, props, _state} ->
        generate_render_call(component, props)
      end)

    case layout do
      :horizontal ->
        """
        Raxol.UI.Flex.render(direction: :horizontal) do
        #{Enum.map_join(render_calls, "\n", &("  " <> &1))}
        end
        """

      :vertical ->
        """
        Raxol.UI.Flex.render(direction: :vertical) do
        #{Enum.map_join(render_calls, "\n", &("  " <> &1))}
        end
        """

      :grid ->
        """
        Raxol.UI.Grid.render(columns: 2) do
        #{Enum.map_join(render_calls, "\n", &("  " <> &1))}
        end
        """
    end
  end

  @doc """
  Generates a complete example application.
  """
  def generate_example_app(component, props, state) do
    """
    defmodule ExampleApp do
      use Raxol.Application

      alias #{component.module}

      @impl true
      def init(_args) do
        {:ok, #{format_map(state, 4)}}
      end

      @impl true
      def render(state) do
        #{generate_render_call(component, props)}
      end

      #{generate_event_handlers(component, state)}
    end

    # To run this example:
    # ExampleApp.start()
    """
  end

  @doc """
  Generates test code for the component.
  """
  def generate_test_code(component, props, state) do
    module_name = generate_module_name(component)

    """
    defmodule #{module_name}Test do
      use ExUnit.Case, async: true

      alias #{module_name}

      describe "#{String.downcase(component.name)}" do
        test "renders without crashing" do
          assert {:ok, _state} = #{module_name}.init(%{})
        end

        test "renders with props" do
          {:ok, state} = #{module_name}.init(%{})
          props = #{format_map(props, 6)}

          result = #{module_name}.render(state, props)
          assert is_binary(result) or is_list(result)
        end

        #{generate_event_tests(component, state)}
      end
    end
    """
  end

  defp generate_event_tests(component, state) do
    handlers = get_common_handlers(component, state)

    generate_handler_tests(Enum.empty?(handlers), handlers, component)
  end
end
