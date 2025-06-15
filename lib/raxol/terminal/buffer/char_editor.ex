defmodule Raxol.Terminal.Buffer.CharEditor do
  @moduledoc """
  Manages terminal character editing operations.
  """

  alias Raxol.Terminal.Buffer.Cell

  @doc """
  Inserts a character at the current position.
  """
  def insert_char(%Cell{} = cell, char) when is_binary(char) do
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
  def replace_char(%Cell{} = cell, char) when is_binary(char) do
    %{cell | char: char}
  end

  @doc """
  Inserts a string of characters.
  """
  def insert_string(%Cell{} = cell, string) when is_binary(string) do
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
      when is_integer(length) and length > 0 do
    case length do
      1 -> delete_char(cell)
      _ -> %{cell | char: " ", width: 1}
    end
  end

  @doc """
  Replaces a string of characters.
  """
  def replace_string(%Cell{} = cell, string) when is_binary(string) do
    case String.length(string) do
      0 -> cell
      1 -> replace_char(cell, string)
      _ -> %{cell | char: string, width: String.length(string)}
    end
  end

  @doc """
  Checks if a character is a control character.
  """
  def control_char?(char) when is_binary(char) do
    case String.to_charlist(char) do
      [c] when c < 32 or c == 127 -> true
      _ -> false
    end
  end

  @doc """
  Checks if a character is a printable character.
  """
  def printable_char?(char) when is_binary(char) do
    case String.to_charlist(char) do
      [c] when c >= 32 and c != 127 -> true
      _ -> false
    end
  end

  @doc """
  Checks if a character is a whitespace character.
  """
  def whitespace_char?(char) when is_binary(char) do
    char in [" ", "\t", "\n", "\r"]
  end

  @doc """
  Gets the width of a character.
  """
  def char_width(char) when is_binary(char) do
    case String.to_charlist(char) do
      [c] when c < 32 or c == 127 -> 0
      [c] when c < 128 -> 1
      _ -> 2
    end
  end

  @doc """
  Gets the width of a string.
  """
  def string_width(string) when is_binary(string) do
    string
    |> String.to_charlist()
    |> Enum.map(&char_width/1)
    |> Enum.sum()
  end

  @doc """
  Inserts a specified number of blank characters at the given position.
  Characters to the right of the insertion point are shifted right.
  Characters shifted off the end of the line are discarded.
  Uses the provided default style for new characters.
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
      cells = List.replace_at(buffer.cells, row, insert_into_line(Enum.at(buffer.cells, row), col, count, default_style))
      %{buffer | cells: cells}
    end
  end

  defp insert_into_line(line, col, count, default_style) do
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

  @doc """
  Deletes a specified number of characters starting from the given position.
  Characters to the right of the deleted characters are shifted left.
  Blank characters are added at the end of the line using the provided default style.
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
    # Ensure row and col are within bounds
    if row >= buffer.height or col >= buffer.width do
      buffer
    else
      # Get the current line
      line = Enum.at(buffer.cells, row)

      # Split the line at the deletion point
      {left_part, right_part} = Enum.split(line, col)

      # Remove the characters to be deleted
      remaining_right_part = Enum.drop(right_part, count)

      # Create blank cells to fill the end of the line
      blank_cell = %Cell{
        char: " ",
        foreground: default_style.foreground,
        background: default_style.background,
        attributes: default_style.attributes
      }

      blank_cells = List.duplicate(blank_cell, count)

      # Combine the parts
      new_line = left_part ++ remaining_right_part ++ blank_cells

      # Update the buffer
      cells = List.replace_at(buffer.cells, row, new_line)
      %{buffer | cells: cells}
    end
  end
end
