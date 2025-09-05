defmodule Raxol.Plugins.Visualization.DrawingUtils do
  @moduledoc """
  Utility functions for drawing basic shapes and text onto a cell grid.
  Used by visualization renderers.
  """

  alias Raxol.Terminal.Cell
  alias Raxol.Style

  @doc """
  Draws a simple box with optional text centered inside.
  Returns a grid of cells.
  Expects bounds map: %{width: w, height: h}.
  """
  def draw_box_with_text(text, %{width: width, height: height} = _bounds) do
    # Create empty grid
    grid = List.duplicate(List.duplicate(Cell.new(" "), width), height)
    # Draw borders (simple)
    grid =
      draw_box_borders(grid, 0, 0, width, height, Style.new(fg: :dark_gray))

    # Draw text
    draw_text_centered(grid, div(height, 2), text)
  end

  @doc """
  Draws box borders onto an existing grid.
  """
  def draw_box_borders(grid, y, x, width, height, style) do
    max_y = y + height - 1
    max_x = x + width - 1

    Enum.reduce(y..max_y, grid, fn current_y, acc_grid ->
      Enum.reduce(x..max_x, acc_grid, fn current_x, inner_acc_grid ->
        draw_border_char(
          inner_acc_grid,
          current_y,
          current_x,
          y,
          x,
          max_y,
          max_x,
          style
        )
      end)
    end)
  end

  defp draw_border_char(grid, current_y, current_x, y, x, max_y, max_x, style) do
    char = get_border_char(current_y, current_x, y, x, max_y, max_x, grid)
    draw_char_if_not_space(char != " ", char, grid, current_y, current_x, style)
  end

  defp draw_char_if_not_space(
         false,
         _char,
         grid,
         _current_y,
         _current_x,
         _style
       ),
       do: grid

  defp draw_char_if_not_space(true, char, grid, current_y, current_x, style) do
    put_cell(grid, current_y, current_x, %{Cell.new(char) | style: style})
  end

  defp get_border_char(current_y, current_x, y, x, max_y, max_x, grid) do
    case {corner?(current_y, current_x, y, x, max_y, max_x),
          edge?(current_y, current_x, y, x, max_y, max_x)} do
      {true, _} ->
        get_corner_char(current_y, current_x, y, x)

      {false, true} ->
        get_edge_char(current_y, current_x, y, x)

      {false, false} ->
        elem(get_cell(grid, current_y, current_x), 0) || " "
    end
  end

  defp corner?(current_y, current_x, y, x, max_y, max_x) do
    current_y in [y, max_y] and current_x in [x, max_x]
  end

  defp get_corner_char(current_y, current_x, y, x) do
    case {current_y == y, current_x == x} do
      {true, true} -> "┌"
      {true, false} -> "┐"
      {false, true} -> "└"
      {false, false} -> "┘"
    end
  end

  defp edge?(current_y, current_x, y, x, max_y, max_x) do
    current_y in [y, max_y] or current_x in [x, max_x]
  end

  defp get_edge_char(current_y, _current_x, y, _x) do
    get_edge_character(current_y == y)
  end

  defp get_edge_character(true), do: "─"
  defp get_edge_character(false), do: "│"

  @doc """
  Draws text centered horizontally on a specific row in the grid.
  Truncates text if it exceeds grid width.
  """
  def draw_text_centered(grid, y, text) do
    height = length(grid)
    width = calculate_grid_width(height > 0, grid)

    is_valid_position = y >= 0 and y < height and width > 0
    handle_text_centering(is_valid_position, grid, y, text, width)
  end

  @doc """
  Draws text onto a grid at a specific coordinate.
  Truncates if text exceeds grid width.
  Uses optional style.
  """
  def draw_text(grid, y, x, text, style \\ Style.new()) do
    _text_length = String.length(text)
    grid_height = length(grid)
    grid_width = length(List.first(grid))
    _available_width = grid_width - x

    is_valid_position = y >= 0 and y < grid_height and x >= 0 and x < grid_width
    handle_text_drawing(is_valid_position, grid, text, y, x, grid_width, style)
  end

  defp draw_chars(grid, chars, y, x, grid_width, style) do
    Enum.reduce(Enum.with_index(chars), grid, fn {char_code, index}, acc_grid ->
      current_x = x + index

      handle_char_drawing(
        current_x < grid_width,
        acc_grid,
        char_code,
        y,
        current_x,
        style
      )
    end)
    |> case do
      {:halt, final_grid} -> final_grid
      final_grid -> final_grid
    end
  end

  @doc """
  Safely puts a cell into the grid (list of lists).
  Handles out-of-bounds coordinates gracefully (no-op).
  """
  def put_cell(grid, y, x, cell) when is_list(grid) and y >= 0 and x >= 0 do
    is_valid_y = y < length(grid)
    handle_cell_placement(is_valid_y, grid, y, x, cell)
  end

  defp handle_cell_placement(false, grid, _y, _x, _cell), do: grid

  defp handle_cell_placement(true, grid, y, x, cell),
    do: update_row(grid, y, x, cell)

  # Catch non-grids or negative coords
  def put_cell(grid, _y, _x, _cell), do: grid

  defp update_row(grid, y, x, cell) do
    row = Enum.at(grid, y)
    is_valid_row = is_list(row) and x < length(row)
    handle_row_update(is_valid_row, grid, y, x, cell, row)
  end

  defp handle_row_update(false, grid, _y, _x, _cell, _row), do: grid

  defp handle_row_update(true, grid, y, x, cell, row) do
    List.update_at(grid, y, fn _ -> List.replace_at(row, x, cell) end)
  end

  @doc """
  Safely gets a cell from the grid.
  Returns nil if coordinates are out of bounds.
  """
  def get_cell(grid, x, y) do
    # Use Enum.fetch for lists
    case Enum.fetch(grid, y) do
      {:ok, row} when is_list(row) -> Enum.fetch(row, x)
      _ -> {:error, :out_of_bounds}
    end
  end

  ## Helper Functions for Pattern Matching

  defp calculate_grid_width(false, _grid), do: 0
  defp calculate_grid_width(true, grid), do: length(List.first(grid))

  defp handle_text_centering(false, grid, _y, _text, _width) do
    # Invalid position or grid
    grid
  end

  defp handle_text_centering(true, grid, y, text, width) do
    text_len = String.length(text)
    start_x = max(0, div(width - text_len, 2))
    # Truncate text to fit remaining width
    truncated_text = String.slice(text, 0, max(0, width - start_x))
    draw_text(grid, y, start_x, truncated_text)
  end

  defp handle_text_drawing(false, grid, _text, _y, _x, _grid_width, _style),
    do: grid

  defp handle_text_drawing(true, grid, text, y, x, grid_width, style) do
    chars = String.to_charlist(text)
    draw_chars(grid, chars, y, x, grid_width, style)
  end

  defp handle_char_drawing(false, acc_grid, _char_code, _y, _current_x, _style) do
    {:halt, acc_grid}
  end

  defp handle_char_drawing(true, acc_grid, char_code, y, current_x, style) do
    put_cell(acc_grid, y, current_x, %{
      Cell.new(<<char_code::utf8>>)
      | style: style
    })
  end
end
