defmodule Raxol.Terminal.Buffer.LineOperations do
  @moduledoc """
  Provides line-level operations for the screen buffer.
  This module handles operations like inserting, deleting, and manipulating lines.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Inserts a specified number of blank lines at the current cursor position.
  Lines below the cursor are shifted down, and lines shifted off the bottom are discarded.
  """
  @spec insert_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_lines(buffer, count) when is_integer(count) and count > 0 do
    {_, y} = Raxol.Terminal.Cursor.get_position(buffer)

    {top, bottom} =
      Raxol.Terminal.ScreenBuffer.ScrollRegion.get_boundaries(
        buffer.scroll_state
      )

    # Only insert lines within the scroll region
    if y >= top and y <= bottom do
      do_insert_lines(buffer, y, count, bottom)
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
  Deletes a specified number of lines starting from the current cursor position.
  Lines below the deleted lines are shifted up, and blank lines are added at the bottom.
  """
  @spec delete_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_lines(buffer, count) when is_integer(count) and count > 0 do
    {_x, y} = Raxol.Terminal.Cursor.get_position(buffer)

    {top, bottom} =
      Raxol.Terminal.ScreenBuffer.ScrollRegion.get_boundaries(
        buffer.scroll_state
      )

    # Only delete lines within the scroll region
    if y >= top and y <= bottom do
      # Split the content at the cursor position
      {before, after_cursor} = Enum.split(buffer.cells, y)

      # Remove the specified number of lines and shift remaining lines up
      remaining_lines = Enum.drop(after_cursor, count)

      # Add blank lines at the bottom
      blank_lines = List.duplicate(List.duplicate(%{}, buffer.width), count)
      new_cells = before ++ remaining_lines ++ blank_lines

      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  @doc """
  Prepends lines to the top of the screen buffer, shifting existing content down.
  Lines shifted off the bottom are moved to the scrollback buffer.
  """
  @spec prepend_lines(ScreenBuffer.t(), list(list(Cell.t()))) ::
          ScreenBuffer.t()
  def prepend_lines(buffer, lines) do
    # Calculate how many lines will be shifted to scrollback
    overflow = max(0, length(lines) - buffer.height)

    # Split lines into those that fit and those that go to scrollback
    {visible_lines, scrollback_lines} = Enum.split(lines, buffer.height)

    # Shift existing content down
    {shifted_content, new_scrollback} =
      if overflow > 0 do
        # Some existing content will be moved to scrollback
        {existing_visible, existing_scrollback} =
          Enum.split(buffer.cells, buffer.height - length(visible_lines))

        {visible_lines ++ existing_visible,
         existing_scrollback ++ buffer.scrollback}
      else
        # All existing content stays visible
        {visible_lines ++
           Enum.take(buffer.cells, buffer.height - length(visible_lines)),
         buffer.scrollback}
      end

    # Update scrollback buffer, respecting the limit
    final_scrollback =
      Enum.take(scrollback_lines ++ new_scrollback, buffer.scrollback_limit)

    %{buffer | cells: shifted_content, scrollback: final_scrollback}
  end

  @doc """
  Removes lines from the top of the buffer.
  """
  @spec pop_top_lines(ScreenBuffer.t(), non_neg_integer()) ::
          {list(list(Cell.t())), ScreenBuffer.t()}
  def pop_top_lines(buffer, count) do
    {popped_lines, remaining_cells} = Enum.split(buffer.cells, count)

    # Add empty lines at the bottom
    empty_lines = create_empty_lines(buffer.width, count)
    new_cells = remaining_cells ++ empty_lines

    {popped_lines, %{buffer | cells: new_cells}}
  end

  @doc """
  Gets a line from the buffer.
  """
  @spec get_line(ScreenBuffer.t(), non_neg_integer()) :: list(Cell.t()) | nil
  def get_line(buffer, line_index) do
    Enum.at(buffer.cells, line_index)
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
      "A"
  """
  @spec update_line(ScreenBuffer.t(), non_neg_integer(), list(Cell.t())) ::
          ScreenBuffer.t()
  def update_line(buffer, line_index, new_line) do
    new_cells = List.update_at(buffer.cells, line_index, fn _ -> new_line end)
    %{buffer | cells: new_cells}
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
      Cell.new("", style)
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
      new_line = List.update_at(line, col, fn _ -> Cell.new("") end)
      update_line(buffer, row, new_line)
    else
      buffer
    end
  end
end
