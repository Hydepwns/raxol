defmodule Raxol.Terminal.ScreenBuffer.Core.Operations do
  @moduledoc """
  Handles core buffer operations like writing, clearing, and scrolling.
  """

  alias Raxol.Terminal.ScreenBuffer.{Screen, Scroll}

  @doc """
  Gets a character at the specified position.
  """
  def get_char(buffer, x, y) do
    case Enum.at(buffer.cells, y) do
      nil ->
        " "

      row ->
        case Enum.at(row, x) do
          nil -> " "
          cell -> get_cell_char(cell)
        end
    end
  end

  # Handle both Raxol.Terminal.Cell and Raxol.Terminal.Buffer.Cell structs
  defp get_cell_char(%Raxol.Terminal.Cell{char: char}), do: char
  defp get_cell_char(%Raxol.Terminal.Buffer.Cell{char: char}), do: char
  defp get_cell_char(%{char: char}) when is_binary(char), do: char
  defp get_cell_char(_), do: " "

  @doc """
  Gets a cell at the specified position.
  """
  def get_cell(buffer, x, y) do
    get_in(buffer.cells, [y, x]) || Raxol.Terminal.Cell.new()
  end

  @doc """
  Writes a character at the specified position.
  """
  def write_char(buffer, x, y, char, style) do
    IO.puts("DEBUG: Core.write_char/4 called")
    # Create a proper Cell struct instead of using Access behavior
    cell = Raxol.Terminal.Cell.new(char, style)

    case get_in(buffer.cells, [y, x]) do
      nil ->
        # Cell doesn't exist, create it
        put_in(buffer.cells, [y, x], cell)

      existing_cell ->
        # Cell exists, update it
        updated_cell = Map.merge(existing_cell, cell)
        put_in(buffer.cells, [y, x], updated_cell)
    end
  end

  @doc """
  Writes a string starting at the specified position.
  """
  def write_string(buffer, x, y, string, style \\ nil) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, i}, acc ->
      write_char(acc, x + i, y, char, style)
    end)
  end

  @doc """
  Clears the entire buffer.
  """
  def clear(buffer, _style) do
    default_cell = Raxol.Terminal.Cell.new()

    %{
      buffer
      | cells:
          List.duplicate(
            List.duplicate(default_cell, buffer.width),
            buffer.height
          )
    }
  end

  @doc """
  Clears a specific line.
  """
  def clear_line(buffer, line, _style \\ nil) do
    new_content =
      List.update_at(buffer.cells, line, fn _ ->
        List.duplicate(%{}, buffer.width)
      end)

    %{buffer | cells: new_content}
  end

  @doc """
  Inserts lines at the top of the buffer.
  """
  def insert_lines(buffer, count) do
    empty_line = List.duplicate(%{}, buffer.width)
    new_lines = List.duplicate(empty_line, count)
    new_content = new_lines ++ buffer.cells
    %{buffer | cells: Enum.take(new_content, buffer.height)}
  end

  @doc """
  Deletes lines from the top of the buffer.
  """
  def delete_lines(buffer, count) do
    empty_line = List.duplicate(%{}, buffer.width)
    new_lines = List.duplicate(empty_line, count)
    new_content = buffer.cells ++ new_lines
    %{buffer | cells: Enum.take(new_content, buffer.height)}
  end

  @doc """
  Inserts characters at the beginning of each line.
  """
  def insert_chars(buffer, count) do
    %{
      buffer
      | cells:
          Enum.map(buffer.cells, fn line ->
            empty_cells = List.duplicate(%{}, count)
            empty_cells ++ Enum.take(line, buffer.width - count)
          end)
    }
  end

  @doc """
  Deletes characters from the beginning of each line.
  """
  def delete_chars(buffer, count) do
    %{
      buffer
      | cells:
          Enum.map(buffer.cells, fn line ->
            empty_cells = List.duplicate(%{}, count)
            Enum.drop(line, count) ++ empty_cells
          end)
    }
  end

  @doc """
  Erases characters from the beginning of each line.
  """
  def erase_chars(buffer, count) do
    %{
      buffer
      | cells:
          Enum.map(buffer.cells, fn line ->
            empty_cells = List.duplicate(%{}, count)
            Enum.take(line, buffer.width - count) ++ empty_cells
          end)
    }
  end

  @doc """
  Erases characters starting at a specific position.
  """
  def erase_chars(buffer, x, y, count) do
    # Erase characters starting at position (x, y)
    if y < length(buffer.cells) do
      line = Enum.at(buffer.cells, y, [])

      if x < length(line) do
        # Replace characters from x to x+count with empty cells
        new_line =
          Enum.take(line, x) ++
            List.duplicate(%{}, count) ++
            Enum.drop(line, x + count)

        new_cells = List.replace_at(buffer.cells, y, new_line)
        %{buffer | cells: new_cells}
      else
        buffer
      end
    else
      buffer
    end
  end

  @doc """
  Erases from cursor to end of display.
  """
  def erase_from_cursor_to_end(buffer) do
    %{
      buffer
      | screen_state: Screen.erase_from_cursor_to_end(buffer.screen_state)
    }
  end

  @doc """
  Erases from start to cursor.
  """
  def erase_from_start_to_cursor(buffer) do
    %{
      buffer
      | screen_state: Screen.erase_from_start_to_cursor(buffer.screen_state)
    }
  end

  @doc """
  Erases the entire display.
  """
  def erase_all(buffer) do
    %{buffer | screen_state: Screen.erase_all(buffer.screen_state)}
  end

  @doc """
  Erases all with scrollback.
  """
  def erase_all_with_scrollback(buffer) do
    %{
      buffer
      | screen_state: Screen.erase_all_with_scrollback(buffer.screen_state)
    }
  end

  @doc """
  Erases from cursor to end of line.
  """
  def erase_from_cursor_to_end_of_line(buffer) do
    %{
      buffer
      | screen_state:
          Screen.erase_from_cursor_to_end_of_line(buffer.screen_state)
    }
  end

  @doc """
  Erases from start of line to cursor.
  """
  def erase_from_start_of_line_to_cursor(buffer) do
    %{
      buffer
      | screen_state:
          Screen.erase_from_start_of_line_to_cursor(buffer.screen_state)
    }
  end

  @doc """
  Erases the current line.
  """
  def erase_line(buffer) do
    %{buffer | screen_state: Screen.erase_line(buffer.screen_state)}
  end

  @doc """
  Erases display based on mode.
  """
  def erase_display(buffer, mode) do
    case mode do
      0 -> erase_from_cursor_to_end(buffer)
      1 -> erase_from_start_to_cursor(buffer)
      2 -> erase_all(buffer)
      3 -> erase_all(buffer)
      _ -> buffer
    end
  end

  @doc """
  Erases display with additional parameters.
  """
  def erase_display(buffer, mode, _cursor, _min_row, _max_row) do
    # For now, delegate to the simpler version
    erase_display(buffer, mode)
  end

  @doc """
  Erases line with additional parameters.
  """
  def erase_line(buffer, _mode, _cursor, _min_col, _max_col) do
    # For now, delegate to the simpler version
    erase_line(buffer)
  end

  @doc """
  Deletes characters with additional parameters.
  """
  def delete_chars(buffer, count, _cursor, _max_col) do
    # For now, delegate to the simpler version
    delete_chars(buffer, count)
  end

  @doc """
  Inserts characters with additional parameters.
  """
  def insert_chars(buffer, count, _cursor, _max_col) do
    # For now, delegate to the simpler version
    insert_chars(buffer, count)
  end

  @doc """
  Marks a region as damaged.
  """
  def mark_damaged(buffer, x, y, width, height, _reason) do
    # For now, delegate to the simpler version
    mark_damaged(buffer, x, y, width, height)
  end

  @doc """
  Sets buffer dimensions.
  """
  def set_dimensions(buffer, width, height) do
    %{buffer | width: width, height: height}
  end

  @doc """
  Gets scrollback state.
  """
  def get_scrollback(buffer) do
    buffer.scroll_state
  end

  @doc """
  Sets scrollback state.
  """
  def set_scrollback(buffer, scrollback) do
    %{buffer | scroll_state: scrollback}
  end

  @doc """
  Gets damaged regions.
  """
  def get_damaged_regions(buffer) do
    Screen.get_damaged_regions(buffer.screen_state)
  end

  @doc """
  Clears damaged regions.
  """
  def clear_damaged_regions(buffer) do
    %{buffer | screen_state: Screen.clear_damaged_regions(buffer.screen_state)}
  end

  @doc """
  Gets cursor position.
  """
  def get_cursor_position(buffer) do
    {buffer.terminal_state.cursor_x, buffer.terminal_state.cursor_y}
  end

  @doc """
  Sets cursor position.
  """
  def set_cursor_position(buffer, x, y) do
    %{buffer | cursor_position: {x, y}}
  end

  @doc """
  Erases a specific region.
  """
  def erase_region(buffer, x, y, width, height) do
    new_content =
      Enum.reduce(y..(y + height - 1), buffer.cells, fn row, acc ->
        List.update_at(acc, row, &erase_line_region(&1, x, width))
      end)

    %{buffer | cells: new_content}
  end

  defp erase_line_region(line, x, width) do
    Enum.reduce(x..(x + width - 1), line, fn col, line_acc ->
      List.update_at(line_acc, col, fn _ -> %{} end)
    end)
  end

  @doc """
  Marks a region as damaged.
  """
  def mark_damaged(buffer, x, y, width, height) do
    %{
      buffer
      | screen_state:
          Screen.mark_damaged(buffer.screen_state, x, y, width, height)
    }
  end

  @doc """
  Clears a specific region.
  """
  def clear_region(buffer, x, y, width, height) do
    buffer
    |> erase_region(x, y, width, height)
    |> mark_damaged(x, y, width, height)
  end

  @doc """
  Gets buffer size.
  """
  def get_size(buffer) do
    {buffer.width, buffer.height}
  end

  @doc """
  Scrolls up by the specified number of lines.
  """
  def scroll_up(buffer, lines) do
    %{buffer | scroll_state: Scroll.up(buffer.scroll_state, lines)}
  end

  @doc """
  Scrolls down by the specified number of lines.
  """
  def scroll_down(buffer, lines) do
    %{buffer | scroll_state: Scroll.down(buffer.scroll_state, lines)}
  end

  @doc """
  Sets scroll region boundaries.
  """
  def set_scroll_region(buffer, start_line, end_line) do
    %{
      buffer
      | scroll_state:
          Scroll.set_region(buffer.scroll_state, start_line, end_line)
    }
  end

  @doc """
  Clears scroll region.
  """
  def clear_scroll_region(buffer) do
    %{buffer | scroll_state: Scroll.clear_region(buffer.scroll_state)}
  end

  @doc """
  Gets scroll region boundaries.
  """
  def get_scroll_region_boundaries(buffer) do
    Scroll.get_boundaries(buffer.scroll_state)
  end

  @doc """
  Gets scroll position.
  """
  def get_scroll_position(buffer) do
    Scroll.get_position(buffer.scroll_state)
  end

  @doc """
  Pops bottom lines from the buffer.
  """
  def pop_bottom_lines(buffer, count) do
    {lines, new_content} = Enum.split(buffer.cells, -count)
    {lines, %{buffer | cells: new_content}}
  end

  @doc """
  Pushes lines to the top of the buffer.
  """
  def push_top_lines(buffer, lines) do
    new_content = lines ++ buffer.cells
    %{buffer | cells: new_content}
  end

  @doc """
  Checks if a cell is empty.
  """
  def empty?(cell) when is_map(cell) do
    is_nil(cell.char) or cell.char == " "
  end
end
