defmodule Raxol.Core.Box do
  @moduledoc """
  Box drawing and line rendering utilities for terminal UIs.

  This module provides functions for drawing boxes, lines, and filled areas
  using Unicode box drawing characters.

  ## Supported Box Styles

  - `:single` - Single line box drawing (─│┌┐└┘)
  - `:double` - Double line box drawing (═║╔╗╚╝)
  - `:rounded` - Rounded corners (─│╭╮╰╯)
  - `:heavy` - Heavy/bold lines (━┃┏┓┗┛)
  - `:dashed` - Dashed lines (╌╎┌┐└┘)

  ## Examples

      # Draw a simple box
      buffer = Raxol.Core.Buffer.create_blank_buffer(80, 24)
      buffer = Raxol.Core.Box.draw_box(buffer, 5, 3, 20, 10, :single)

      # Draw a double-line box with style
      buffer = Raxol.Core.Box.draw_box(buffer, 10, 5, 30, 8, :double)

      # Draw horizontal and vertical lines
      buffer = Raxol.Core.Box.draw_horizontal_line(buffer, 0, 0, 80)
      buffer = Raxol.Core.Box.draw_vertical_line(buffer, 0, 0, 24)

  """

  alias Raxol.Core.Buffer

  @type box_style :: :single | :double | :rounded | :heavy | :dashed

  @doc """
  Draws a box at the specified coordinates with the given style.

  ## Parameters

    - `buffer` - The buffer to draw on
    - `x` - X coordinate (left edge)
    - `y` - Y coordinate (top edge)
    - `width` - Width of the box
    - `height` - Height of the box
    - `style` - Box style (default: `:single`)

  ## Examples

      buffer = Raxol.Core.Box.draw_box(buffer, 5, 3, 20, 10, :double)

  """
  @spec draw_box(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          box_style()
        ) :: Buffer.t()
  def draw_box(buffer, x, y, width, height, style \\ :single) do
    chars = box_chars(style)

    buffer
    |> draw_corners(x, y, width, height, chars)
    |> draw_edges(x, y, width, height, chars)
  end

  @spec box_chars(box_style()) :: %{
          top_left: String.t(),
          top_right: String.t(),
          bottom_left: String.t(),
          bottom_right: String.t(),
          horizontal: String.t(),
          vertical: String.t()
        }
  defp box_chars(:single) do
    %{
      top_left: "┌",
      top_right: "┐",
      bottom_left: "└",
      bottom_right: "┘",
      horizontal: "─",
      vertical: "│"
    }
  end

  defp box_chars(:double) do
    %{
      top_left: "╔",
      top_right: "╗",
      bottom_left: "╚",
      bottom_right: "╝",
      horizontal: "═",
      vertical: "║"
    }
  end

  defp box_chars(:rounded) do
    %{
      top_left: "╭",
      top_right: "╮",
      bottom_left: "╰",
      bottom_right: "╯",
      horizontal: "─",
      vertical: "│"
    }
  end

  defp box_chars(:heavy) do
    %{
      top_left: "┏",
      top_right: "┓",
      bottom_left: "┗",
      bottom_right: "┛",
      horizontal: "━",
      vertical: "┃"
    }
  end

  defp box_chars(:dashed) do
    %{
      top_left: "┌",
      top_right: "┐",
      bottom_left: "└",
      bottom_right: "┘",
      horizontal: "╌",
      vertical: "╎"
    }
  end

  @spec draw_corners(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          map()
        ) :: Buffer.t()
  defp draw_corners(buffer, x, y, width, height, chars) do
    right_x = x + width - 1
    bottom_y = y + height - 1

    buffer
    |> Buffer.set_cell(x, y, chars.top_left, %{})
    |> Buffer.set_cell(right_x, y, chars.top_right, %{})
    |> Buffer.set_cell(x, bottom_y, chars.bottom_left, %{})
    |> Buffer.set_cell(right_x, bottom_y, chars.bottom_right, %{})
  end

  @spec draw_edges(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          map()
        ) :: Buffer.t()
  defp draw_edges(buffer, x, y, width, height, chars) do
    right_x = x + width - 1
    bottom_y = y + height - 1

    buffer
    |> draw_horizontal_edge(x + 1, y, width - 2, chars.horizontal)
    |> draw_horizontal_edge(x + 1, bottom_y, width - 2, chars.horizontal)
    |> draw_vertical_edge(x, y + 1, height - 2, chars.vertical)
    |> draw_vertical_edge(right_x, y + 1, height - 2, chars.vertical)
  end

  @spec draw_horizontal_edge(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t()
        ) :: Buffer.t()
  defp draw_horizontal_edge(buffer, x, y, length, char) do
    Enum.reduce(0..(length - 1), buffer, fn offset, acc ->
      Buffer.set_cell(acc, x + offset, y, char, %{})
    end)
  end

  @spec draw_vertical_edge(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t()
        ) :: Buffer.t()
  defp draw_vertical_edge(buffer, x, y, length, char) do
    Enum.reduce(0..(length - 1), buffer, fn offset, acc ->
      Buffer.set_cell(acc, x, y + offset, char, %{})
    end)
  end

  @doc """
  Draws a horizontal line at the specified position.

  ## Parameters

    - `buffer` - The buffer to draw on
    - `x` - X coordinate (starting position)
    - `y` - Y coordinate (row)
    - `length` - Length of the line
    - `char` - Character to use (default: "-")

  """
  @spec draw_horizontal_line(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t()
        ) :: Buffer.t()
  def draw_horizontal_line(buffer, x, y, length, char \\ "-") do
    Enum.reduce(0..(length - 1), buffer, fn offset, acc ->
      Buffer.set_cell(acc, x + offset, y, char, %{})
    end)
  end

  @doc """
  Draws a vertical line at the specified position.

  ## Parameters

    - `buffer` - The buffer to draw on
    - `x` - X coordinate (column)
    - `y` - Y coordinate (starting position)
    - `length` - Length of the line
    - `char` - Character to use (default: "|")

  """
  @spec draw_vertical_line(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t()
        ) :: Buffer.t()
  def draw_vertical_line(buffer, x, y, length, char \\ "|") do
    Enum.reduce(0..(length - 1), buffer, fn offset, acc ->
      Buffer.set_cell(acc, x, y + offset, char, %{})
    end)
  end

  @doc """
  Fills an area with the specified character and style.

  ## Parameters

    - `buffer` - The buffer to draw on
    - `x` - X coordinate (left edge)
    - `y` - Y coordinate (top edge)
    - `width` - Width of the area
    - `height` - Height of the area
    - `char` - Character to fill with
    - `style` - Style to apply (default: %{})

  """
  @spec fill_area(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map()
        ) :: Buffer.t()
  def fill_area(buffer, x, y, width, height, char, style \\ %{}) do
    Enum.reduce(0..(height - 1), buffer, fn row_offset, row_buffer ->
      Enum.reduce(0..(width - 1), row_buffer, fn col_offset, col_buffer ->
        Buffer.set_cell(col_buffer, x + col_offset, y + row_offset, char, style)
      end)
    end)
  end
end
