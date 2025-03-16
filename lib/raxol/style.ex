defmodule Raxol.Style do
  @moduledoc """
  A CSS-like styling system for terminal UIs.
  
  This module provides a declarative way to style UI elements,
  inspired by Charm.sh's Lip Gloss. It handles colors, borders,
  padding, margin, and alignment.
  
  ## Example
  
  ```elixir
  import Raxol.Style
  
  # Create a style
  button_style = style([
    color: :blue,
    background: :white,
    padding: [1, 2],
    border: :rounded,
    width: 20,
    align: :center
  ])
  
  # Apply style to content
  styled_button = render(button_style, "Click Me")
  ```
  """
  
  @doc """
  Creates a new style with the given properties.
  
  ## Options
  
  * `:color` - Foreground color
  * `:background` - Background color
  * `:padding` - Padding around content as [top, right, bottom, left] or single value
  * `:margin` - Margin around content as [top, right, bottom, left] or single value
  * `:border` - Border style (:none, :normal, :rounded, :thick, :double)
  * `:width` - Fixed width of the content
  * `:height` - Fixed height of the content
  * `:align` - Horizontal alignment (:left, :center, :right)
  * `:vertical_align` - Vertical alignment (:top, :middle, :bottom)
  * `:bold` - Whether the text should be bold
  * `:italic` - Whether the text should be italic
  * `:underline` - Whether the text should be underlined
  
  ## Returns
  
  A style struct that can be used with `render/2`.
  
  ## Example
  
  ```elixir
  style([
    color: :green,
    background: :black,
    padding: [1, 2, 1, 2],
    border: :rounded
  ])
  ```
  """
  def style(properties \\ []) do
    %{
      color: Keyword.get(properties, :color, :default),
      background: Keyword.get(properties, :background, :default),
      padding: normalize_spacing(Keyword.get(properties, :padding, 0)),
      margin: normalize_spacing(Keyword.get(properties, :margin, 0)),
      border: Keyword.get(properties, :border, :none),
      width: Keyword.get(properties, :width, :auto),
      height: Keyword.get(properties, :height, :auto),
      align: Keyword.get(properties, :align, :left),
      vertical_align: Keyword.get(properties, :vertical_align, :top),
      bold: Keyword.get(properties, :bold, false),
      italic: Keyword.get(properties, :italic, false),
      underline: Keyword.get(properties, :underline, false)
    }
  end
  
  @doc """
  Renders content with the given style.
  
  ## Parameters
  
  * `style` - The style to apply
  * `content` - The content to style
  
  ## Returns
  
  A renderable element with the style applied.
  
  ## Example
  
  ```elixir
  button_style = style(color: :blue, background: :white, border: :rounded)
  render(button_style, "Click Me")
  ```
  """
  def render(style, content) when is_binary(content) do
    %{
      type: :styled_element,
      style: style,
      content: content
    }
  end
  
  def render(style, element) when is_map(element) do
    Map.put(element, :style, style)
  end
  
  @doc """
  Merges two styles, with the second style taking precedence.
  
  ## Parameters
  
  * `base` - The base style
  * `override` - The style to override with
  
  ## Returns
  
  A new style with the merged properties.
  
  ## Example
  
  ```elixir
  base_style = style(color: :blue, padding: 1)
  custom_style = style(color: :red)
  merged_style = merge(base_style, custom_style)
  # Result has color: :red, padding: 1
  ```
  """
  def merge(base, override) do
    Map.merge(base, override, fn
      # Special case for padding/margin to allow partial overrides
      :padding, v1, v2 -> merge_spacing(v1, v2)
      :margin, v1, v2 -> merge_spacing(v1, v2)
      _, _, v2 -> v2
    end)
  end
  
  @doc """
  Combines multiple styles into a single style.
  
  Styles are applied from left to right, with later styles
  taking precedence over earlier ones.
  
  ## Parameters
  
  * `styles` - List of styles to combine
  
  ## Returns
  
  A new style combining all the input styles.
  
  ## Example
  
  ```elixir
  base = style(color: :blue)
  highlight = style(background: :yellow)
  border = style(border: :rounded)
  combined = combine([base, highlight, border])
  ```
  """
  def combine(styles) when is_list(styles) do
    Enum.reduce(styles, style(), &merge/2)
  end
  
  # Private functions
  
  defp normalize_spacing(n) when is_integer(n), do: [n, n, n, n]
  defp normalize_spacing([v]), do: [v, v, v, v]
  defp normalize_spacing([v, h]), do: [v, h, v, h]
  defp normalize_spacing([t, r, b, l]), do: [t, r, b, l]
  defp normalize_spacing(_), do: [0, 0, 0, 0]
  
  defp merge_spacing(v1, v2) do
    Enum.zip_with(v1, v2, fn 
      _, 0 -> 0       # If the override is 0, use 0
      a, :auto -> a   # If the override is :auto, keep original
      _, b -> b       # Otherwise use the override
    end)
  end
end 