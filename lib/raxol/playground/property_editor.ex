defmodule Raxol.Playground.PropertyEditor do
  @moduledoc """
  Interactive property editor for the component playground.

  Provides a user-friendly interface for editing component properties
  with type validation and real-time preview updates.
  """

  @doc """
  Renders an interactive property editor for a component.
  """
  def render_editor(component, current_props \\ %{}) do
    if is_nil(component) do
      "No component selected. Use 'select <id>' to choose a component."
    else
      render_component_editor(component, current_props)
    end
  end

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
        if String.starts_with?(value_string, ":") do
          atom_name = String.slice(value_string, 1..-1//1)
          {:ok, String.to_atom(atom_name)}
        else
          {:ok, String.to_atom(value_string)}
        end

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

    default_text =
      if default_value do
        " (default: #{inspect(default_value)})"
      else
        ""
      end

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
  def get_property_suggestions(component, partial_name \\ "") do
    if is_nil(component) do
      []
    else
      all_prop_names =
        (component.default_props || %{})
        |> Map.keys()
        |> Enum.map(&to_string/1)

      if partial_name == "" do
        all_prop_names
      else
        Enum.filter(all_prop_names, &String.starts_with?(&1, partial_name))
      end
      |> Enum.sort()
    end
  end

  @doc """
  Renders the property editor UI in terminal format.
  """
  def render_terminal_editor(component, current_props) do
    if is_nil(component) do
      """
      #{IO.ANSI.yellow()}No component selected#{IO.ANSI.reset()}

      Use 'select <component_id>' to choose a component first.
      """
    else
      properties = get_component_properties(component, current_props)

      header = """

      #{IO.ANSI.bright()}Property Editor - #{component.name}#{IO.ANSI.reset()}
      #{String.duplicate("─", 50)}
      """

      if Enum.empty?(properties) do
        header <> "\n(No properties available)"
      else
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

  defp render_property_list(properties) when length(properties) == 0 do
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

  defp format_value_display(value) when is_binary(value) do
    if String.length(value) > 20 do
      truncated = String.slice(value, 0, 17) <> "..."
      "\"#{truncated}\""
    else
      "\"#{value}\""
    end
  end

  defp format_value_display(value) when is_atom(value) do
    ":#{value}"
  end

  defp format_value_display(value) when is_list(value) do
    if length(value) <= 3 do
      inspect(value)
    else
      "[#{length(value)} items]"
    end
  end

  defp format_value_display(value) when is_map(value) do
    count = map_size(value)

    if count <= 2 do
      inspect(value)
    else
      "%{#{count} keys}"
    end
  end

  defp format_value_display(value) do
    inspect(value)
  end

  defp parse_list_value(value_string) do
    # Simple list parsing for common cases
    trimmed = String.trim(value_string)

    cond do
      String.starts_with?(trimmed, "[") and String.ends_with?(trimmed, "]") ->
        # Try to parse as a list literal
        try do
          {result, _} = Code.eval_string(trimmed)

          if is_list(result) do
            {:ok, result}
          else
            {:error, "Not a valid list"}
          end
        rescue
          _ -> parse_simple_list(trimmed)
        end

      String.contains?(trimmed, ",") ->
        # Parse comma-separated values
        items = String.split(trimmed, ",") |> Enum.map(&String.trim/1)
        {:ok, items}

      true ->
        # Single item list
        {:ok, [trimmed]}
    end
  end

  defp parse_simple_list(list_string) do
    # Remove brackets and split by comma
    inner = String.slice(list_string, 1..-2//1) |> String.trim()

    if inner == "" do
      {:ok, []}
    else
      items = String.split(inner, ",") |> Enum.map(&String.trim/1)
      {:ok, items}
    end
  end

  defp parse_map_value(value_string) do
    trimmed = String.trim(value_string)

    if String.starts_with?(trimmed, "%{") and String.ends_with?(trimmed, "}") do
      try do
        {result, _} = Code.eval_string(trimmed)

        if is_map(result) do
          {:ok, result}
        else
          {:error, "Not a valid map"}
        end
      rescue
        _ -> {:error, "Invalid map syntax"}
      end
    else
      {:error, "Map must start with %{ and end with }"}
    end
  end

  defp intelligent_parse(value_string) do
    trimmed = String.trim(value_string)

    cond do
      trimmed == "true" ->
        {:ok, true}

      trimmed == "false" ->
        {:ok, false}

      trimmed == "nil" ->
        {:ok, nil}

      String.starts_with?(trimmed, ":") ->
        {:ok, String.to_atom(String.slice(trimmed, 1..-1//1))}

      String.match?(trimmed, ~r/^\d+$/) ->
        {:ok, String.to_integer(trimmed)}

      String.match?(trimmed, ~r/^\d+\.\d+$/) ->
        {:ok, String.to_float(trimmed)}

      String.starts_with?(trimmed, "[") ->
        parse_list_value(trimmed)

      String.starts_with?(trimmed, "%{") ->
        parse_map_value(trimmed)

      # Default to string
      true ->
        {:ok, trimmed}
    end
  end
end
