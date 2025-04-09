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
    attributes = cell.attributes

    style = build_style(attributes, renderer.theme)

    if style == "" do
      char
    else
      "<span style=\"#{style}\">#{char}</span>"
    end
  end

  defp build_style(attributes, theme) do
    styles = []

    styles = if foreground = Map.get(attributes, :foreground) do
      color = get_theme_color(theme, :foreground, foreground)
      [{"color", color} | styles]
    else
      styles
    end

    styles = if background = Map.get(attributes, :background) do
      color = get_theme_color(theme, :background, background)
      [{"background-color", color} | styles]
    else
      styles
    end

    styles = if Map.get(attributes, :bold) do
      [{"font-weight", "bold"} | styles]
    else
      styles
    end

    styles = if Map.get(attributes, :underline) do
      [{"text-decoration", "underline"} | styles]
    else
      styles
    end

    styles = if Map.get(attributes, :italic) do
      [{"font-style", "italic"} | styles]
    else
      styles
    end

    styles
    |> Enum.map(fn {property, value} -> "#{property}: #{value}" end)
    |> Enum.join("; ")
  end

  defp get_theme_color(theme, type, name) do
    case name do
      :default -> get_in(theme, [type, :default]) || "#FFFFFF"
      _ -> Map.get(theme[type], name) || get_in(theme, [type, :default]) || "#FFFFFF"
    end
  end
end
