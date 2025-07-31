defmodule Raxol.Terminal.Buffer.UnifiedManager.Scroll do
  @moduledoc """
  Handles scrolling operations for the unified buffer manager.

  This module provides functions for scrolling regions within the buffer,
  managing scrollback content, and handling scroll operations.
  """

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Buffer.Scroll, as: ScrollBuffer

  @doc """
  Processes scrolling within a region.
  """
  @spec process_scroll_region(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          integer()
        ) :: {map(), ScrollBuffer.t()}
  def process_scroll_region(state, x, y, width, height, amount) do
    # Validate region bounds
    if x < 0 or y < 0 or width <= 0 or height <= 0 or
         x + width > state.active_buffer.width or
         y + height > state.active_buffer.height do
      # Invalid region, return unchanged buffers
      {state.active_buffer, state.scrollback_buffer}
    else
      # Perform scrolling within the region
      new_active_buffer =
        scroll_region_in_buffer(
          state.active_buffer,
          x,
          y,
          width,
          height,
          amount
        )

      # Add scrolled content to scrollback buffer
      scrolled_lines =
        extract_scrolled_lines(state.active_buffer, x, y, width, height, amount)

      new_scrollback_buffer =
        add_lines_to_scrollback(state.scrollback_buffer, scrolled_lines)

      {new_active_buffer, new_scrollback_buffer}
    end
  end

  @doc """
  Scrolls a region up within the buffer.
  """
  @spec scroll_region_up(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: map()
  def scroll_region_up(buffer, x, y, width, height, amount) do
    # Extract only the region content from each row
    region_lines =
      Enum.map(y..(y + height - 1), fn row_y ->
        if row_y < buffer.height do
          row = Enum.at(buffer.cells, row_y, [])
          Enum.slice(row, x, width)
        else
          List.duplicate(Cell.new(), width)
        end
      end)

    # Split the region into scroll_lines (lines that will be scrolled out) and remaining (lines that will stay)
    {_scroll_lines, remaining} = Enum.split(region_lines, amount)

    # Create empty lines for the scrolled-out lines - only for the region width
    empty_line = List.duplicate(Cell.new(), width)
    empty_lines = List.duplicate(empty_line, amount)

    # New region: remaining lines + empty lines at bottom
    new_region_lines = remaining ++ empty_lines

    # Replace only the region in the buffer
    replace_region_in_buffer(buffer, x, y, width, height, new_region_lines)
  end

  @doc """
  Scrolls a region down within the buffer.
  """
  @spec scroll_region_down(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: map()
  def scroll_region_down(buffer, x, y, width, height, amount) do
    # Extract only the region content from each row
    region_lines =
      Enum.map(y..(y + height - 1), fn row_y ->
        if row_y < buffer.height do
          row = Enum.at(buffer.cells, row_y, [])
          Enum.slice(row, x, width)
        else
          List.duplicate(Cell.new(), width)
        end
      end)

    # Scroll the region content down: move lines starting from 0 down by 'amount' positions
    # Lines height-amount to height-1 are lost, lines 0 to height-amount-1 move down
    {lines_to_move, _} = Enum.split(region_lines, height - amount)

    # Create empty lines for the top - only for the region width
    empty_line = List.duplicate(Cell.new(), width)
    empty_lines = List.duplicate(empty_line, amount)

    # New region: empty lines at top + moved lines
    new_region_lines = empty_lines ++ lines_to_move

    # Replace only the region in the buffer
    replace_region_in_buffer(buffer, x, y, width, height, new_region_lines)
  end

  # Private functions

  defp scroll_region_in_buffer(buffer, x, y, width, height, amount) do
    if amount > 0 do
      # Scroll up: move content up within the region
      scroll_region_up(buffer, x, y, width, height, amount)
    else
      # Scroll down: move content down within the region
      scroll_region_down(buffer, x, y, width, height, abs(amount))
    end
  end

  # Extract lines that are scrolled out of the region
  defp extract_scrolled_lines(buffer, x, y, width, _height, amount)
       when amount > 0 do
    # When scrolling up, the top 'amount' lines are scrolled out
    Enum.map(0..(amount - 1), fn i ->
      row_y = y + i

      if row_y < buffer.height do
        Enum.slice(buffer.cells |> Enum.at(row_y, []), x, width)
      else
        []
      end
    end)
    |> Enum.filter(fn line -> line != [] end)
  end

  defp extract_scrolled_lines(buffer, x, y, width, height, amount)
       when amount < 0 do
    # When scrolling down, the bottom 'abs(amount)' lines are scrolled out
    abs_amount = abs(amount)

    Enum.map((height - abs_amount)..(height - 1), fn i ->
      row_y = y + i

      if row_y < buffer.height do
        Enum.slice(buffer.cells |> Enum.at(row_y, []), x, width)
      else
        []
      end
    end)
    |> Enum.filter(fn line -> line != [] end)
  end

  # Add lines to scrollback buffer
  defp add_lines_to_scrollback(scrollback_buffer, lines) do
    if lines != [] do
      ScrollBuffer.add_content(scrollback_buffer, lines)
    else
      scrollback_buffer
    end
  end

  # Helper function to replace a region in the buffer
  defp replace_region_in_buffer(buffer, x, y, width, height, new_region_lines) do
    new_cells =
      update_buffer_rows(buffer.cells, x, y, width, height, new_region_lines)

    %{buffer | cells: new_cells}
  end

  defp update_buffer_rows(cells, x, y, width, height, new_region_lines) do
    cells
    |> Enum.with_index()
    |> Enum.map(fn {row, row_y} ->
      if row_in_region?(row_y, y, height) do
        update_row_in_region(
          row,
          x,
          width,
          Enum.at(new_region_lines, row_y - y)
        )
      else
        row
      end
    end)
  end

  defp row_in_region?(row_y, y, height) do
    row_y >= y and row_y < y + height
  end

  defp update_row_in_region(row, x, width, region_row) do
    row
    |> Enum.with_index()
    |> Enum.map(fn {cell, col_x} ->
      if col_in_region?(col_x, x, width) do
        new_cell = Enum.at(region_row, col_x - x)
        # Return new_cell or create empty cell if nil
        new_cell || Cell.new()
      else
        cell
      end
    end)
  end

  defp col_in_region?(col_x, x, width) do
    col_x >= x and col_x < x + width
  end

  @doc """
  Gets a view of the scrollback buffer content.

  ## Parameters
    * `scrollback_buffer` - The scrollback buffer
    * `count` - The number of lines to retrieve

  ## Returns
    * `list()` - The requested lines from the scrollback buffer
  """
  def get_view(scrollback_buffer, count) do
    Raxol.Terminal.Buffer.Scroll.get_view(scrollback_buffer, count)
  end

  @doc """
  Gets the size of the scrollback buffer.

  ## Parameters
    * `scrollback_buffer` - The scrollback buffer

  ## Returns
    * `non_neg_integer()` - The number of lines in the scrollback buffer
  """
  def get_size(scrollback_buffer) do
    Raxol.Terminal.Buffer.Scroll.get_size(scrollback_buffer)
  end

  @doc """
  Cleans up the scrollback buffer.

  ## Parameters
    * `scrollback_buffer` - The scrollback buffer

  ## Returns
    * `Raxol.Terminal.Buffer.Scroll.t()` - The cleaned up scrollback buffer
  """
  def cleanup(scrollback_buffer) do
    Raxol.Terminal.Buffer.Scroll.cleanup(scrollback_buffer)
  end

  @doc """
  Sets the maximum height of the scrollback buffer.

  ## Parameters
    * `scrollback_buffer` - The scrollback buffer
    * `limit` - The maximum height

  ## Returns
    * `Raxol.Terminal.Buffer.Scroll.t()` - The updated scrollback buffer
  """
  def set_max_height(scrollback_buffer, limit) do
    Raxol.Terminal.Buffer.Scroll.set_max_height(scrollback_buffer, limit)
  end
end
