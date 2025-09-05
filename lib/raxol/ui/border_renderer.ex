defmodule Raxol.UI.BorderRenderer do
  @moduledoc """
  Handles border rendering logic and border character definitions.
  """

  @doc """
  Gets border characters for a given border style.
  """
  def get_border_chars(:single) do
    %{
      top_left: "┌",
      top_right: "┐",
      bottom_left: "└",
      bottom_right: "┘",
      horizontal: "─",
      vertical: "│"
    }
  end

  def get_border_chars(:double) do
    %{
      top_left: "╔",
      top_right: "╗",
      bottom_left: "╚",
      bottom_right: "╝",
      horizontal: "═",
      vertical: "║"
    }
  end

  def get_border_chars(:rounded) do
    %{
      top_left: "╭",
      top_right: "╮",
      bottom_left: "╰",
      bottom_right: "╯",
      horizontal: "─",
      vertical: "│"
    }
  end

  # Fallback for unknown or :none
  def get_border_chars(_) do
    %{
      top_left: " ",
      top_right: " ",
      bottom_left: " ",
      bottom_right: " ",
      horizontal: " ",
      vertical: " "
    }
  end

  @doc """
  Renders box borders with proper styling.
  """
  def render_box_borders(x, y, 1, 1, _border_chars, style) do
    {fg, bg, style_attrs} = extract_style_attributes(style)
    [{x, y, " ", fg, bg, style_attrs}]
  end

  def render_box_borders(x, y, width, height, border_chars, style) do
    {fg, bg, style_attrs} = extract_style_attributes(style)

    generate_border_cells(
      x,
      y,
      width,
      height,
      border_chars,
      fg,
      bg,
      style_attrs
    )
  end

  defp extract_style_attributes(style) do
    fg = Map.get(style, :fg) || Map.get(style, :foreground, :white)
    bg = Map.get(style, :bg) || Map.get(style, :background, :black)

    border_style = Map.get(style, :border_style, :single)

    border_type =
      case border_style do
        %{type: type} -> type
        type when is_atom(type) -> type
        _ -> :single
      end

    style_attrs =
      case border_type do
        :none -> []
        _ -> [border_type]
      end

    {fg, bg, style_attrs}
  end

  defp generate_border_cells(
         x,
         y,
         width,
         height,
         border_chars,
         fg,
         bg,
         style_attrs
       ) do
    position = %{x: x, y: y, width: width, height: height}

    for i <- 0..(width - 1),
        j <- 0..(height - 1),
        i == 0 or i == width - 1 or j == 0 or j == height - 1 do
      get_border_cell(i, j, position, border_chars, fg, bg, style_attrs)
    end
  end

  defp get_border_cell(
         i,
         j,
         %{x: x, y: y, width: width, height: height},
         border_chars,
         fg,
         bg,
         style_attrs
       ) do
    {char, cell_x, cell_y} =
      get_border_char_and_position(i, j, x, y, width, height, border_chars)

    {cell_x, cell_y, char, fg, bg, style_attrs}
  end

  defp get_border_char_and_position(i, j, x, y, width, height, border_chars) do
    char = get_border_char(i, j, width, height, border_chars)
    {char_x, char_y} = get_border_position(i, j, x, y, width, height)
    {char, char_x, char_y}
  end

  defp get_border_char(i, j, width, height, border_chars) do
    case {i, j, width, height} do
      {0, 0, _, _} ->
        border_chars.top_left

      {i, 0, width, _} when i == width - 1 ->
        border_chars.top_right

      {0, j, _, height} when j == height - 1 ->
        border_chars.bottom_left

      {i, j, width, height} when i == width - 1 and j == height - 1 ->
        border_chars.bottom_right

      {_, j, _, height} when j == 0 or j == height - 1 ->
        border_chars.horizontal

      _ ->
        border_chars.vertical
    end
  end

  defp get_border_position(i, j, x, y, width, height) do
    char_x = get_border_x_position(i, x, width)
    char_y = get_border_y_position(j, y, height)
    {char_x, char_y}
  end

  defp get_border_x_position(i, x, width) when i == width - 1, do: x + width - 1
  defp get_border_x_position(i, x, _width), do: x + i

  defp get_border_y_position(j, y, height) when j == height - 1,
    do: y + height - 1

  defp get_border_y_position(j, y, _height), do: y + j

  @doc """
  Renders horizontal line.
  """
  def render_horizontal_line(x, y, width, char, style, _theme) do
    # Resolve colors properly
    fg = Map.get(style, :fg) || Map.get(style, :foreground, :white)
    bg = Map.get(style, :bg) || Map.get(style, :background, :black)

    for i <- 1..(width - 2) do
      {x + i, y, char, fg, bg, []}
    end
  end

  @doc """
  Renders vertical line.
  """
  def render_vertical_line(x, y, height, char, style, _theme) do
    # Resolve colors properly
    fg = Map.get(style, :fg) || Map.get(style, :foreground, :white)
    bg = Map.get(style, :bg) || Map.get(style, :background, :black)

    for i <- 1..(height - 2) do
      {x, y + i, char, fg, bg, []}
    end
  end

  @doc """
  Renders empty box with no borders.
  """
  def render_empty_box(x, y, width, height, style) do
    # Resolve colors properly
    fg = Map.get(style, :fg) || Map.get(style, :foreground, :white)
    bg = Map.get(style, :bg) || Map.get(style, :background, :black)

    # Empty box with no border style
    for i <- 0..(width - 1), j <- 0..(height - 1) do
      {x + i, y + j, " ", fg, bg, []}
    end
  end
end
