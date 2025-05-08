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
  # Alias the parent module
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
    # Extract layout attributes
    layout_attrs = %{}

    layout_attrs =
      if Map.has_key?(map, :padding),
        do: Map.put(layout_attrs, :padding, map.padding),
        else: layout_attrs

    layout_attrs =
      if Map.has_key?(map, :margin),
        do: Map.put(layout_attrs, :margin, map.margin),
        else: layout_attrs

    layout_attrs =
      if Map.has_key?(map, :width),
        do: Map.put(layout_attrs, :width, map.width),
        else: layout_attrs

    layout_attrs =
      if Map.has_key?(map, :height),
        do: Map.put(layout_attrs, :height, map.height),
        else: layout_attrs

    layout_attrs =
      if Map.has_key?(map, :alignment),
        do: Map.put(layout_attrs, :alignment, map.alignment),
        else: layout_attrs

    layout_attrs =
      if Map.has_key?(map, :overflow),
        do: Map.put(layout_attrs, :overflow, map.overflow),
        else: layout_attrs

    # Attributes for the main Style struct (excluding layout ones already handled)
    # and explicitly excluding border for now, as it's handled specially.
    style_specific_attrs =
      Map.drop(map, [
        :padding,
        :margin,
        :width,
        :height,
        :alignment,
        :overflow,
        :border
      ])

    # Create the initial Style struct with its specific attrs
    initial_style = struct(new(), style_specific_attrs)

    # Set the layout field
    final_style = %{initial_style | layout: Layout.new(layout_attrs)}

    # Handle border separately
    case Map.get(map, :border) do
      atom when is_atom(atom) ->
        border_struct =
          case atom do
            :none -> %Borders{style: :none, width: 0}
            :single -> %Borders{style: :solid, width: 1}
            :solid -> %Borders{style: :solid, width: 1}
            :double -> %Borders{style: :double, width: 1}
            _ -> Borders.new()
          end

        %{final_style | border: border_struct}

      # If it's already a Borders struct
      %Borders{} = border_struct ->
        %{final_style | border: border_struct}

      # No border or nil, or other map format for border (which might need more handling if supported)
      _ ->
        final_style
    end
  end

  @doc """
  Merges two styles, with the second overriding the first.
  """
  def merge(base, override) do
    %__MODULE__{
      layout: Layout.merge(base.layout, override.layout),
      border: Borders.merge(base.border, override.border),
      color: override.color || base.color,
      background: override.background || base.background,
      text_decoration:
        (base.text_decoration ++ override.text_decoration) |> Enum.uniq(),
      decorations: (base.decorations ++ override.decorations) |> Enum.uniq()
    }
  end

  @doc """
  Converts style properties to ANSI escape sequences (currently just numeric codes).
  """
  def to_ansi(style) do
    fg_ansi =
      if style.color,
        do: Colors.Color.to_ansi(style.color, :foreground),
        else: nil

    bg_ansi =
      if style.background,
        do: Colors.Color.to_ansi(style.background, :background),
        else: nil

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
    theme = theme || Raxol.Style.Theme.current()

    resolved_style =
      case style_def do
        %__MODULE__{} = style ->
          style

        atom when is_atom(atom) ->
          theme.styles[atom] || new()

        string when is_binary(string) ->
          theme.styles[String.to_atom(string)] || new()

        map when is_map(map) ->
          new(map)

        _ ->
          new()
      end

    # Apply theme variants if applicable
    apply_theme_variant(resolved_style, theme)
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
end
