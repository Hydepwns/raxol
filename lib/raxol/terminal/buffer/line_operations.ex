defmodule Raxol.Terminal.Buffer.LineOperations do
  import Raxol.Guards

  @moduledoc """
  Provides line-level operations for the screen buffer.
  This module handles operations like inserting, deleting, and manipulating lines.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Inserts blank lines at the cursor position, shifting lines down and pushing out the bottom lines.
  Lines below the cursor are shifted down, and lines shifted off the bottom are discarded.
  """
  @spec insert_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_lines(buffer, count) when integer?(count) and count > 0 do
    {_, y} = buffer.cursor_position

    # Split the content at the cursor position
    {before_cursor, after_cursor} = Enum.split(buffer.cells, y)

    # Create blank lines
    blank_lines = create_empty_lines(buffer.width, count)

    # Combine: before cursor + blank lines + after cursor
    combined = before_cursor ++ blank_lines ++ after_cursor

    # Take only the first buffer.height lines (truncate if necessary)
    new_cells = Enum.take(combined, buffer.height)

    %{buffer | cells: new_cells}
  end

  @doc """
  Inserts a specified number of lines with explicit parameters.
  """
  def insert_lines(
        buffer,
        count,
        cursor_y,
        _cursor_x,
        scroll_top,
        scroll_bottom
      ) do
    if cursor_y >= scroll_top and cursor_y <= scroll_bottom do
      # Split the content at the cursor position
      {before_cursor, after_cursor} = Enum.split(buffer.cells, cursor_y)

      # Create blank lines
      blank_lines = create_empty_lines(buffer.width, count)

      # Calculate how many lines to keep from after_cursor
      lines_to_keep = max(0, scroll_bottom - cursor_y - count + 1)
      kept_lines = Enum.take(after_cursor, lines_to_keep)

      # Combine the parts
      new_cells = before_cursor ++ blank_lines ++ kept_lines

      # Ensure the buffer maintains its correct size
      final_cells =
        if length(new_cells) < length(buffer.cells) do
          # Add any additional blank lines needed
          additional_lines =
            create_empty_lines(
              buffer.width,
              length(buffer.cells) - length(new_cells)
            )

          new_cells ++ additional_lines
        else
          # Truncate if necessary
          Enum.take(new_cells, length(buffer.cells))
        end

      %{buffer | cells: final_cells}
    else
      buffer
    end
  end

  @doc """
  Helper function to handle the line insertion logic.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `cursor_y` - The y-coordinate of the cursor
  * `count` - The number of lines to insert
  * `bottom` - The bottom boundary of the scroll region

  ## Returns

  The updated screen buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = LineOperations.do_insert_lines(buffer, 0, 5, 23)
      iex> length(buffer.cells)
      24
  """
  @spec do_insert_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def do_insert_lines(buffer, cursor_y, count, bottom) do
    # Split the content at the cursor position
    {before_cursor, after_cursor} = Enum.split(buffer.cells, cursor_y)

    # Create blank lines
    blank_lines = create_empty_lines(buffer.width, count)

    # Calculate how many lines to keep from after_cursor
    lines_to_keep = max(0, bottom - cursor_y - count + 1)
    kept_lines = Enum.take(after_cursor, lines_to_keep)

    # Combine the parts
    new_cells = before_cursor ++ blank_lines ++ kept_lines

    # Ensure the buffer maintains its correct size
    final_cells =
      if length(new_cells) < length(buffer.cells) do
        # Add any additional blank lines needed
        additional_lines =
          create_empty_lines(
            buffer.width,
            length(buffer.cells) - length(new_cells)
          )

        new_cells ++ additional_lines
      else
        # Truncate if necessary
        Enum.take(new_cells, length(buffer.cells))
      end

    %{buffer | cells: final_cells}
  end

  @doc """
  Inserts lines at a specific position with style.
  """
  @spec do_insert_lines_with_style(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def do_insert_lines_with_style(buffer, cursor_y, count, bottom, style) do
    # Split the content at the cursor position
    {before_cursor, after_cursor} = Enum.split(buffer.cells, cursor_y)

    # Create blank lines with style
    blank_lines = create_empty_lines(buffer.width, count, style)

    # Calculate how many lines to keep from after_cursor
    lines_to_keep = max(0, bottom - cursor_y - count + 1)
    kept_lines = Enum.take(after_cursor, lines_to_keep)

    # Combine the parts
    new_cells = before_cursor ++ blank_lines ++ kept_lines

    # Ensure the buffer maintains its correct size
    final_cells =
      if length(new_cells) < length(buffer.cells) do
        # Add any additional blank lines needed
        additional_lines =
          create_empty_lines(
            buffer.width,
            length(buffer.cells) - length(new_cells)
          )

        new_cells ++ additional_lines
      else
        # Truncate if necessary
        Enum.take(new_cells, length(buffer.cells))
      end

    %{buffer | cells: final_cells}
  end

  @doc """
  Deletes a specified number of lines starting from the current cursor position.
  Lines below the deleted lines are shifted up, and blank lines are added at the bottom.
  """
  @spec delete_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_lines(buffer, count) when is_integer(count) and count > 0 do
    {_x, y} = buffer.cursor_position

    {top, bottom} =
      Raxol.Terminal.ScreenBuffer.ScrollRegion.get_boundaries(
        buffer.scroll_region
      )

    # Only delete lines within the scroll region
    if y >= top and y <= bottom do
      # Split the content at the cursor position
      {before, after_cursor} = Enum.split(buffer.cells, y)

      # Remove the specified number of lines and shift remaining lines up
      remaining_lines = Enum.drop(after_cursor, count)

      # Add blank lines at the bottom
      blank_lines = create_empty_lines(buffer.width, count)
      new_cells = before ++ remaining_lines ++ blank_lines

      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  @doc """
  Deletes a specified number of lines with explicit parameters.
  """
  def delete_lines(
        buffer,
        count,
        cursor_y,
        _cursor_x,
        scroll_top,
        scroll_bottom
      ) do
    if cursor_y >= scroll_top and cursor_y <= scroll_bottom do
      # Split the content at the cursor position
      {before, after_cursor} = Enum.split(buffer.cells, cursor_y)

      # Remove the specified number of lines and shift remaining lines up
      remaining_lines = Enum.drop(after_cursor, count)

      # Add blank lines at the bottom
      blank_lines = create_empty_lines(buffer.width, count)
      new_cells = before ++ remaining_lines ++ blank_lines

      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  @doc """
  Prepends a specified number of empty lines to the buffer.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `count` - The number of empty lines to prepend

  ## Returns

  The updated screen buffer with empty lines prepended.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = LineOperations.prepend_lines(buffer, 2)
      iex> length(buffer.cells)
      24
  """
  @spec prepend_lines(ScreenBuffer.t(), non_neg_integer()) ::
          ScreenBuffer.t()
  def prepend_lines(buffer, count) when count > 0 do
    empty_lines = create_empty_lines(buffer.width, count)
    combined = empty_lines ++ buffer.cells
    new_cells = Enum.take(combined, buffer.height)
    removed = Enum.drop(combined, buffer.height)

    new_scrollback =
      Enum.take(removed ++ buffer.scrollback, buffer.scrollback_limit)

    %{buffer | cells: new_cells, scrollback: new_scrollback}
  end

  def prepend_lines(buffer, _count), do: buffer

  @doc """
  Removes lines from the top of the buffer.
  """
  @spec pop_top_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def pop_top_lines(buffer, count) when count > 0 do
    {_popped_lines, remaining_cells} = Enum.split(buffer.cells, count)

    # Add empty lines at the bottom
    empty_lines = create_empty_lines(buffer.width, count)
    new_cells = remaining_cells ++ empty_lines

    %{buffer | cells: new_cells}
  end

  def pop_top_lines(buffer, _count), do: buffer

  @doc """
  Gets a line from the buffer.
  """
  @spec get_line(ScreenBuffer.t(), non_neg_integer()) :: list(Cell.t())
  def get_line(buffer, line_index) do
    case buffer.cells do
      nil ->
        # Return empty list if cells is nil
        []

      cells ->
        if line_index >= 0 and line_index < length(cells) do
          Enum.at(cells, line_index) || []
        else
          []
        end
    end
  end

  @doc """
  Updates a line in the buffer with new cells.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `line_index` - The index of the line to update
  * `new_line` - The new line content

  ## Returns

  The updated screen buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> new_line = List.duplicate(%Cell{char: "A"}, 80)
      iex> buffer = LineOperations.update_line(buffer, 0, new_line)
      iex> LineOperations.get_line(buffer, 0) |> hd() |> Map.get(:char)
  """
  @spec update_line(ScreenBuffer.t(), non_neg_integer(), list(Cell.t())) ::
          ScreenBuffer.t()
  def update_line(buffer, line_index, new_line) do
    case buffer.cells do
      nil ->
        # Return buffer unchanged if cells is nil
        buffer

      cells ->
        if line_index >= 0 and line_index < length(cells) do
          new_cells = List.replace_at(cells, line_index, new_line)
          %{buffer | cells: new_cells}
        else
          buffer
        end
    end
  end

  @doc """
  Clears a line in the buffer with optional styling.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `line_index` - The index of the line to clear
  * `style` - Optional text style for the cleared line

  ## Returns

  The updated screen buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> style = %{fg: :red, bg: :blue}
      iex> buffer = LineOperations.clear_line(buffer, 0, style)
      iex> LineOperations.get_line(buffer, 0) |> hd() |> Map.get(:style)
      %{fg: :red, bg: :blue}
  """
  @spec clear_line(
          ScreenBuffer.t(),
          non_neg_integer(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def clear_line(buffer, line_index, style \\ nil) do
    empty_line = create_empty_line(buffer.width, style || buffer.default_style)
    update_line(buffer, line_index, empty_line)
  end

  @doc """
  Creates a specified number of empty lines with the given width.

  ## Parameters

  * `width` - The width of each line
  * `count` - The number of lines to create

  ## Returns

  A list of empty lines, where each line is a list of empty cells.

  ## Examples

      iex> lines = LineOperations.create_empty_lines(80, 2)
      iex> length(lines)
      2
      iex> length(hd(lines))
      80
  """
  @spec create_empty_lines(non_neg_integer(), non_neg_integer()) ::
          list(list(Cell.t()))
  def create_empty_lines(width, count) do
    for _ <- 1..count do
      create_empty_line(width)
    end
  end

  @doc """
  Creates empty lines with the given width and style.

  ## Parameters

  * `width` - The width of each line
  * `count` - The number of lines to create
  * `style` - The text style for the cells

  ## Returns

  A list of empty lines with the specified style.

  ## Examples

      iex> lines = LineOperations.create_empty_lines(80, 3, %{fg: :red})
      iex> length(lines)
      3
      iex> hd(hd(lines)).style.fg
      :red
  """
  @spec create_empty_lines(
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) ::
          list(list(Cell.t()))
  def create_empty_lines(width, count, style) do
    for _ <- 1..count do
      create_empty_line(width, style)
    end
  end

  @doc """
  Creates a single empty line with the given width and optional style.

  ## Parameters

  * `width` - The width of the line
  * `style` - Optional text style for the cells

  ## Returns

  A list of empty cells representing an empty line.

  ## Examples

      iex> line = LineOperations.create_empty_line(80)
      iex> length(line)
      80
      iex> line = LineOperations.create_empty_line(80, %{fg: :red})
      iex> hd(line).style.fg
      :red
  """
  @spec create_empty_line(non_neg_integer(), TextFormatting.text_style() | nil) ::
          list(Cell.t())
  def create_empty_line(width, style \\ nil) do
    for _ <- 1..width do
      Cell.new(" ", style)
    end
  end

  @doc """
  Erases a specified number of characters in a line.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to modify
  * `col` - The starting column
  * `count` - The number of characters to erase

  ## Returns

  The updated screen buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = LineOperations.erase_chars(buffer, 0, 0, 10)
      iex> LineOperations.get_line(buffer, 0) |> Enum.take(10) |> Enum.all?(fn cell -> cell.char == "" end)
      true
  """
  @spec erase_chars(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def erase_chars(buffer, row, col, count) do
    line = get_line(buffer, row)

    if line do
      new_line = erase_chars_in_line(line, col, count)
      update_line(buffer, row, new_line)
    else
      buffer
    end
  end

  defp erase_chars_in_line(line, col, count) do
    Enum.with_index(line)
    |> Enum.map(fn {cell, index} ->
      if index >= col and index < col + count do
        Cell.new(" ")
      else
        cell
      end
    end)
  end

  # Functions expected by tests
  @doc """
  Inserts lines at a specific position.
  """
  @spec insert_lines(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def insert_lines(buffer, position, count) do
    if position >= 0 and position < length(buffer.cells) and count > 0 do
      do_insert_lines(buffer, position, count, length(buffer.cells) - 1)
    else
      buffer
    end
  end

  @doc """
  Inserts lines at a specific position with style.
  """
  @spec insert_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) ::
          ScreenBuffer.t()
  def insert_lines(buffer, position, count, style) do
    if position >= 0 and position < length(buffer.cells) and count > 0 do
      do_insert_lines_with_style(
        buffer,
        position,
        count,
        length(buffer.cells) - 1,
        style
      )
    else
      buffer
    end
  end

  @doc """
  Inserts lines at a specific position with region boundaries.
  """
  @spec insert_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          ScreenBuffer.t()
  def insert_lines(buffer, lines, y, top, bottom) do
    if y >= top and y <= bottom and lines > 0 do
      do_insert_lines(buffer, y, lines, bottom)
    else
      buffer
    end
  end

  @doc """
  Deletes lines at a specific position.
  """
  @spec delete_lines(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def delete_lines(buffer, position, count) do
    if position >= 0 and position < length(buffer.cells) and count > 0 do
      {before, after_cursor} = Enum.split(buffer.cells, position)
      remaining_lines = Enum.drop(after_cursor, count)
      blank_lines = create_empty_lines(buffer.width, count)
      new_cells = before ++ remaining_lines ++ blank_lines
      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  @doc """
  Deletes lines at a specific position with style and region boundaries.
  """
  @spec delete_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style(),
          {non_neg_integer(), non_neg_integer()}
        ) ::
          ScreenBuffer.t()
  def delete_lines(buffer, y, count, style, {top, bottom}) do
    if y >= top and y <= bottom and count > 0 do
      do_delete_lines_in_region(buffer, y, count, style, top, bottom)
    else
      buffer
    end
  end

  defp do_delete_lines_in_region(buffer, y, count, style, top, bottom) do
    # Split buffer into parts: before region, region, after region
    {before_region, rest} = Enum.split(buffer.cells, top)
    {region, after_region} = Enum.split(rest, bottom - top + 1)

    # Calculate relative position within the region
    rel_y = y - top

    # Split region at cursor position
    {region_before_cursor, region_at_and_after_cursor} =
      Enum.split(region, rel_y)

    # Remove the lines to be deleted
    region_after_deleted = Enum.drop(region_at_and_after_cursor, count)

    # Create blank lines to add at the bottom of the region
    blank_lines = create_empty_lines(buffer.width, count, style)

    # Reassemble the region: before cursor + after deleted + blank lines at bottom
    new_region = region_before_cursor ++ region_after_deleted ++ blank_lines

    # Reassemble the entire buffer
    new_cells = before_region ++ new_region ++ after_region

    # Ensure buffer maintains its height
    final_cells = Enum.take(new_cells, buffer.height)
    %{buffer | cells: final_cells}
  end

  def delete_lines(buffer, _y, _count, _style, region)
      when not is_tuple(region),
      do: buffer

  @doc """
  Deletes lines at the specified position within the scroll region.
  """
  def delete_lines_in_region(buffer, lines, y, top, bottom) do
    # Ensure we're within the scroll region
    y = max(top, min(y, bottom - 1))

    # Calculate how many lines we can actually delete
    available_lines = bottom - y
    lines_to_delete = min(lines, available_lines)

    if lines_to_delete > 0 do
      # Delete lines from y to y + lines_to_delete - 1
      # This shifts content up from below the deleted region
      buffer
      |> delete_lines_from_position(y, lines_to_delete, bottom)
    else
      buffer
    end
  end

  defp delete_lines_from_position(buffer, start_y, count, bottom) do
    # Shift lines from below the deletion region up
    Enum.reduce(start_y..(bottom - count - 1), buffer, fn y, acc ->
      # Get the line that should move up
      source_line = get_line(acc, y + count)
      # Set it at the current position
      set_line(acc, y, source_line)
    end)
    |> then(fn acc ->
      # Fill the bottom lines with empty content
      Enum.reduce((bottom - count)..(bottom - 1), acc, fn y, acc ->
        set_line(acc, y, create_empty_line())
      end)
    end)
  end

  defp create_empty_line do
    # Create an empty line with default attributes
    # Use the existing function with default width
    create_empty_line(80)
  end

  @doc """
  Sets a line at a specific position.
  """
  @spec set_line(ScreenBuffer.t(), non_neg_integer(), list(Cell.t())) ::
          ScreenBuffer.t()
  def set_line(buffer, position, new_line) do
    if position >= 0 and position < length(buffer.cells) do
      new_cells = List.replace_at(buffer.cells, position, new_line)
      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  @doc """
  Deletes a specified number of characters from the current line.
  """
  @spec delete_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_chars(buffer, count) when count > 0 do
    {x, y} = buffer.cursor_position
    delete_chars_at(buffer, y, x, count)
  end

  def delete_chars(buffer, _count), do: buffer

  @doc """
  Deletes characters at a specific position.
  """
  @spec delete_chars_at(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def delete_chars_at(buffer, row, col, count) do
    if row >= 0 and row < length(buffer.cells) and col >= 0 and
         col < buffer.width do
      line = get_line(buffer, row)

      new_line =
        delete_chars_from_line(
          line,
          col,
          count,
          buffer.width,
          buffer.default_style
        )

      update_line(buffer, row, new_line)
    else
      buffer
    end
  end

  @doc """
  Inserts a specified number of characters at the current position.
  """
  @spec insert_chars(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_chars(buffer, count) when count > 0 do
    {x, y} = buffer.cursor_position
    insert_chars_at(buffer, y, x, count)
  end

  def insert_chars(buffer, _count), do: buffer

  @doc """
  Inserts characters at a specific position.
  """
  @spec insert_chars_at(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def insert_chars_at(buffer, row, col, count) do
    if row >= 0 and row < length(buffer.cells) and col >= 0 and
         col < buffer.width do
      line = get_line(buffer, row)

      new_line =
        insert_chars_into_line(
          line,
          col,
          count,
          buffer.width,
          buffer.default_style
        )

      update_line(buffer, row, new_line)
    else
      buffer
    end
  end

  # Helper functions for character operations
  defp delete_chars_from_line(line, col, count, width, default_style) do
    {before, after_part} = Enum.split(line, col)
    {_, remaining} = Enum.split(after_part, count)

    # Create a new line with the correct content
    new_line = before ++ remaining

    # Ensure the line has the correct width by padding with empty cells
    if length(new_line) < width do
      new_line ++ create_empty_line(width - length(new_line), default_style)
    else
      Enum.take(new_line, width)
    end
  end

  defp insert_chars_into_line(line, col, count, width, default_style) do
    # If the character at the cursor is a space, skip it when inserting
    {before, after_part} = Enum.split(line, col)

    # If the first char in after_part is a space, drop it (to avoid duplicating the space)
    after_part =
      case after_part do
        [%{char: " "} | rest] -> rest
        _ -> after_part
      end

    blank_cell = %Cell{
      char: " ",
      style: default_style,
      dirty: false,
      wide_placeholder: false
    }

    empty_chars = List.duplicate(blank_cell, count)
    new_line = before ++ empty_chars ++ after_part
    Enum.take(new_line, width)
  end
end
