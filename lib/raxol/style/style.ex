defmodule Raxol.Style do
  @moduledoc """
  The core styling system for Raxol.

  Provides a CSS-like interface for styling terminal UI elements with
  support for:
  * Colors (16-color, 256-color, true-color)
  * Text attributes (bold, italic, underline)
  * Layout (padding, margin, alignment)
  * Borders and backgrounds
  * Theme support
  * Responsive styling
  * Component-specific style mapping
  """

  alias Raxol.Style.{Colors, Layout, Borders}

  @type t :: %__MODULE__{
    color: Colors.color(),
    background: Colors.color(),
    attributes: [atom()],
    layout: Layout.t(),
    border: Borders.t(),
    theme_variant: atom(),
    responsive: map(),
    component_specific: map()
  }

  defstruct color: nil,
            background: nil,
            attributes: [],
            layout: %Layout{},
            border: %Borders{},
            theme_variant: :default,
            responsive: %{},
            component_specific: %{}

  @doc """
  Creates a new style with default values.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new style with the specified values.
  """
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Merges two styles, with the second taking precedence.
  """
  def merge(%__MODULE__{} = base, %__MODULE__{} = override) do
    %__MODULE__{
      color: override.color || base.color,
      background: override.background || base.background,
      attributes: Enum.uniq(base.attributes ++ override.attributes),
      layout: Layout.merge(base.layout, override.layout),
      border: Borders.merge(base.border, override.border),
      theme_variant: override.theme_variant || base.theme_variant,
      responsive: Map.merge(base.responsive, override.responsive),
      component_specific: Map.merge(base.component_specific, override.component_specific)
    }
  end

  @doc """
  Converts a style to ANSI escape codes.
  """
  def to_ansi(%__MODULE__{} = style) do
    [
      Colors.to_ansi(style.color, :foreground),
      Colors.to_ansi(style.background, :background),
      attributes_to_ansi(style.attributes)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join()
  end

  @doc """
  Resolves a style definition against the current theme.
  """
  def resolve(style_def, theme \\ nil) do
    theme = theme || Raxol.Style.Theme.current()
    
    resolved_style = case style_def do
      %__MODULE__{} = style -> style
      atom when is_atom(atom) -> theme.styles[atom] || new()
      string when is_binary(string) -> theme.styles[String.to_atom(string)] || new()
      map when is_map(map) -> new(map)
      _ -> new()
    end
    
    # Apply theme variants if applicable
    apply_theme_variant(resolved_style, theme)
  end
  
  @doc """
  Apply responsive styling based on terminal dimensions.
  """
  def apply_responsive(style, width, height) do
    responsive_rules = style.responsive
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

  defp attributes_to_ansi(attrs) do
    attrs
    |> Enum.map(&attribute_to_ansi/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join()
  end
  
  defp attribute_to_ansi(:bold), do: "\e[1m"
  defp attribute_to_ansi(:italic), do: "\e[3m"
  defp attribute_to_ansi(:underline), do: "\e[4m"
  defp attribute_to_ansi(:blink), do: "\e[5m"
  defp attribute_to_ansi(:reverse), do: "\e[7m"
  defp attribute_to_ansi(_), do: nil
  
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