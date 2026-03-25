defmodule Raxol.Config.Schema.Documentation do
  @moduledoc """
  Documentation generation for Raxol configuration schemas.
  """

  @compile {:no_warn_undefined, Raxol.Config.Schema.Definitions}

  @doc """
  Generates documentation for all configuration options.
  Returns a list of documentation strings, one per field.
  """
  def generate_docs(schema) do
    schema
    |> generate_docs_for_schema([])
    |> Enum.join("\n\n")
  end

  defp generate_docs_for_schema(schema, path) when is_map(schema) do
    schema
    |> Enum.flat_map(fn {key, value} ->
      current_path = path ++ [key]
      generate_doc_for_value(Map.has_key?(value, :type), current_path, value)
    end)
  end

  defp generate_doc_for_value(true, current_path, value),
    do: [generate_field_doc(current_path, value)]

  defp generate_doc_for_value(false, current_path, value),
    do: generate_docs_for_schema(value, current_path)

  defp generate_field_doc(path, field_schema) do
    path_str = Enum.join(path, ".")
    type_str = format_type(field_schema.type)
    default_str = inspect(field_schema.default)

    """
    ### #{path_str}

    **Type:** `#{type_str}`
    **Default:** `#{default_str}`
    **Required:** #{field_schema.required}

    #{field_schema.description}

    #{format_constraints(Map.get(field_schema, :constraints, []))}
    """
  end

  defp format_type(type) do
    case type do
      {:enum, values} -> "enum[#{Enum.join(values, ", ")}]"
      {:list, item_type} -> "list[#{format_type(item_type)}]"
      {:map, value_type} -> "map[#{format_type(value_type)}]"
      other -> to_string(other)
    end
  end

  defp format_constraints([]), do: ""

  defp format_constraints(constraints) do
    constraint_strs =
      Enum.map(constraints, fn
        {:min, value} -> "Minimum: #{value}"
        {:max, value} -> "Maximum: #{value}"
        {:min_length, value} -> "Minimum length: #{value}"
        {:max_length, value} -> "Maximum length: #{value}"
        {:format, _regex} -> "Must match format"
        {:custom, _} -> "Custom validation"
      end)

    "**Constraints:**\n" <> Enum.map_join(constraint_strs, "\n", &"- #{&1}")
  end
end
