defmodule Raxol.Terminal.Buffer.Eraser do
  @moduledoc """
  Provides screen clearing operations for the screen buffer.
  This module handles operations like clearing the screen, lines, and regions.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Buffer.LineOperations
  require Raxol.Core.Runtime.Log

  @doc """
  Clears the entire screen with the specified style.
  """
  @spec clear(ScreenBuffer.t(), TextFormatting.text_style() | nil) :: ScreenBuffer.t()
  def clear(buffer, style \\ nil) do
    empty_line = create_empty_line(buffer.width, style || buffer.default_style)
    new_cells = List.duplicate(empty_line, buffer.height)
    %{buffer | cells: new_cells}
  end

  @doc """
  Clears a specific line with the specified style.
  """
  @spec clear_line(ScreenBuffer.t(), non_neg_integer(), TextFormatting.text_style() | nil) :: ScreenBuffer.t()
  def clear_line(buffer, line_index, style \\ nil) do
    LineOperations.clear_line(buffer, line_index, style)
  end

  @doc """
  Clears a region of the screen with the specified style.
  """
  @spec clear_region(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style() | nil) :: ScreenBuffer.t()
  def clear_region(buffer, x, y, width, height, style \\ nil) do
    empty_cell = Cell.new("", style || buffer.default_style)

    new_cells = Enum.reduce(y..(y + height - 1), buffer.cells, fn row, cells ->
      if row < buffer.height do
        List.update_at(cells, row, fn line ->
          Enum.reduce(x..(x + width - 1), line, fn col, acc ->
            if col < buffer.width do
              List.update_at(acc, col, fn _ -> empty_cell end)
            else
              acc
            end
          end)
        end)
      else
        cells
      end
    end)

    %{buffer | cells: new_cells}
  end

  @doc """
  Erases from cursor to end of screen.
  """
  @spec erase_from_cursor_to_end(ScreenBuffer.t()) :: ScreenBuffer.t()
  def erase_from_cursor_to_end(buffer) do
    {x, y} = buffer.cursor_position
    clear_region(buffer, x, y, buffer.width - x, buffer.height - y)
  end

  @doc """
  Erases from start of screen to cursor.
  """
  @spec erase_from_start_to_cursor(ScreenBuffer.t()) :: ScreenBuffer.t()
  def erase_from_start_to_cursor(buffer) do
    {x, y} = buffer.cursor_position
    clear_region(buffer, 0, 0, x + 1, y + 1)
  end

  @doc """
  Erases the entire screen.
  """
  @spec erase_all(ScreenBuffer.t()) :: ScreenBuffer.t()
  def erase_all(buffer) do
    clear(buffer)
  end

  @doc """
  Erases from cursor to end of display.
  """
  @spec erase_display_segment(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style() | nil) :: ScreenBuffer.t()
  def erase_display_segment(buffer, x, y, style \\ nil)
  def erase_display_segment(buffer, x, y, style) do
    style = style || TextFormatting.new()
    cells = buffer.cells
    empty_cell = Cell.new(" ", style)

    cells = Enum.with_index(cells)
    |> Enum.map(fn {line, row} ->
      if row > y or (row == y and x > 0) do
        Enum.with_index(line)
        |> Enum.map(fn {cell, col} ->
          if row > y or (row == y and col >= x) do
            empty_cell
          else
            cell
          end
        end)
      else
        line
      end
    end)

    %{buffer | cells: cells}
  end

  @doc """
  Erases from cursor to end of line.
  """
  @spec erase_line_segment(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style() | nil) :: ScreenBuffer.t()
  def erase_line_segment(buffer, x, y, style \\ nil)
  def erase_line_segment(buffer, x, y, style) do
    style = style || TextFormatting.new()
    cells = buffer.cells
    empty_cell = Cell.new(" ", style)

    cells = Enum.with_index(cells)
    |> Enum.map(fn {line, row} ->
      if row == y do
        Enum.with_index(line)
        |> Enum.map(fn {cell, col} ->
          if col >= x do
            empty_cell
          else
            cell
          end
        end)
      else
        line
      end
    end)

    %{buffer | cells: cells}
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
    clear_region(buffer, row, col, row, buffer.width - 1, style)
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
    clear_region(buffer, row, 0, row, col, style)
  end
  def clear_line_to(buffer, _row, _col, _style) do
    buffer
  end

  @doc """
  Clears the screen from cursor position to end.
  """
  @spec clear_screen_from(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style() | nil) :: ScreenBuffer.t()
  def clear_screen_from(buffer, y, x, style \\ nil) do
    style = style || TextFormatting.new()
    # Clear from cursor to end of line
    buffer = clear_region(buffer, x, y, buffer.width - x, 1, style)
    # Clear all lines below
    if y + 1 < buffer.height do
      clear_region(buffer, 0, y + 1, buffer.width, buffer.height - (y + 1), style)
    else
      buffer
    end
  end

  @doc """
  Clears the screen from start to cursor position.
  """
  @spec clear_screen_to(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style() | nil) :: ScreenBuffer.t()
  def clear_screen_to(buffer, y, x, style \\ nil) do
    style = style || TextFormatting.new()
    # Clear from start of line to cursor
    buffer = clear_region(buffer, 0, y, x + 1, 1, style)
    # Clear all lines above
    if y > 0 do
      clear_region(buffer, 0, 0, buffer.width, y, style)
    else
      buffer
    end
  end

  @doc """
  Clears the entire screen (main buffer grid) using the provided style.
  Returns the updated buffer state.
  """
  @spec clear_screen(ScreenBuffer.t(), TextFormatting.text_style() | nil) :: ScreenBuffer.t()
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
  def clear_screen(buffer, _style) when is_tuple(buffer) do
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
        case cursor_pos do
          {col, row} ->
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
          _ ->
            buffer
        end
      _ when is_tuple(buffer) ->
        raise ArgumentError,
              "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
    end
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
        case cursor_pos do
          {col, row} ->
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
          _ ->
            buffer
        end
      _ when is_tuple(buffer) ->
        raise ArgumentError,
              "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
    end
  end

  # Private helper functions

  defp create_empty_line(width, style) do
    for _ <- 1..width do
      Cell.new("", style)
    end
  end
end
