defmodule Raxol.Terminal.Renderer do
  @moduledoc """
  Terminal renderer module.

  This module handles rendering of terminal output, including:
  - Character cell rendering
  - Text styling
  - Cursor rendering
  - Performance optimizations
  """

  alias Raxol.Terminal.{Cell, ScreenBuffer}

  @type t :: %__MODULE__{
          screen_buffer: ScreenBuffer.t(),
          cursor: {non_neg_integer(), non_neg_integer()} | nil,
          theme: map(),
          font_settings: map()
        }

  defstruct [
    :screen_buffer,
    :cursor,
    :theme,
    :font_settings
  ]

  @doc """
  Creates a new renderer with the given screen buffer.

  ## Examples

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> renderer.screen_buffer
      %ScreenBuffer{}
  """
  def new(screen_buffer, theme \\ %{}, font_settings \\ %{}) do
    %__MODULE__{
      screen_buffer: screen_buffer,
      cursor: nil,
      theme: theme,
      font_settings: font_settings
    }
  end

  @doc """
  Renders the screen buffer to a string.

  ## Examples

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> output = Renderer.render(renderer)
      iex> is_binary(output)
      true
  """
  def render(%__MODULE__{} = renderer) do
    renderer.screen_buffer.cells
    |> Enum.map(&render_row(&1, renderer))
    |> Enum.join("\n")
  end

  @doc """
  Sets the cursor position.

  ## Examples

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> renderer = Renderer.set_cursor(renderer, {10, 5})
      iex> renderer.cursor
      {10, 5}
  """
  def set_cursor(%__MODULE__{} = renderer, position) do
    %{renderer | cursor: position}
  end

  @doc """
  Clears the cursor position.

  ## Examples

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> renderer = Renderer.set_cursor(renderer, {10, 5})
      iex> renderer = Renderer.clear_cursor(renderer)
      iex> renderer.cursor
      nil
  """
  def clear_cursor(%__MODULE__{} = renderer) do
    %{renderer | cursor: nil}
  end

  @doc """
  Sets the theme.

  ## Examples

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> theme = %{foreground: %{default: "#FFFFFF"}}
      iex> renderer = Renderer.set_theme(renderer, theme)
      iex> renderer.theme
      %{foreground: %{default: "#FFFFFF"}}
  """
  def set_theme(%__MODULE__{} = renderer, theme) do
    %{renderer | theme: theme}
  end

  @doc """
  Sets the font settings.

  ## Examples

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> font_settings = %{family: "monospace", size: 14}
      iex> renderer = Renderer.set_font_settings(renderer, font_settings)
      iex> renderer.font_settings
      %{family: "monospace", size: 14}
  """
  def set_font_settings(%__MODULE__{} = renderer, font_settings) do
    %{renderer | font_settings: font_settings}
  end

  # Private functions

  defp render_row(row, renderer) do
    row
    |> Enum.map(&render_cell(&1, renderer))
    |> Enum.join("")
  end

  defp render_cell(cell, renderer) do
    char = Cell.get_char(cell)
    style_attrs = cell.style

    style = build_style(style_attrs, renderer.theme)

    # Escape basic HTML characters manually
    escaped_char = escape_html(char || " ")

    # Always wrap in a span, even if style is empty
    "<span style=\"#{style}\">#{escaped_char}</span>"
  end

  defp build_style(style_attrs, theme) do
    # Start with an empty list of styles
    initial_styles = []

    # Apply styles based on cell attributes, falling back to theme defaults for colors
    final_styles =
      initial_styles
      |> apply_color_style(:foreground, style_attrs, theme)
      |> apply_color_style(:background, style_attrs, theme)
      |> apply_flag_style(:bold, style_attrs, "font-weight", "bold")
      |> apply_flag_style(
        :underline,
        style_attrs,
        "text-decoration",
        "underline"
      )
      |> apply_flag_style(:italic, style_attrs, "font-style", "italic")

    # Add other flag-based styles here

    final_styles
    # Reverse to maintain original check order in string
    |> Enum.reverse()
    |> Enum.map(fn {property, value} -> "#{property}: #{value}" end)
    |> Enum.join("; ")
  end

  # Helper to apply color styles (foreground/background)
  defp apply_color_style(current_styles, key, style_attrs, theme) do
    # Determine color: Use cell's value if present, otherwise theme default
    color_name = Map.get(style_attrs, key) || :default
    color_value = get_theme_color(theme, key, color_name)

    # Determine CSS property name
    property_name =
      case key do
        :foreground -> "color"
        :background -> "background-color"
      end

    # Add the style if the color value is not nil (theme might not define defaults)
    if color_value != nil do
      [{property_name, color_value} | current_styles]
    else
      current_styles
    end
  end

  # Helper to apply flag-based styles (bold, italic, etc.)
  defp apply_flag_style(
         current_styles,
         key,
         style_attrs,
         property_name,
         property_value
       ) do
    if Map.get(style_attrs, key) do
      [{property_name, property_value} | current_styles]
    else
      current_styles
    end
  end

  defp get_theme_color(theme, type, name) do
    # Simpler fallback: If name is :default, get theme default. Otherwise get named color.
    # Return nil if not found anywhere.
    case name do
      :default ->
        get_in(theme, [type, :default])

      _ ->
        Map.get(theme[type] || %{}, name)
    end
  end

  # Simple HTML escaper
  defp escape_html(binary) when is_binary(binary) do
    binary
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
