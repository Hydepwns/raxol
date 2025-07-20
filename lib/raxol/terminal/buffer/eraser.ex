defmodule Raxol.Terminal.Buffer.Eraser do
  @moduledoc """
  Provides screen clearing operations for the screen buffer.
  This module handles operations like clearing the screen, lines, and regions.
  """

  import Raxol.Guards

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Buffer.LineOperations
  require Raxol.Core.Runtime.Log

  def clear_line(buffer, line_index, style \\ nil) do
    LineOperations.clear_line(buffer, line_index, style)
  end

  def erase_all(buffer) do
    clear(buffer)
  end

  def erase_from_cursor_to_end(buffer) do
    {row, col} = buffer.cursor_position
    erase_line_segment(buffer, row, col)
  end

  def erase_from_start_to_cursor(buffer) do
    {row, col} = buffer.cursor_position || {0, 0}
    empty_cell = Cell.new(" ", buffer.default_style)

    new_cells =
      process_lines_for_erase_from_start(
        buffer.cells,
        row,
        col,
        empty_cell,
        buffer.width
      )

    %{buffer | cells: new_cells}
  end

  defp process_lines_for_erase_from_start(cells, row, col, empty_cell, width) do
    Enum.with_index(cells)
    |> Enum.map(fn {line, line_row} ->
      process_line_for_erase_from_start(line, line_row, row, col, empty_cell, width)
    end)
  end

  defp process_line_for_erase_from_start(line, line_row, row, col, empty_cell, width) do
    cond do
      line_row < row -> List.duplicate(empty_cell, width)
      line_row == row -> clear_line_to_position(line, col, empty_cell)
      true -> line
    end
  end

  defp clear_line_to_position(line, col, empty_cell) do
    Enum.with_index(line)
    |> Enum.map(fn {cell, cell_col} -> if cell_col <= col, do: empty_cell, else: cell end)
  end

  def erase_from_start_of_line_to_cursor(buffer) do
    {row, col} = buffer.cursor_position
    clear_line_to(buffer, row, col)
  end

  def erase_line(buffer, mode) do
    {row, col} = buffer.cursor_position

    case mode do
      # From cursor to end of line
      0 -> clear_line_from(buffer, row, col)
      # From start of line to cursor
      1 -> clear_line_to(buffer, row, col)
      # Entire line
      2 -> clear_line(buffer, row)
      _ -> buffer
    end
  end

  @doc """
  Clears the entire screen with the specified style.
  """
  @spec clear(ScreenBuffer.t(), TextFormatting.text_style() | nil) ::
          ScreenBuffer.t()
  def clear(buffer, style \\ nil) do
    empty_line = create_empty_line(buffer.width, style || buffer.default_style)
    new_cells = List.duplicate(empty_line, buffer.height)
    %{buffer | cells: new_cells}
  end

  @doc """
  Clears a region of the screen with the specified style.
  """
  @spec clear_region(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def clear_region(buffer, x, y, width, height, style \\ nil) do
    empty_cell = Cell.new(" ", style || buffer.default_style)

    new_cells =
      Enum.reduce(y..(y + height - 1), buffer.cells, fn row, cells ->
        if row < buffer.height do
          List.update_at(
            cells,
            row,
            &clear_line_segment(&1, x, width, empty_cell)
          )
        else
          cells
        end
      end)

    %{buffer | cells: new_cells}
  end

  @doc """
  Erases from cursor to end of display.
  """
  @spec erase_display_segment(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def erase_display_segment(buffer, row, col, style \\ nil)

  def erase_display_segment(buffer, row, col, style) do
    style = style || TextFormatting.new()
    cells = buffer.cells
    empty_cell = Cell.new(" ", style)

    cells =
      Enum.with_index(cells)
      |> Enum.map(fn {line, line_row} ->
        if line_row > row or (line_row == row and col > 0) do
          clear_display_line_from_position(line, line_row, row, col, empty_cell)
        else
          line
        end
      end)

    %{buffer | cells: cells}
  end

  defp clear_display_line_from_position(line, line_row, row, col, empty_cell) do
    Enum.with_index(line)
    |> Enum.map(fn {cell, cell_col} ->
      if line_row > row or (line_row == row and cell_col >= col) do
        empty_cell
      else
        cell
      end
    end)
  end

  @doc """
  Erases from cursor to end of line.
  """
  @spec erase_line_segment(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def erase_line_segment(buffer, row, col, style \\ nil)

  def erase_line_segment(buffer, row, col, style) do
    style = style || TextFormatting.new()
    cells = buffer.cells
    empty_cell = Cell.new(" ", style)

    cells =
      Enum.with_index(cells)
      |> Enum.map(fn {line, line_row} ->
        if line_row == row do
          clear_line_from_position(line, col, empty_cell)
        else
          line
        end
      end)

    %{buffer | cells: cells}
  end

  defp clear_line_from_position(line, col, empty_cell) do
    Enum.with_index(line)
    |> Enum.map(fn {cell, cell_col} ->
      if cell_col >= col do
        empty_cell
      else
        cell
      end
    end)
  end

  @doc """
  Clears from the given position to the end of the line using the provided style.
  Returns the updated buffer state.
  """
  @spec clear_line_from(
          ScreenBuffer.t(),
          integer(),
          integer(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def clear_line_from(buffer, row, col, style \\ nil)

  def clear_line_from(%ScreenBuffer{} = buffer, row, col, style) do
    style = style || TextFormatting.new()
    clear_region(buffer, col, row, buffer.width - col, 1, style)
  end

  def clear_line_from(buffer, _row, _col, _style) do
    buffer
  end

  @doc """
  Clears from the beginning of the line to the given position using the provided style.
  Returns the updated buffer state.
  """
  @spec clear_line_to(
          ScreenBuffer.t(),
          integer(),
          integer(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def clear_line_to(buffer, row, col, style \\ nil)

  def clear_line_to(%ScreenBuffer{} = buffer, row, col, style) do
    style = style || TextFormatting.new()
    clear_region(buffer, 0, row, col + 1, 1, style)
  end

  def clear_line_to(buffer, _row, _col, _style) do
    buffer
  end

  @doc """
  Clears the screen from cursor position to end.
  """
  @spec clear_screen_from(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def clear_screen_from(buffer, row, col, style \\ nil) do
    style = style || TextFormatting.new()
    # Clear from cursor to end of line
    buffer = clear_region(buffer, col, row, buffer.width - col, 1, style)
    # Clear all lines below
    if row + 1 < buffer.height do
      clear_region(
        buffer,
        0,
        row + 1,
        buffer.width,
        buffer.height - (row + 1),
        style
      )
    else
      buffer
    end
  end

  @doc """
  Clears the screen from start to cursor position.
  """
  @spec clear_screen_to(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def clear_screen_to(buffer, row, col, style \\ nil) do
    style = style || TextFormatting.new()

    # Clear all lines before the cursor's line
    buffer =
      if row > 0 do
        clear_region(buffer, 0, 0, buffer.width, row, style)
      else
        buffer
      end

    # Clear from start of cursor's line up to and including cursor position
    clear_region(buffer, 0, row, col + 1, 1, style)
  end

  @doc """
  Clears the entire screen (main buffer grid) using the provided style.
  Returns the updated buffer state.
  """
  @spec clear_screen(ScreenBuffer.t(), TextFormatting.text_style() | nil) ::
          ScreenBuffer.t()
  def clear_screen(buffer, style \\ nil)

  def clear_screen(%ScreenBuffer{} = buffer, style) do
    style = style || TextFormatting.new()

    clear_region(
      buffer,
      0,
      0,
      buffer.width,
      buffer.height,
      style
    )
  end

  def clear_screen(buffer, _style) when tuple?(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  @doc """
  Erases parts of the current line based on cursor position and type.
  Type can be :to_end, :to_beginning, or :all.
  Requires cursor state {row, col}.
  Delegates to specific clear_line_* functions.
  """
  @spec erase_in_line(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          :to_end | :to_beginning | :all,
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def erase_in_line(buffer, cursor_pos, type, style \\ nil) do
    style = style || TextFormatting.new()

    case buffer do
      %{__struct__: _} = buffer ->
        handle_erase_in_line(buffer, cursor_pos, type, style)

      _ when tuple?(buffer) ->
        raise ArgumentError,
              "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
    end
  end

  defp handle_erase_in_line(buffer, {row, col}, type, style) do
    case type do
      :to_end ->
        clear_line_from(buffer, row, col, style)

      :to_beginning ->
        clear_line_to(buffer, row, col, style)

      :all ->
        clear_line(buffer, row, style)

      _ ->
        buffer
    end
  end

  defp handle_erase_in_line(buffer, _cursor_pos, _type, _style) do
    buffer
  end

  @doc """
  Erases parts of the display based on cursor position and type.
  Type can be :to_end, :to_beginning, or :all.
  Requires cursor state {row, col}.
  Delegates to specific clear_screen_* functions.
  Does not handle type 3 (scrollback) - that should be handled by the Emulator.
  """
  @spec erase_in_display(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          :to_end | :to_beginning | :all,
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def erase_in_display(buffer, cursor_pos, type, style \\ nil) do
    style = style || TextFormatting.new()

    case buffer do
      %{__struct__: _} = buffer ->
        handle_erase_in_display(buffer, cursor_pos, type, style)

      _ when tuple?(buffer) ->
        raise ArgumentError,
              "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
    end
  end

  defp handle_erase_in_display(buffer, {row, col}, type, style) do
    case type do
      :to_end ->
        clear_screen_from(buffer, row, col, style)

      :to_beginning ->
        clear_screen_to(buffer, row, col, style)

      :all ->
        clear_screen(buffer, style)

      _ ->
        buffer
    end
  end

  defp handle_erase_in_display(buffer, _cursor_pos, _type, _style) do
    buffer
  end

  # === Additional Eraser Functions ===

  @doc """
  Erases characters from the cursor position by shifting remaining text left.
  """
  @spec erase_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_chars(buffer, count) do
    {row, col} = buffer.cursor_position
    erase_chars(buffer, row, col, count)
  end

  @doc """
  Erases characters at a specific position by shifting remaining text left.
  """
  @spec erase_chars(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def erase_chars(buffer, row, col, count) do
    if row < buffer.height do
      case buffer.cells do
        nil ->
          # Return buffer unchanged if cells is nil
          buffer

        cells ->
          line = Enum.at(cells, row, [])
          new_line = erase_chars_in_line(line, col, count, buffer.default_style)
          new_cells = List.replace_at(cells, row, new_line)
          %{buffer | cells: new_cells}
      end
    else
      buffer
    end
  end

  defp erase_chars_in_line(line, col, count, _default_style) do
    line_length = length(line)

    if col >= line_length do
      line
    else
      # Get the part before the cursor
      before_cursor = Enum.take(line, col)

      # Get the part after the erased characters
      after_erased = Enum.drop(line, col + count)

      # Combine: before cursor + remaining text (shifted left)
      before_cursor ++ after_erased
    end
  end

  @doc """
  Erases the display with the specified mode.
  """
  @spec erase_display(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_display(buffer, mode) do
    case mode do
      # From cursor to end of screen
      0 ->
        {row, col} = buffer.cursor_position || {0, 0}
        clear_screen_from(buffer, row, col)

      # From start of screen to cursor
      1 ->
        {row, col} = buffer.cursor_position || {0, 0}
        clear_screen_to(buffer, row, col)

      # Entire screen
      2 ->
        clear_screen(buffer)

      # Clear scrollback buffer
      3 ->
        clear_scrollback(buffer)

      _ ->
        buffer
    end
  end

  @doc """
  Erases the specified line with the specified mode.
  """
  @spec erase_line(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def erase_line(buffer, line, mode) do
    {row, col} = buffer.cursor_position || {0, 0}
    case mode do
      # From cursor to end of line
      0 -> clear_line_from(buffer, line, col)
      # From start of line to cursor
      1 -> clear_line_to(buffer, line, col)
      # Entire line
      2 -> clear_line(buffer, line)
      _ -> buffer
    end
  end

  @doc """
  Erases in display with the specified mode.
  """
  @spec erase_in_display(ScreenBuffer.t(), non_neg_integer()) ::
          ScreenBuffer.t()
  def erase_in_display(buffer, mode) do
    erase_display(buffer, mode)
  end

  @doc """
  Erases in line with the specified mode.
  """
  @spec erase_in_line(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def erase_in_line(buffer, mode) do
    {row, col} = buffer.cursor_position || {0, 0}
    erase_line(buffer, row, mode)
  end

  # Private helper functions

  defp clear_line_segment(line, x, width, empty_cell) do
    Enum.reduce(x..(x + width - 1), line, fn col, acc ->
      update_cell_if_in_bounds(acc, col, empty_cell, length(line))
    end)
  end

  defp update_cell_if_in_bounds(line, col, empty_cell, line_length) do
    if col < line_length do
      List.update_at(line, col, fn _ -> empty_cell end)
    else
      line
    end
  end

  defp create_empty_line(width, style) do
    for _ <- 1..width do
      Cell.new(" ", style)
    end
  end

  def set_cursor_position(buffer, row, col), do: buffer

  def get_cursor_position(_buffer), do: {0, 0}

  def set_scroll_region(buffer, _top, _bottom), do: buffer

  def mark_damaged(buffer, _x, _y, _width, _height), do: buffer

  def get_damage_regions(_buffer), do: []

  @doc """
  Clears the scrollback buffer.
  """
  @spec clear_scrollback(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear_scrollback(buffer) do
    %{buffer | scrollback: []}
  end
end
