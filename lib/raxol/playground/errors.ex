defmodule Raxol.Playground.Errors do
  @moduledoc """
  Helpful error messages with suggestions for the playground.

  Provides rich error formatting with:
  - Jaro distance-based "Did you mean?" suggestions
  - Available options listing
  - Contextual hints for common mistakes

  ## Examples

      iex> Errors.component_not_found("buton", catalog)
      {:error, %{
        type: :component_not_found,
        id: "buton",
        suggestion: "button",
        message: "Component 'buton' not found.\\n\\nDid you mean: button?"
      }}
  """

  # ============================================================================
  # Component Errors
  # ============================================================================

  @doc """
  Generates a helpful error when a component is not found.

  Uses Jaro distance to suggest similar component names.

  ## Examples

      iex> Errors.component_not_found("buton", [%{id: "button"}, %{id: "table"}])
      {:error, %{type: :component_not_found, id: "buton", suggestion: "button", ...}}
  """
  @spec component_not_found(String.t(), list(map())) :: {:error, map()}
  def component_not_found(id, catalog) do
    component_ids = Enum.map(catalog, & &1.id)
    similar = find_similar(id, component_ids)
    available = Enum.take(component_ids, 10)

    {:error,
     %{
       type: :component_not_found,
       id: id,
       suggestion: List.first(similar),
       available: available,
       message: format_not_found(id, similar, available)
     }}
  end

  @doc """
  Generates an error for invalid prop values.

  ## Examples

      iex> Errors.invalid_prop("button", :variant, "primary", [:atom])
      {:error, %{type: :invalid_prop, property: :variant, ...}}
  """
  @spec invalid_prop(String.t(), atom(), any(), list()) :: {:error, map()}
  def invalid_prop(component_id, prop, value, expected_types) do
    {:error,
     %{
       type: :invalid_prop,
       component: component_id,
       property: prop,
       got: value,
       got_type: type_of(value),
       expected: expected_types,
       message: format_invalid_prop(component_id, prop, value, expected_types)
     }}
  end

  @doc """
  Generates an error for unknown props.

  ## Examples

      iex> Errors.unknown_prop("button", :colour, [:label, :variant, :disabled])
      {:error, %{type: :unknown_prop, property: :colour, suggestion: nil, ...}}
  """
  @spec unknown_prop(String.t(), atom(), list(atom())) :: {:error, map()}
  def unknown_prop(component_id, prop, valid_props) do
    prop_strings = Enum.map(valid_props, &Atom.to_string/1)
    similar = find_similar(Atom.to_string(prop), prop_strings)

    suggestion =
      case similar do
        [first | _] -> String.to_atom(first)
        [] -> nil
      end

    {:error,
     %{
       type: :unknown_prop,
       component: component_id,
       property: prop,
       suggestion: suggestion,
       valid_props: valid_props,
       message: format_unknown_prop(component_id, prop, suggestion, valid_props)
     }}
  end

  @doc """
  Generates an error for missing required props.

  ## Examples

      iex> Errors.missing_required_prop("button", :label)
      {:error, %{type: :missing_required_prop, property: :label, ...}}
  """
  @spec missing_required_prop(String.t(), atom()) :: {:error, map()}
  def missing_required_prop(component_id, prop) do
    {:error,
     %{
       type: :missing_required_prop,
       component: component_id,
       property: prop,
       message: format_missing_prop(component_id, prop)
     }}
  end

  # ============================================================================
  # Theme Errors
  # ============================================================================

  @doc """
  Generates an error for unknown themes.

  ## Examples

      iex> Errors.theme_not_found(:darcula, [:dracula, :nord, :monokai])
      {:error, %{type: :theme_not_found, theme: :darcula, suggestion: :dracula, ...}}
  """
  @spec theme_not_found(atom(), list(atom())) :: {:error, map()}
  def theme_not_found(theme, available_themes) do
    theme_strings = Enum.map(available_themes, &Atom.to_string/1)
    similar = find_similar(Atom.to_string(theme), theme_strings)

    suggestion =
      case similar do
        [first | _] -> String.to_atom(first)
        [] -> nil
      end

    {:error,
     %{
       type: :theme_not_found,
       theme: theme,
       suggestion: suggestion,
       available: available_themes,
       message: format_theme_not_found(theme, suggestion, available_themes)
     }}
  end

  # ============================================================================
  # Export Errors
  # ============================================================================

  @doc """
  Generates an error for unknown export formats.

  ## Examples

      iex> Errors.invalid_export_format(:json, [:component, :standalone, :example])
      {:error, %{type: :invalid_export_format, format: :json, ...}}
  """
  @spec invalid_export_format(atom(), list(atom())) :: {:error, map()}
  def invalid_export_format(format, valid_formats) do
    {:error,
     %{
       type: :invalid_export_format,
       format: format,
       valid_formats: valid_formats,
       message: format_invalid_export(format, valid_formats)
     }}
  end

  # ============================================================================
  # Error Formatting Helpers
  # ============================================================================

  @doc """
  Formats an error map into a human-readable string.

  ## Examples

      iex> Errors.format_error({:error, %{message: "Component not found"}})
      "Component not found"
  """
  @spec format_error({:error, map()}) :: String.t()
  def format_error({:error, %{message: message}}), do: message

  def format_error({:error, reason}) when is_atom(reason),
    do: humanize_atom(reason)

  def format_error({:error, reason}) when is_binary(reason), do: reason

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp find_similar(target, candidates) do
    candidates
    |> Enum.map(
      &{&1, String.jaro_distance(String.downcase(target), String.downcase(&1))}
    )
    |> Enum.filter(fn {_, score} -> score > 0.6 end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.map(&elem(&1, 0))
    |> Enum.take(3)
  end

  defp format_not_found(id, similar, available) do
    base = "Component '#{id}' not found."

    suggestion_text =
      case similar do
        [] -> ""
        [one] -> "\n\nDid you mean: #{one}?"
        many -> "\n\nDid you mean one of: #{Enum.join(many, ", ")}?"
      end

    available_text =
      case available do
        [] -> ""
        list -> "\n\nAvailable components: #{Enum.join(list, ", ")}"
      end

    base <> suggestion_text <> available_text
  end

  defp format_invalid_prop(component_id, prop, value, expected_types) do
    got_type = type_of(value)
    expected_str = Enum.map_join(expected_types, " or ", &inspect/1)

    """
    Invalid value for #{component_id}.#{prop}

    Got: #{inspect(value)} (#{got_type})
    Expected: #{expected_str}

    Hint: #{hint_for_type(expected_types, value)}
    """
    |> String.trim()
  end

  defp format_unknown_prop(component_id, prop, suggestion, valid_props) do
    base = "Unknown property '#{prop}' for component '#{component_id}'."

    suggestion_text =
      case suggestion do
        nil -> ""
        s -> "\n\nDid you mean: #{s}?"
      end

    valid_text =
      "\n\nValid properties: #{Enum.map_join(valid_props, ", ", &inspect/1)}"

    base <> suggestion_text <> valid_text
  end

  defp format_missing_prop(component_id, prop) do
    """
    Missing required property '#{prop}' for component '#{component_id}'.

    Add it with: Builder.prop(builder, #{inspect(prop)}, value)
    """
    |> String.trim()
  end

  defp format_theme_not_found(theme, suggestion, available) do
    base = "Theme '#{theme}' not found."

    suggestion_text =
      case suggestion do
        nil -> ""
        s -> "\n\nDid you mean: #{s}?"
      end

    available_text =
      "\n\nAvailable themes: #{Enum.map_join(available, ", ", &inspect/1)}"

    base <> suggestion_text <> available_text
  end

  defp format_invalid_export(format, valid_formats) do
    """
    Invalid export format '#{format}'.

    Valid formats: #{Enum.map_join(valid_formats, ", ", &inspect/1)}

    Example: Builder.export(builder, :component)
    """
    |> String.trim()
  end

  defp type_of(value) when is_binary(value), do: :string
  defp type_of(value) when is_atom(value), do: :atom
  defp type_of(value) when is_integer(value), do: :integer
  defp type_of(value) when is_float(value), do: :float
  defp type_of(value) when is_boolean(value), do: :boolean
  defp type_of(value) when is_list(value), do: :list
  defp type_of(value) when is_map(value), do: :map
  defp type_of(value) when is_function(value), do: :function
  defp type_of(_value), do: :unknown

  defp hint_for_type(expected, value) do
    cond do
      :atom in expected and is_binary(value) ->
        "Try using an atom instead: :#{value}"

      :string in expected and is_atom(value) ->
        "Try using a string instead: \"#{value}\""

      :integer in expected and is_binary(value) ->
        case Integer.parse(value) do
          {n, ""} -> "Try using an integer instead: #{n}"
          _ -> "Provide an integer value"
        end

      :boolean in expected and value in ["true", "false"] ->
        "Try using a boolean instead: #{value}"

      true ->
        "Check the component documentation for valid values"
    end
  end

  defp humanize_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
