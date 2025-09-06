defmodule Raxol.Playground.PropertyEditor do
  @moduledoc """
  Interactive property editor for the component playground.

  Provides a user-friendly interface for editing component properties
  with type validation and real-time preview updates.
  """

  @doc """
  Renders an interactive property editor for a component.
  """
  def render_editor(component, current_props \\ %{})

  def render_editor(nil, _current_props),
    do: "No component selected. Use 'select <id>' to choose a component."

  def render_editor(component, current_props),
    do: render_component_editor(component, current_props)

  @doc """
  Validates and parses a property value based on its type.
  """
  def parse_property_value(component, prop_name, value_string) do
    prop_types = Map.get(component, :prop_types, %{})
    expected_type = Map.get(prop_types, String.to_atom(prop_name))

    case expected_type do
      :string ->
        {:ok, value_string}

      :integer ->
        case Integer.parse(value_string) do
          {int, ""} -> {:ok, int}
          _ -> {:error, "Must be an integer"}
        end

      :number ->
        case Float.parse(value_string) do
          {float, ""} ->
            {:ok, float}

          _ ->
            case Integer.parse(value_string) do
              {int, ""} -> {:ok, int}
              _ -> {:error, "Must be a number"}
            end
        end

      :boolean ->
        case String.downcase(value_string) do
          "true" -> {:ok, true}
          "false" -> {:ok, false}
          "1" -> {:ok, true}
          "0" -> {:ok, false}
          _ -> {:error, "Must be true or false"}
        end

      :atom ->
        parse_atom_value(value_string)

      :list ->
        parse_list_value(value_string)

      :map ->
        parse_map_value(value_string)

      _ ->
        # Try to intelligently parse the value
        intelligent_parse(value_string)
    end
  end

  @doc """
  Gets property suggestions and help text.
  """
  def get_property_help(component, prop_name) do
    prop_atom = String.to_atom(prop_name)
    prop_types = Map.get(component, :prop_types, %{})
    expected_type = Map.get(prop_types, prop_atom)
    default_value = get_in(component, [:default_props, prop_atom])

    help_text =
      case expected_type do
        :string ->
          "Text value (use quotes for strings with spaces)"

        :integer ->
          "Whole number (e.g., 1, 42, -5)"

        :number ->
          "Number (e.g., 1, 3.14, -2.5)"

        :boolean ->
          "true or false"

        :atom ->
          "Atom value (e.g., :primary, :large, :center)"

        :list ->
          "List of values (e.g., [\"item1\", \"item2\", \"item3\"])"

        :map ->
          "Map/object (e.g., %{key: \"value\", color: :red})"

        _ ->
          "Any value"
      end

    default_text = format_default_value(default_value)

    "#{help_text}#{default_text}"
  end

  @doc """
  Gets all available properties for a component with their current values.
  """
  def get_component_properties(component, current_props) do
    all_props = Map.merge(component.default_props || %{}, current_props)
    prop_types = Map.get(component, :prop_types, %{})

    Enum.map(all_props, fn {key, value} ->
      %{
        name: key,
        current_value: value,
        type: Map.get(prop_types, key, :any),
        help: get_property_help(component, to_string(key))
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Renders property suggestions for tab completion.
  """
  def get_property_suggestions(component, partial_name \\ "")

  def get_property_suggestions(nil, _partial_name), do: []

  def get_property_suggestions(component, partial_name) do
    all_prop_names =
      (component.default_props || %{})
      |> Map.keys()
      |> Enum.map(&to_string/1)

    filter_property_names(all_prop_names, partial_name)
    |> Enum.sort()
  end

  @doc """
  Renders the property editor UI in terminal format.
  """
  def render_terminal_editor(nil, _current_props) do
    """
    #{IO.ANSI.yellow()}No component selected#{IO.ANSI.reset()}

    Use 'select <component_id>' to choose a component first.
    """
  end

  def render_terminal_editor(component, current_props) do
    properties = get_component_properties(component, current_props)

    header = """

    #{IO.ANSI.bright()}Property Editor - #{component.name}#{IO.ANSI.reset()}
    #{String.duplicate("─", 50)}
    """

    render_properties_content(header, properties)
  end

  # Private Functions

  defp parse_atom_value(":" <> atom_name) do
    {:ok, String.to_atom(atom_name)}
  end

  defp parse_atom_value(value_string) do
    {:ok, String.to_atom(value_string)}
  end

  defp format_default_value(nil), do: ""

  defp format_default_value(default_value),
    do: " (default: #{inspect(default_value)})"

  defp filter_property_names(names, ""), do: names

  defp filter_property_names(names, partial) do
    Enum.filter(names, &String.starts_with?(&1, partial))
  end

  defp render_properties_content(header, []) do
    header <> "\n(No properties available)"
  end

  defp render_properties_content(header, properties) do
    property_list = Enum.map_join(properties, "\n", &format_property_line/1)

    footer = """

    #{IO.ANSI.light_black()}Commands:#{IO.ANSI.reset()}
      set <prop> <value>  - Update property
      reset <prop>        - Reset to default
      props               - Show this editor
      preview             - Update preview
    """

    header <> "\n" <> property_list <> footer
  end

  defp apply_parser_if_match(predicate, parser, trimmed) do
    case predicate.(trimmed) do
      true -> {:ok, parser.(trimmed)}
      false -> nil
    end
  end

  # Private Functions

  defp render_component_editor(component, current_props) do
    properties = get_component_properties(component, current_props)

    """
    #{IO.ANSI.bright()}#{component.name} Properties:#{IO.ANSI.reset()}
    #{String.duplicate("─", 40)}

    #{render_property_list(properties)}

    #{IO.ANSI.light_black()}Use 'set <prop> <value>' to update properties.#{IO.ANSI.reset()}
    """
  end

  defp render_property_list([]) do
    "  (No properties available)"
  end

  defp render_property_list(properties) do
    properties
    |> Enum.map(&format_property_line/1)
    |> Enum.join("\n")
  end

  defp format_property_line(prop) do
    name_width = 15
    padded_name = String.pad_trailing(to_string(prop.name), name_width)

    type_color =
      case prop.type do
        :string -> IO.ANSI.green()
        :integer -> IO.ANSI.blue()
        :number -> IO.ANSI.blue()
        :boolean -> IO.ANSI.yellow()
        :atom -> IO.ANSI.magenta()
        :list -> IO.ANSI.cyan()
        :map -> IO.ANSI.cyan()
        _ -> IO.ANSI.white()
      end

    value_display = format_value_display(prop.current_value)
    type_display = "#{type_color}#{prop.type}#{IO.ANSI.reset()}"

    "  #{padded_name} #{value_display} #{IO.ANSI.light_black()}(#{type_display})#{IO.ANSI.reset()}"
  end

  defp format_value_display(value)
       when is_binary(value) and byte_size(value) > 20 do
    truncated = String.slice(value, 0, 17) <> "..."
    "\"#{truncated}\""
  end

  defp format_value_display(value) when is_binary(value) do
    "\"#{value}\""
  end

  defp format_value_display(value) when is_atom(value) do
    ":#{value}"
  end

  defp format_value_display(value) when is_list(value) and length(value) <= 3 do
    inspect(value)
  end

  defp format_value_display(value) when is_list(value) do
    "[#{length(value)} items]"
  end

  defp format_value_display(value)
       when is_map(value) and map_size(value) <= 2 do
    inspect(value)
  end

  defp format_value_display(value) when is_map(value) do
    "%{#{map_size(value)} keys}"
  end

  defp format_value_display(value) do
    inspect(value)
  end

  defp parse_list_value(value_string) do
    # Simple list parsing for common cases
    trimmed = String.trim(value_string)
    parse_list_by_format(trimmed)
  end

  defp parse_list_by_format("[" <> _ = trimmed) when byte_size(trimmed) >= 2 do
    case String.ends_with?(trimmed, "]") do
      true -> parse_bracketed_list(trimmed)
      false -> parse_unbracketed_list(trimmed)
    end
  end

  defp parse_list_by_format(trimmed) when byte_size(trimmed) >= 2 do
    parse_unbracketed_list(trimmed)
  end

  defp parse_list_by_format(trimmed), do: {:ok, [trimmed]}

  defp parse_bracketed_list(trimmed) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           {result, _} = Code.eval_string(trimmed)
           validate_list_result(result)
         end) do
      {:ok, result} -> result
      {:error, _} -> parse_simple_list(trimmed)
    end
  end

  defp validate_list_result(result) when is_list(result), do: {:ok, result}
  defp validate_list_result(_), do: {:error, "Not a valid list"}

  defp parse_unbracketed_list(trimmed) do
    case String.contains?(trimmed, ",") do
      true ->
        items = String.split(trimmed, ",") |> Enum.map(&String.trim/1)
        {:ok, items}

      false ->
        {:ok, [trimmed]}
    end
  end

  defp parse_simple_list(list_string) do
    # Remove brackets and split by comma
    inner = String.slice(list_string, 1..-2//1) |> String.trim()
    parse_inner_list(inner)
  end

  defp parse_inner_list(""), do: {:ok, []}

  defp parse_inner_list(inner) do
    items = String.split(inner, ",") |> Enum.map(&String.trim/1)
    {:ok, items}
  end

  defp parse_map_value(value_string) do
    trimmed = String.trim(value_string)
    parse_map_string(trimmed)
  end

  defp parse_map_string("%{" <> _ = trimmed) do
    case String.ends_with?(trimmed, "}") do
      true -> eval_map_string(trimmed)
      false -> {:error, "Map must start with %{ and end with }"}
    end
  end

  defp parse_map_string(_),
    do: {:error, "Map must start with %{ and end with }"}

  defp eval_map_string(trimmed) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           {result, _} = Code.eval_string(trimmed)
           validate_map_result(result)
         end) do
      {:ok, result} -> result
      {:error, _} -> {:error, "Invalid map syntax"}
    end
  end

  defp validate_map_result(result) when is_map(result), do: {:ok, result}
  defp validate_map_result(_), do: {:error, "Not a valid map"}

  defp intelligent_parse(value_string) do
    trimmed = String.trim(value_string)
    parse_by_type(trimmed)
  end

  defp parse_by_type("true"), do: {:ok, true}
  defp parse_by_type("false"), do: {:ok, false}
  defp parse_by_type("nil"), do: {:ok, nil}

  defp parse_by_type(":" <> atom_name), do: {:ok, String.to_atom(atom_name)}

  defp parse_by_type(trimmed) do
    type_parsers = [
      {&integer_string?/1, &String.to_integer/1},
      {&float_string?/1, &String.to_float/1},
      {&list_string?/1, &parse_list_value/1},
      {&map_string?/1, &parse_map_value/1}
    ]

    Enum.find_value(type_parsers, {:ok, trimmed}, fn {predicate, parser} ->
      apply_parser_if_match(predicate, parser, trimmed)
    end)
  end

  defp integer_string?(str), do: String.match?(str, ~r/^\d+$/)
  defp float_string?(str), do: String.match?(str, ~r/^\d+\.\d+$/)
  defp list_string?(str), do: String.starts_with?(str, "[")
  defp map_string?(str), do: String.starts_with?(str, "%{")
end
