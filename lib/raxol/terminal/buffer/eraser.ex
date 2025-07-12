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

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def clear_line(buffer, line_index, style \\ nil) do
    LineOperations.clear_line(buffer, line_index, style)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def erase_all(buffer) do
    clear(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def erase_from_cursor_to_end(buffer) do
    {x, y} = buffer.cursor_position
    clear_region(buffer, x, y, buffer.width - x, buffer.height - y)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def erase_from_start_to_cursor(buffer) do
    {x, y} = buffer.cursor_position || {0, 0}
    empty_cell = Cell.new(" ", buffer.default_style)

    new_cells =
      Enum.with_index(buffer.cells)
      |> Enum.map(fn {line, row} ->
        cond do
          row < y ->
            List.duplicate(empty_cell, buffer.width)

          row == y ->
            Enum.with_index(line)
            |> Enum.map(fn {cell, col} ->
              if col <= x, do: empty_cell, else: cell
            end)

          true ->
            line
        end
      end)

    %{buffer | cells: new_cells}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def erase_from_cursor_to_end_of_line(buffer) do
    {x, y} = buffer.cursor_position
    clear_line_from(buffer, y, x)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def erase_from_start_of_line_to_cursor(buffer) do
    {x, y} = buffer.cursor_position
    clear_line_to(buffer, y, x)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def erase_line(buffer, mode) do
    {x, y} = buffer.cursor_position

    case mode do
      # From cursor to end of line
      0 -> clear_line_from(buffer, y, x)
      # From start of line to cursor
      1 -> clear_line_to(buffer, y, x)
      # Entire line
      2 -> clear_line(buffer, y)
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
  def erase_display_segment(buffer, x, y, style \\ nil)

  def erase_display_segment(buffer, x, y, style) do
    style = style || TextFormatting.new()
    cells = buffer.cells
    empty_cell = Cell.new(" ", style)

    cells =
      Enum.with_index(cells)
      |> Enum.map(fn {line, row} ->
        if row > y or (row == y and x > 0) do
          clear_display_line_from_position(line, row, x, y, empty_cell)
        else
          line
        end
      end)

    %{buffer | cells: cells}
  end

  defp clear_display_line_from_position(line, row, x, y, empty_cell) do
    Enum.with_index(line)
    |> Enum.map(fn {cell, col} ->
      if row > y or (row == y and col >= x) do
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
  def erase_line_segment(buffer, x, y, style \\ nil)

  def erase_line_segment(buffer, x, y, style) do
    style = style || TextFormatting.new()
    cells = buffer.cells
    empty_cell = Cell.new(" ", style)

    cells =
      Enum.with_index(cells)
      |> Enum.map(fn {line, row} ->
        if row == y do
          clear_line_from_position(line, x, empty_cell)
        else
          line
        end
      end)

    %{buffer | cells: cells}
  end

  defp clear_line_from_position(line, x, empty_cell) do
    Enum.with_index(line)
    |> Enum.map(fn {cell, col} ->
      if col >= x do
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
  def clear_line_from(buffer, y, x, style \\ nil)

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
  def clear_line_to(buffer, y, x, style \\ nil)

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
  def clear_screen_from(buffer, y, x, style \\ nil) do
    style = style || TextFormatting.new()
    # Clear from cursor to end of line
    buffer = clear_region(buffer, x, y, buffer.width - x, 1, style)
    # Clear all lines below
    if y + 1 < buffer.height do
      clear_region(
        buffer,
        0,
        y + 1,
        buffer.width,
        buffer.height - (y + 1),
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
  def clear_screen_to(buffer, y, x, style \\ nil) do
    style = style || TextFormatting.new()

    buffer =
      if y > 0 do
        clear_region(buffer, 0, 0, buffer.width, y, style)
      else
        buffer
      end

    clear_region(buffer, 0, y, x + 1, 1, style)
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
      buffer.height - 1,
      buffer.width - 1,
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
  Requires cursor state {col, row}.
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

  defp handle_erase_in_line(buffer, {col, row}, type, style) do
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
  Requires cursor state {col, row}.
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

  defp handle_erase_in_display(buffer, {col, row}, type, style) do
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
    {x, y} = buffer.cursor_position
    erase_chars(buffer, x, y, count)
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
  def erase_chars(buffer, x, y, count) do
    if y < buffer.height do
      line = Enum.at(buffer.cells, y, [])
      new_line = erase_chars_in_line(line, x, count, buffer.default_style)
      new_cells = List.replace_at(buffer.cells, y, new_line)
      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  defp erase_chars_in_line(line, x, count, _default_style) do
    line_length = length(line)

    if x >= line_length do
      line
    else
      # Get the part before the cursor
      before_cursor = Enum.take(line, x)

      # Get the part after the erased characters
      after_erased = Enum.drop(line, x + count)

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
      0 -> erase_from_cursor_to_end(buffer)
      # From start of screen to cursor
      1 -> erase_from_start_to_cursor(buffer)
      # Entire screen
      2 -> erase_all(buffer)
      _ -> buffer
    end
  end

  @doc """
  Erases the specified line with the specified mode.
  """
  @spec erase_line(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def erase_line(buffer, line, mode) do
    case mode do
      # From cursor to end of line
      0 -> clear_line_from(buffer, line, 0)
      # From start of line to cursor
      1 -> clear_line_to(buffer, line, 0)
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
    erase_line(buffer, mode)
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

  def set_cursor_position(buffer, _x, _y), do: buffer

  def get_cursor_position(_buffer), do: {0, 0}

  def set_scroll_region(buffer, _top, _bottom), do: buffer

  def mark_damaged(buffer, _x, _y, _width, _height), do: buffer

  def get_damage_regions(_buffer), do: []
end
