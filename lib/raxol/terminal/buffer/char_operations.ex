alias Raxol.Terminal.Buffer.Cell

defmodule Raxol.Terminal.Buffer.CharOperations do
  @moduledoc '''
  Handles character-based operations in the terminal buffer.
  '''

  @doc '''
  Inserts a specified number of blank characters at the current cursor position.
  Characters to the right of the cursor are shifted right, and characters shifted off the end are discarded.
  '''
  @spec insert_chars(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer()) :: Raxol.Terminal.ScreenBuffer.t()
  def insert_chars(buffer, count) when is_integer(count) and count > 0 do
    {x, y} = Raxol.Terminal.Cursor.get_position(buffer)
    {top, bottom} = Raxol.Terminal.ScreenBuffer.ScrollRegion.get_boundaries(buffer.scroll_state)

    if in_scroll_region?(y, top, bottom) do
      insert_chars_at_position(buffer, x, y, count)
    else
      buffer
    end
  end

  defp in_scroll_region?(y, top, bottom), do: y >= top and y <= bottom

  defp insert_chars_at_position(buffer, x, y, count) do
    line = Enum.at(buffer.content, y, [])
    new_line = create_line_with_insertion(line, x, count, buffer.width)
    new_content = List.replace_at(buffer.content, y, new_line)
    %{buffer | content: new_content}
  end

  defp create_line_with_insertion(line, x, count, width) do
    {before_cursor, after_cursor} = Enum.split(line, x)
    blank_chars = List.duplicate(%{}, count)
    before_cursor ++ blank_chars ++ Enum.take(after_cursor, width - x - count)
  end

  @doc '''
  Deletes a specified number of characters starting from the current cursor position.
  Characters to the right of the deleted characters are shifted left, and blank characters are added at the end.
  '''
  @spec delete_chars(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer()) :: Raxol.Terminal.ScreenBuffer.t()
  def delete_chars(buffer, count) when is_integer(count) and count > 0 do
    {x, y} = Raxol.Terminal.Cursor.get_position(buffer)
    {top, bottom} = Raxol.Terminal.ScreenBuffer.ScrollRegion.get_boundaries(buffer.scroll_state)

    # Only delete characters within the scroll region
    if y >= top and y <= bottom do
      line = Enum.at(buffer.content, y, [])
      new_line = delete_chars_from_line(line, x, count)

      # Update the content
      new_content = List.replace_at(buffer.content, y, new_line)
      %{buffer | content: new_content}
    else
      buffer
    end
  end

  @doc '''
  Helper function that handles the line manipulation logic for deleting characters.
  Splits the line at the cursor position, removes characters, and adds blanks at the end.

  ## Parameters

  * `line` - The line to modify
  * `x` - The column to start deleting from
  * `count` - The number of characters to delete

  ## Returns

  The updated line with characters deleted and blanks added at the end.

  ## Examples

      iex> line = List.duplicate(%Cell{char: "A"}, 10)
      iex> new_line = CharOperations.delete_chars_from_line(line, 5, 3)
      iex> length(new_line)
      10
      iex> Enum.at(new_line, 5).char
      " "
  '''
  @spec delete_chars_from_line(list(Cell.t()), non_neg_integer(), non_neg_integer()) :: list(Cell.t())
  def delete_chars_from_line(line, x, count) do
    {before_cursor, after_cursor} = Enum.split(line, x)

    # Remove the specified number of characters and shift remaining characters left
    remaining_chars = Enum.drop(after_cursor, count)

    # Add blank characters at the end
    blank_chars = List.duplicate(%{}, count)
    before_cursor ++ remaining_chars ++ blank_chars
  end

  @doc '''
  Inserts a specified number of blank characters at the given position.
  Characters to the right of the insertion point are shifted right.
  Characters shifted off the end of the line are discarded.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to insert characters in
  * `col` - The column to start inserting at
  * `count` - The number of characters to insert
  * `default_style` - The style to apply to new characters

  ## Returns

  The updated screen buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> style = %{fg: :red, bg: :blue}
      iex> buffer = CharOperations.insert_characters(buffer, 0, 0, 5, style)
      iex> CharOperations.get_char(buffer, 0, 0)
      " "
  '''
  @spec insert_characters(
          Raxol.Terminal.ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Raxol.Terminal.ANSI.TextFormatting.text_style()
        ) :: Raxol.Terminal.ScreenBuffer.t()
  def insert_characters(buffer, row, col, count, default_style)
      when row >= 0 and col >= 0 and count > 0 do
    if row >= buffer.height or col >= buffer.width do
      buffer
    else
      cells = List.replace_at(buffer.cells, row, insert_into_line(Enum.at(buffer.cells, row), col, count, default_style))
      %{buffer | cells: cells}
    end
  end

  @doc '''
  Inserts characters into a line at the specified position.

  ## Parameters

  * `line` - The line to modify
  * `col` - The column to start inserting at
  * `count` - The number of characters to insert
  * `default_style` - The style to apply to new characters

  ## Returns

  The updated line with inserted characters.

  ## Examples

      iex> line = List.duplicate(%Cell{}, 10)
      iex> style = %{fg: :red, bg: :blue}
      iex> new_line = CharOperations.insert_into_line(line, 5, 3, style)
      iex> length(new_line)
      10
  '''
  @spec insert_into_line(list(Cell.t()), non_neg_integer(), non_neg_integer(), Raxol.Terminal.ANSI.TextFormatting.text_style()) :: list(Cell.t())
  def insert_into_line(line, col, count, default_style) do
    {left_part, right_part} = Enum.split(line, col)
    blank_cell = %Cell{
      char: " ",
      foreground: default_style.foreground,
      background: default_style.background,
      attributes: default_style.attributes
    }
    blank_cells = List.duplicate(blank_cell, count)
    kept_right_part = Enum.take(right_part, length(line) - col - count)
    left_part ++ blank_cells ++ kept_right_part
  end
end
