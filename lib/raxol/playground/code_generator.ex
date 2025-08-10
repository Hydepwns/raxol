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
      if include_imports do
        """
        defmodule #{module_name} do
          use Raxol.Component
          #{generate_aliases(component)}
        """
      else
        """
        defmodule #{module_name} do
          use Raxol.Component
        """
      end

    init_function =
      if map_size(state) > 0 do
        """
          
          @impl true
          def init(_props) do
            {:ok, #{format_map(state, 4)}}
          end
        """
      else
        ""
      end

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
    imports =
      if include_imports do
        "alias #{component.module}\n\n"
      else
        ""
      end

    """
    #{imports}#{generate_render_call(component, props)}
    """
  end

  defp generate_example_code(component, props, state, include_imports) do
    imports =
      if include_imports do
        """
        # Add to your component or view:
        alias #{component.module}

        """
      else
        ""
      end

    state_comment =
      if map_size(state) > 0 do
        """
        # Component state (managed internally):
        # #{format_map(state, 0)}

        """
      else
        ""
      end

    """
    #{imports}# Example usage:
    #{state_comment}#{generate_render_call(component, props)}
    """
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

    if map_size(props) == 0 do
      "#{module_alias}.render()"
    else
      formatted_props = format_props(props)

      if String.contains?(formatted_props, "\n") do
        """
        #{module_alias}.render(#{formatted_props})
        """
      else
        "#{module_alias}.render(#{formatted_props})"
      end
    end
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
    |> Enum.map(fn {key, value} -> "#{key}: #{format_value(value)}" end)
    |> Enum.join(", ")
  end

  defp format_props(props) do
    formatted_pairs =
      props
      |> Map.to_list()
      |> Enum.map(fn {key, value} -> "  #{key}: #{format_value(value)}" end)
      |> Enum.join(",\n")

    "\n#{formatted_pairs}\n"
  end

  defp format_map(map, _indent) when map_size(map) == 0 do
    "%{}"
  end

  defp format_map(map, _indent) when map_size(map) <= 2 do
    pairs =
      map
      |> Map.to_list()
      |> Enum.map(fn {key, value} -> "#{key}: #{format_value(value)}" end)
      |> Enum.join(", ")

    "%{#{pairs}}"
  end

  defp format_map(map, indent) do
    indent_str = String.duplicate(" ", indent)
    inner_indent = String.duplicate(" ", indent + 2)

    formatted_pairs =
      map
      |> Map.to_list()
      |> Enum.map(fn {key, value} ->
        "#{inner_indent}#{key}: #{format_value(value)}"
      end)
      |> Enum.join(",\n")

    "%{\n#{formatted_pairs}\n#{indent_str}}"
  end

  defp format_value(value) when is_binary(value) do
    if String.contains?(value, "\"") do
      ~s('#{value}')
    else
      ~s("#{value}")
    end
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
    if Enum.all?(value, &is_binary/1) and length(value) <= 5 do
      formatted_items = Enum.map(value, &format_value/1)
      "[#{Enum.join(formatted_items, ", ")}]"
    else
      formatted_items =
        value
        |> Enum.map(&format_value/1)
        |> Enum.map(&("  " <> &1))
        |> Enum.join(",\n")

      "[\n#{formatted_items}\n]"
    end
  end

  defp format_value(value) when is_map(value) do
    format_map(value, 0)
  end

  defp format_value(value) do
    inspect(value)
  end

  defp generate_event_handlers(component, state) do
    handlers = get_common_handlers(component, state)

    if Enum.empty?(handlers) do
      ""
    else
      handler_functions = Enum.map(handlers, &generate_handler/1)
      "\n" <> Enum.join(handler_functions, "\n")
    end
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
    if Map.has_key?(handler, :state_key) do
      """

      @impl true
      def handle_event(#{handler.event}, state) do
        # #{handler.action}
        {:ok, %{state | #{handler.state_key}: not state.#{handler.state_key}}}
      end
      """
    else
      """

      @impl true
      def handle_event(#{handler.event}, state) do
        # #{handler.action}
        # Add your logic here
        {:ok, state}
      end
      """
    end
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

    if Enum.empty?(handlers) do
      ""
    else
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
  end
end
