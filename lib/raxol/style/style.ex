defmodule Raxol.Style do
  @moduledoc """
  Defines style properties for terminal UI elements.
  """

  @type t :: %__MODULE__{
          layout: Raxol.Style.Layout.t(),
          border: Raxol.Style.Borders.t(),
          color: Raxol.Style.Colors.Color.t() | nil,
          background: Raxol.Style.Colors.Color.t() | nil,
          text_decoration: list(:underline | :strikethrough | :bold | :italic),
          decorations: list(atom)
        }

  defstruct layout: Raxol.Style.Layout.new(),
            border: Raxol.Style.Borders.new(),
            # Default color handled by renderer
            color: nil,
            # Default background handled by renderer
            background: nil,
            text_decoration: [],
            decorations: []

  alias Raxol.Style.{Layout, Borders}
  alias Raxol.Style.Colors

  @ansi_codes %{
    underline: 4,
    strikethrough: 9,
    bold: 1,
    italic: 3
  }

  @doc """
  Creates a new style with default values.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new style from a keyword list or map of attributes.
  """
  def new(attrs) when is_list(attrs) do
    Enum.reduce(attrs, new(), fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  def new(map) when is_map(map) do
    layout_attrs = extract_layout_attrs(map)
    style_attrs = extract_style_attrs(map)
    initial_style = struct(new(), style_attrs)
    final_style = %{initial_style | layout: Layout.new(layout_attrs)}
    handle_border(final_style, map)
  end

  defp extract_layout_attrs(map) do
    [:padding, :margin, :width, :height, :alignment, :overflow]
    |> Enum.reduce(%{}, fn key, acc ->
      maybe_put_key(Map.has_key?(map, key), acc, key, map[key])
    end)
  end

  defp extract_style_attrs(map) do
    Map.drop(map, [
      :padding,
      :margin,
      :width,
      :height,
      :alignment,
      :overflow,
      :border
    ])
  end

  defp handle_border(style, map) do
    case Map.get(map, :border) do
      atom when is_atom(atom) -> %{style | border: create_border_struct(atom)}
      %Borders{} = border -> %{style | border: border}
      _ -> style
    end
  end

  defp create_border_struct(atom) do
    case atom do
      :none -> %Borders{style: :none, width: 0}
      :single -> %Borders{style: :solid, width: 1}
      :solid -> %Borders{style: :solid, width: 1}
      :double -> %Borders{style: :double, width: 1}
      _ -> Borders.new()
    end
  end

  @doc """
  Merges two styles, with the second overriding the first.
  """
  def merge(style1, style2) do
    %__MODULE__{
      layout: Map.merge(style1.layout, style2.layout),
      border: Borders.merge(style1.border, style2.border),
      color: style2.color || style1.color,
      background: style2.background || style1.background,
      text_decoration:
        (style1.text_decoration ++ style2.text_decoration)
        |> Enum.uniq(),
      decorations:
        (style1.decorations ++ style2.decorations)
        |> Enum.uniq()
    }
  end

  @doc """
  Converts style properties to ANSI escape sequences (currently just numeric codes).
  """
  def to_ansi(style) do
    fg_ansi = maybe_convert_color_to_ansi(style.color, :foreground)
    bg_ansi = maybe_convert_color_to_ansi(style.background, :background)

    decoration_ansi =
      Enum.map(style.decorations, fn dec ->
        Map.get(@ansi_codes, dec)
      end)

    [
      fg_ansi,
      bg_ansi
      | decoration_ansi
    ]
    |> Enum.reject(&is_nil/1)

    # Actual sequence generation (e.g., IO.ANSI...) should happen closer to rendering
  end

  @doc """
  Resolves a style definition against the current theme.
  """
  def resolve(style_def, theme \\ nil) do
    theme = theme || Raxol.UI.Theming.Theme.current()
    resolved_style = resolve_style_definition(style_def, theme)
    apply_theme_variant(resolved_style, theme)
  end

  defp resolve_style_definition(style_def, theme) do
    case style_def do
      %__MODULE__{} = style ->
        style

      atom when is_atom(atom) ->
        lookup_theme_style(atom, theme)

      string when is_binary(string) ->
        lookup_theme_style(String.to_atom(string), theme)

      map when is_map(map) ->
        new(map)

      _ ->
        new()
    end
  end

  defp lookup_theme_style(key, theme) do
    theme.styles[key] || new()
  end

  @doc """
  Apply responsive styling based on terminal dimensions.
  """
  def apply_responsive(style, width, height) do
    responsive_rules =
      style.responsive
      |> Enum.filter(fn {constraint, _} ->
        evaluate_constraint(constraint, width, height)
      end)
      |> Enum.map(fn {_, style_override} -> style_override end)

    Enum.reduce(responsive_rules, style, &merge/2)
  end

  @doc """
  Apply component-specific styling.
  """
  def apply_component_specific(style, component_type) do
    case Map.get(style.component_specific, component_type) do
      nil -> style
      component_style -> merge(style, component_style)
    end
  end

  # Private helpers

  defp apply_theme_variant(style, theme) do
    case Map.get(theme.variants, style.theme_variant) do
      nil -> style
      variant -> merge(style, variant)
    end
  end

  defp evaluate_constraint(constraint, width, height) do
    case constraint do
      {:min_width, min} -> width >= min
      {:max_width, max} -> width <= max
      {:min_height, min} -> height >= min
      {:max_height, max} -> height <= max
      _ -> false
    end
  end

  defp maybe_put_key(true, acc, key, value), do: Map.put(acc, key, value)
  defp maybe_put_key(false, acc, _key, _value), do: acc

  defp maybe_convert_color_to_ansi(nil, _type), do: nil

  defp maybe_convert_color_to_ansi(color, type),
    do: Colors.Color.to_ansi(color, type)
end
