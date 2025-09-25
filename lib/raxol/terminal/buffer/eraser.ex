defmodule Raxol.Terminal.Buffer.Eraser do
  @moduledoc """
  Compatibility adapter for buffer erasing operations.
  Forwards calls to Raxol.Terminal.ScreenBuffer.Operations.
  """

  alias Raxol.Terminal.ScreenBuffer.Operations, as: ConsolidatedOps

  @doc """
  Clears the entire buffer.
  """
  @spec clear(term()) :: term()
  def clear(buffer) do
    # Clear all cells in the buffer
    height = buffer.height || 24
    width = buffer.width || 80
    ConsolidatedOps.clear_region(buffer, 0, 0, width, height)
  end

  @doc """
  Erases from start of line to cursor.
  """
  @spec erase_from_start_of_line_to_cursor(term()) :: term()
  def erase_from_start_of_line_to_cursor(buffer) do
    ConsolidatedOps.clear_to_beginning_of_line(buffer)
  end

  @doc """
  Erases from start to cursor.
  """
  @spec erase_from_start_to_cursor(term()) :: term()
  def erase_from_start_to_cursor(buffer) do
    ConsolidatedOps.clear_to_beginning_of_screen(buffer)
  end

  @doc """
  Erases a line.
  """
  @spec erase_line(term(), non_neg_integer()) :: term()
  def erase_line(buffer, y) do
    ConsolidatedOps.clear_line(buffer, y)
  end

  @doc """
  Clears all buffer content (alias for clear).
  """
  @spec clear_all(term()) :: term()
  def clear_all(buffer), do: clear(buffer)

  @doc """
  Erases characters at cursor position.
  """
  @spec erase_chars(term(), non_neg_integer()) :: term()
  def erase_chars(buffer, count) do
    ConsolidatedOps.erase_chars(buffer, count)
  end

  @doc """
  Erases from cursor to end of line.
  """
  @spec erase_from_cursor_to_end(term()) :: term()
  def erase_from_cursor_to_end(buffer) do
    ConsolidatedOps.clear_to_end_of_line(buffer)
  end

  @doc """
  Erases in display with mode.
  """
  @spec erase_in_display(term(), atom()) :: term()
  def erase_in_display(buffer, mode) do
    ConsolidatedOps.erase_display(buffer, mode)
  end

  @doc """
  Erases in line with mode at position.
  """
  @spec erase_in_line(term(), non_neg_integer(), atom()) :: term()
  def erase_in_line(buffer, y, mode) do
    ConsolidatedOps.erase_line(buffer, y, mode)
  end

  @doc """
  Erases a line segment.
  """
  @spec erase_line_segment(term(), non_neg_integer(), non_neg_integer()) ::
          term()
  def erase_line_segment(buffer, x, y) do
    # Erase from x to end of line at row y
    width = buffer.width || 80
    ConsolidatedOps.clear_region(buffer, x, y, width - x, 1)
  end

  @doc """
  Clears the screen with a style.
  """
  @spec clear_screen(term(), map() | nil) :: term()
  def clear_screen(buffer, _style \\ nil) do
    clear(buffer)
  end

  @doc """
  Clears screen from a position.
  """
  @spec clear_screen_from(
          term(),
          non_neg_integer(),
          non_neg_integer(),
          map() | nil
        ) :: term()
  def clear_screen_from(buffer, row, col, _style \\ nil) do
    # Clear from position to end of screen
    {x, y} = buffer.cursor_position || {col, row}
    buffer = %{buffer | cursor_position: {col, row}}

    ConsolidatedOps.clear_to_end_of_screen(buffer)
    # Restore original cursor
    |> Map.put(:cursor_position, {x, y})
  end

  @doc """
  Clears screen to a position.
  """
  @spec clear_screen_to(
          term(),
          non_neg_integer(),
          non_neg_integer(),
          map() | nil
        ) :: term()
  def clear_screen_to(buffer, row, col, _style \\ nil) do
    # Clear from start of screen to position
    {x, y} = buffer.cursor_position || {0, 0}
    buffer = %{buffer | cursor_position: {col, row}}

    ConsolidatedOps.clear_to_beginning_of_screen(buffer)
    # Restore original cursor
    |> Map.put(:cursor_position, {x, y})
  end

  @doc """
  Clears scrollback buffer.
  """
  @spec clear_scrollback(term()) :: term()
  def clear_scrollback(buffer) do
    # Clear scrollback history
    %{buffer | scrollback: []}
  end

  @doc """
  Clears a line from a position.
  """
  @spec clear_line_from(
          term(),
          non_neg_integer(),
          non_neg_integer(),
          map() | nil
        ) :: term()
  def clear_line_from(buffer, row, col, _style \\ nil) do
    # Clear from col to end of line at row
    width = buffer.width || 80
    ConsolidatedOps.clear_region(buffer, col, row, width - col, 1)
  end

  @doc """
  Clears a line to a position.
  """
  @spec clear_line_to(term(), non_neg_integer(), non_neg_integer(), map() | nil) ::
          term()
  def clear_line_to(buffer, row, col, _style \\ nil) do
    # Clear from start of line to col at row
    ConsolidatedOps.clear_region(buffer, 0, row, col + 1, 1)
  end

  @doc """
  Erases a number of characters at a position.
  """
  @spec erase_chars(
          term(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: term()
  def erase_chars(buffer, row, col, count) do
    ConsolidatedOps.clear_region(buffer, col, row, count, 1)
  end

  @doc """
  Clears an entire line.
  """
  @spec clear_line(term(), non_neg_integer(), term()) :: term()
  def clear_line(buffer, row, _style \\ nil) do
    ConsolidatedOps.clear_line(buffer, row)
  end

  @doc """
  Clears a rectangular region.
  """
  @spec clear_region(
          term(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          term()
        ) :: term()
  def clear_region(buffer, x, y, width, height, _style \\ nil) do
    ConsolidatedOps.clear_region(buffer, x, y, width, height)
  end
end
