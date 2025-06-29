defmodule Raxol.Terminal.Buffer.CharEditor do
  import Raxol.Guards

  @moduledoc """
  Manages terminal character editing operations.
  """

  alias Raxol.Terminal.Cell

  @doc """
  Inserts a character at the current position.
  """
  def insert_char(%Cell{} = cell, char) when binary?(char) do
    %{cell | char: char}
  end

  @doc """
  Deletes a character at the current position.
  """
  def delete_char(%Cell{} = cell) do
    %{cell | char: " "}
  end

  @doc """
  Replaces a character at the current position.
  """
  def replace_char(%Cell{} = cell, char) when binary?(char) do
    %{cell | char: char}
  end

  @doc """
  Inserts a string of characters.
  """
  def insert_string(%Cell{} = cell, string) when binary?(string) do
    case String.length(string) do
      0 -> cell
      1 -> insert_char(cell, string)
      _ -> %{cell | char: string, width: String.length(string)}
    end
  end

  @doc """
  Deletes a string of characters.
  """
  def delete_string(%Cell{} = cell, length)
      when integer?(length) and length > 0 do
    case length do
      1 -> delete_char(cell)
      _ -> %{cell | char: " ", width: 1}
    end
  end

  @doc """
  Replaces a string of characters.
  """
  def replace_string(%Cell{} = cell, string) when binary?(string) do
    case String.length(string) do
      0 -> cell
      1 -> replace_char(cell, string)
      _ -> %{cell | char: string, width: String.length(string)}
    end
  end

  @doc """
  Checks if a character is a control character.
  """
  def control_char?(char) when binary?(char) do
    case String.to_charlist(char) do
      [c] when c < 32 or c == 127 -> true
      _ -> false
    end
  end

  @doc """
  Checks if a character is a printable character.
  """
  def printable_char?(char) when binary?(char) do
    case String.to_charlist(char) do
      [c] when c >= 32 and c != 127 -> true
      _ -> false
    end
  end

  @doc """
  Checks if a character is a whitespace character.
  """
  def whitespace_char?(char) when binary?(char) do
    char in [" ", "\t", "\n", "\r"]
  end

  @doc """
  Gets the width of a character.
  """
  def char_width(char) when binary?(char) do
    case String.to_charlist(char) do
      [c] when c < 32 or c == 127 -> 0
      [c] when c < 128 -> 1
      _ -> 2
    end
  end

  @doc """
  Gets the width of a string.
  """
  def string_width(string) when binary?(string) do
    string
    |> String.to_charlist()
    |> Enum.map(&char_width/1)
    |> Enum.sum()
  end

  @doc """
  Determines the content length of a line (number of non-blank characters).
  """
  def content_length(line) do
    line
    |> Enum.take_while(fn cell -> cell.char != " " end)
    |> length()
  end

  @doc """
  Truncates a line to the specified content length, padding with blank cells if needed.
  """
  def truncate_to_content_length(line, content_length) do
    if length(line) <= content_length do
      # Pad with blank cells if line is shorter than content length
      padding = List.duplicate(Cell.new(" "), content_length - length(line))
      line ++ padding
    else
      # Truncate to content length
      Enum.take(line, content_length)
    end
  end

  defp pad_or_truncate_line(line, width) do
    len = length(line)
    cond do
      len < width -> line ++ List.duplicate(Cell.new(" "), width - len)
      len > width -> Enum.take(line, width)
      true -> line
    end
  end

  @doc """
  Inserts a specified number of characters at the given position.
  Characters to the right of the insertion point are shifted right.
  Characters shifted off the end of the line are discarded.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to insert characters in
  * `col` - The column to start inserting at
  * `count` - The number of characters to insert

  ## Returns

  The updated screen buffer.
  """
  @spec insert_chars(
          Raxol.Terminal.ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Raxol.Terminal.ScreenBuffer.t()
  def insert_chars(buffer, row, col, count)
      when row >= 0 and col >= 0 and count > 0 do
    if row >= buffer.height or col >= buffer.width do
      buffer
    else
      line = Enum.at(buffer.cells, row)
      orig_content_length = content_length(line)
      # If line is blank, use the column position as the content length
      effective_content_length = if orig_content_length == 0, do: col, else: orig_content_length
      {left, _right} = Enum.split(line, col)
      blanks = Enum.map(1..count, fn _ -> Cell.new(" ") end)
      new_line = left ++ blanks ++ Enum.slice(line, col, effective_content_length - col)
      new_line = Enum.take(new_line, effective_content_length + count)
      new_line = pad_or_truncate_line(new_line, buffer.width)
      cells = List.replace_at(buffer.cells, row, new_line)
      %{buffer | cells: cells}
    end
  end

  @doc """
  Inserts a specified number of characters at the given position.
  Characters to the right of the insertion point are shifted right.
  Characters shifted off the end of the line are discarded.
  Uses the provided default style for new characters.

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
      iex> buffer = CharEditor.insert_characters(buffer, 0, 0, 5, style)
      iex> CharEditor.get_char(buffer, 0, 0)
      " "
  """
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
      cells =
        List.replace_at(
          buffer.cells,
          row,
          insert_into_line(
            Enum.at(buffer.cells, row),
            col,
            count,
            default_style
          )
        )

      %{buffer | cells: cells}
    end
  end

  @doc """
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
      iex> new_line = CharEditor.insert_into_line(line, 5, 3, style)
      iex> length(new_line)
      10
  """
  @spec insert_into_line(
          list(Cell.t()),
          non_neg_integer(),
          non_neg_integer(),
          Raxol.Terminal.ANSI.TextFormatting.text_style()
        ) :: list(Cell.t())
  def insert_into_line(line, col, count, default_style) do
    orig_content_length = content_length(line)
    {left_part, _right_part} = Enum.split(line, col)
    blank_cell = Cell.new(" ", default_style)
    blank_cells = List.duplicate(blank_cell, count)
    result = left_part ++ blank_cells ++ Enum.slice(line, col, orig_content_length - col)
    result = Enum.take(result, orig_content_length + count)
    pad_or_truncate_line(result, length(line))
  end

  @doc """
  Deletes a specified number of characters starting from the given position.
  Characters to the right of the deleted characters are shifted left.
  Blank characters are added at the end of the line.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to delete characters from
  * `col` - The column to start deleting from
  * `count` - The number of characters to delete

  ## Returns

  The updated screen buffer.
  """
  @spec delete_chars(
          Raxol.Terminal.ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Raxol.Terminal.ScreenBuffer.t()
  def delete_chars(buffer, row, col, count)
      when row >= 0 and col >= 0 and count > 0 do
    if row >= buffer.height or col >= buffer.width do
      buffer
    else
      line = Enum.at(buffer.cells, row)

      # Split the line into left (before deletion) and right (after deletion)
      {left, _} = Enum.split(line, col)
      right = Enum.slice(line, col + count, buffer.width)

      # Combine left + right
      new_line = left ++ right
      # Always pad to buffer.width
      new_line = new_line ++ List.duplicate(Cell.new(" "), max(0, buffer.width - length(new_line)))
      new_line = Enum.take(new_line, buffer.width)

      cells = List.replace_at(buffer.cells, row, new_line)
      %{buffer | cells: cells}
    end
  end
  def delete_chars(buffer, _row, _col, count) when count <= 0, do: buffer

  @doc """
  Deletes a specified number of characters starting from the given position.
  Characters to the right of the deleted characters are shifted left.
  Blank characters are added at the end of the line with the specified style.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to delete characters from
  * `col` - The column to start deleting from
  * `count` - The number of characters to delete
  * `default_style` - The style to apply to new blank characters

  ## Returns

  The updated screen buffer.
  """
  @spec delete_characters(
          Raxol.Terminal.ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Raxol.Terminal.ANSI.TextFormatting.text_style()
        ) :: Raxol.Terminal.ScreenBuffer.t()
  def delete_characters(buffer, row, col, count, default_style)
      when row >= 0 and col >= 0 and count > 0 do
    if row >= buffer.height or col >= buffer.width do
      buffer
    else
      cells =
        List.replace_at(
          buffer.cells,
          row,
          delete_from_line(
            Enum.at(buffer.cells, row),
            col,
            count,
            default_style
          )
        )

      %{buffer | cells: cells}
    end
  end

  @doc """
  Deletes characters from a line at the specified position.

  ## Parameters

  * `line` - The line to modify
  * `col` - The column to start deleting from
  * `count` - The number of characters to delete
  * `default_style` - The style to apply to new blank characters

  ## Returns

  The updated line with deleted characters replaced by blanks.

  ## Examples

      iex> line = List.duplicate(%Cell{}, 10)
      iex> style = %{fg: :red, bg: :blue}
      iex> new_line = CharEditor.delete_from_line(line, 5, 3, style)
      iex> length(new_line)
      10
  """
  @spec delete_from_line(
          list(Cell.t()),
          non_neg_integer(),
          non_neg_integer(),
          Raxol.Terminal.ANSI.TextFormatting.text_style()
        ) :: list(Cell.t())
  def delete_from_line(line, col, count, default_style) do
    line_length = length(line)

    # Split the line into left part (before deletion point) and right part (after deletion)
    {left_part, right_part} = Enum.split(line, col)

    # Remove the characters to be deleted from the right part
    remaining_right = Enum.slice(right_part, count, line_length - col - count)

    # Create blank cells to fill the end of the line
    blank_cell = Cell.new(" ", default_style)
    blanks_needed = line_length - length(left_part) - length(remaining_right)
    blank_cells = List.duplicate(blank_cell, blanks_needed)

    # Combine left part + remaining right part + blank cells
    result = left_part ++ remaining_right ++ blank_cells

    # Ensure the result has the correct length
    Enum.take(result, line_length)
  end

  @doc """
  Writes a character at the specified position in the buffer.
  """
  def write_char(buffer, row, col, char) when binary?(char) do
    if row >= 0 and row < buffer.height and col >= 0 and col < buffer.width do
      line = Enum.at(buffer.cells, row)
      updated_line = List.replace_at(line, col, Cell.new(char))
      cells = List.replace_at(buffer.cells, row, updated_line)
      %{buffer | cells: cells}
    else
      buffer
    end
  end

  @doc """
  Writes a string at the specified position in the buffer.
  """
  def write_string(buffer, row, col, string) when binary?(string) do
    if row >= 0 and row < buffer.height and col >= 0 and col < buffer.width do
      line = Enum.at(buffer.cells, row)
      orig_len = length(line)
      chars = String.graphemes(string)
      max_len = orig_len - col
      chars = Enum.take(chars, max_len)
      updated_line = Enum.with_index(line)
      |> Enum.map(fn {cell, idx} ->
        if idx >= col and idx < col + length(chars) do
          char = Enum.at(chars, idx - col)
          Cell.new(char)
        else
          cell
        end
      end)
      updated_line = Enum.take(updated_line, orig_len)
      cells = List.replace_at(buffer.cells, row, updated_line)
      %{buffer | cells: cells}
    else
      buffer
    end
  end

  def update_line_with_string(line, col, string, width) do
    chars = String.graphemes(string)

    Enum.reduce(Enum.with_index(chars), line, fn {char, index}, acc_line ->
      pos = col + index

      if pos < width do
        List.replace_at(acc_line, pos, Cell.new(char))
      else
        acc_line
      end
    end)
  end

  @doc """
  Erases a specified number of characters starting from the given position.
  Characters to the right of the erased characters are shifted left.
  Blank characters are added at the end of the line.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to erase characters from
  * `col` - The column to start erasing from
  * `count` - The number of characters to erase

  ## Returns

  The updated screen buffer.
  """
  def erase_chars(buffer, row, col, count) when row >= 0 and col >= 0 and count > 0 do
    if row >= buffer.height or col >= buffer.width do
      buffer
    else
      line = Enum.at(buffer.cells, row)

      # Split the line into left (before erasure) and right (after erasure)
      {left, _} = Enum.split(line, col)
      right = Enum.slice(line, col + count, buffer.width)

      # Combine left + right
      new_line = left ++ right
      # Always pad to buffer.width
      new_line = new_line ++ List.duplicate(Cell.new(" "), max(0, buffer.width - length(new_line)))
      new_line = Enum.take(new_line, buffer.width)

      cells = List.replace_at(buffer.cells, row, new_line)
      %{buffer | cells: cells}
    end
  end

  @doc """
  Erases a specified number of characters starting from the given position.
  Characters to the right of the erased characters are shifted left.
  Blank characters are added at the end of the line with the specified style.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to erase characters from
  * `col` - The column to start erasing from
  * `count` - The number of characters to erase
  * `style` - The style to apply to new blank characters

  ## Returns

  The updated screen buffer.
  """
  def erase_chars(buffer, row, col, count, style) when row >= 0 and col >= 0 and count > 0 do
    if row >= buffer.height or col >= buffer.width do
      buffer
    else
      line = Enum.at(buffer.cells, row)

      # Split the line into left (before erasure) and right (after erasure)
      {left, _} = Enum.split(line, col)
      right = Enum.slice(line, col + count, buffer.width)

      # Combine left + right
      new_line = left ++ right
      # Always pad to buffer.width with styled spaces
      new_line = new_line ++ List.duplicate(Cell.new(" ", style), max(0, buffer.width - length(new_line)))
      new_line = Enum.take(new_line, buffer.width)

      cells = List.replace_at(buffer.cells, row, new_line)
      %{buffer | cells: cells}
    end
  end

  def replace_chars(buffer, row, col, string, style) when row >= 0 and col >= 0 and is_binary(string) do
    if row >= buffer.height or col >= buffer.width do
      buffer
    else
      line = Enum.at(buffer.cells, row)
      line_len = length(line)

      # Truncate replacement string if it would overflow the line
      max_replace = max(0, line_len - col)
      chars = String.graphemes(string) |> Enum.take(max_replace)
      rep_len = length(chars)

      # Split the line into left (before replacement)
      {left, _} = Enum.split(line, col)

      # Create replacement cells
      rep_cells = Enum.map(chars, fn c ->
        if style, do: Cell.new(c, style), else: Cell.new(c)
      end)

      # The right segment should be empty if we're replacing at the end
      # or should contain characters after the replacement
      right = if col + rep_len < line_len do
        Enum.slice(line, col + rep_len, line_len - (col + rep_len))
      else
        []
      end

      # Combine left + replacement + right
      new_line = left ++ rep_cells ++ right
      new_line = pad_or_truncate_line(new_line, buffer.width)

      cells = List.replace_at(buffer.cells, row, new_line)
      %{buffer | cells: cells}
    end
  end

  def replace_chars(buffer, row, col, string) when is_binary(string) do
    replace_chars(buffer, row, col, string, nil)
  end

  # Catch-all clauses for invalid input
  def insert_chars(buffer, _row, _col, _count), do: buffer
  def delete_chars(buffer, _row, _col, _count), do: buffer
  def erase_chars(buffer, _row, _col, count) when count <= 0, do: buffer
  def erase_chars(buffer, _row, _col, _count, _style), do: buffer

end
