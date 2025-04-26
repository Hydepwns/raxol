defmodule Raxol.Plugins.Visualization.DrawingUtils do
  @moduledoc """
  Utility functions for drawing basic shapes and text onto a cell grid.
  Used by visualization renderers.
  """

  alias Raxol.Terminal.Cell
  alias Raxol.UI.Style

  @doc """
  Draws a simple box with optional text centered inside.
  Returns a grid of cells.
  Expects bounds map: %{width: w, height: h}.
  """
  def draw_box_with_text(text, %{width: width, height: height} = _bounds) do
    # Create empty grid
    grid = List.duplicate(List.duplicate(Cell.new(" "), width), height)
    # Draw borders (simple)
    grid = draw_box_borders(grid, 0, 0, width, height, Style.new(fg: :dark_gray))
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
        char = cond do
          # Corners
          current_y == y and current_x == x -> "┌"
          current_y == y and current_x == max_x -> "┐"
          current_y == max_y and current_x == x -> "└"
          current_y == max_y and current_x == max_x -> "┘"
          # Edges
          current_y == y or current_y == max_y -> "─"
          current_x == x or current_x == max_x -> "│"
          # Inside (should not happen with this loop structure)
          true -> elem(get_cell(inner_acc_grid, current_y, current_x), 0) || " "
        end
        # Only draw border characters
        if char != " " do
          put_cell(inner_acc_grid, current_y, current_x, %{Cell.new(char) | style: style})
        else
           inner_acc_grid # Shouldn't be reached for borders
        end
      end)
    end)
  end


  @doc """
  Draws text centered horizontally on a specific row in the grid.
  Truncates text if it exceeds grid width.
  """
  def draw_text_centered(grid, y, text) do
    height = length(grid)
    width = if height > 0, do: length(List.first(grid)), else: 0

    if y < 0 or y >= height or width == 0 do
      grid # Invalid position or grid
    else
      text_len = String.length(text)
      start_x = max(0, div(width - text_len, 2))
      # Truncate text to fit remaining width
      truncated_text = String.slice(text, 0, max(0, width - start_x))
      draw_text(grid, y, start_x, truncated_text)
    end
  end

  @doc """
  Draws text at a specific position in the grid.
  Overwrites existing cells. Truncates if text exceeds grid width.
  """
  def draw_text(grid, y, x, text, style \\ Style.new()) do
    height = length(grid)
    width = if height > 0, do: length(List.first(grid)), else: 0

    if y < 0 or y >= height or x >= width do
      grid # Start position out of bounds
    else
      chars = String.to_charlist(text)
      Enum.reduce(Enum.with_index(chars), grid, fn {char_code, index}, acc_grid ->
        current_x = x + index
        # Stop if we go past the grid width
        if current_x < width do
          put_cell(acc_grid, y, current_x, %{Cell.new(<<char_code::utf8>>) | style: style})
        else
          # Halt the reduction early if out of bounds
          {:halt, acc_grid}
        end
      end)\n      |> case do
           {:halt, final_grid} -> final_grid # Result when halted
           final_grid -> final_grid # Result when reduction completes normally
         end
    end
  end

  @doc """
  Safely puts a cell into the grid (list of lists).
  Handles out-of-bounds coordinates gracefully (no-op).
  """
  def put_cell(grid, y, x, cell) when is_list(grid) and y >= 0 and x >= 0 do
    if y < length(grid) do
      row = Enum.at(grid, y)
      if is_list(row) and x < length(row) do
        List.update_at(grid, y, fn _ -> List.replace_at(row, x, cell) end)
      else
        grid # x out of bounds
      end
    else
      grid # y out of bounds
    end
  end
  def put_cell(grid, _y, _x, _cell), do: grid # Catch non-grids or negative coords

  @doc """
  Safely gets a cell from the grid.
  Returns nil if coordinates are out of bounds.
  """
  def get_cell(grid, y, x) when is_list(grid) and y >= 0 and x >= 0 do
     List.fetch(grid, y)
     |> case do
          {:ok, row} when is_list(row) -> List.fetch(row, x)
          _ -> :error
        end
     |> case do
          {:ok, cell} -> cell
          _ -> nil
        end
  end
  def get_cell(_grid, _y, _x), do: nil

end
