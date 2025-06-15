defmodule Raxol.Terminal.Buffer.CharOperations do
  @moduledoc """
  Handles character-based operations in the terminal buffer.
  """

  @doc """
  Inserts a specified number of blank characters at the current cursor position.
  Characters to the right of the cursor are shifted right, and characters shifted off the end are discarded.
  """
  @spec insert_chars(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer()) :: Raxol.Terminal.ScreenBuffer.t()
  def insert_chars(buffer, count) when is_integer(count) and count > 0 do
    {x, y} = Raxol.Terminal.Cursor.get_position(buffer)
    {top, bottom} = Raxol.Terminal.ScreenBuffer.ScrollRegion.get_boundaries(buffer.scroll_state)

    # Only insert characters within the scroll region
    if y >= top and y <= bottom do
      # Get the current line
      line = Enum.at(buffer.content, y, [])
      {before_cursor, after_cursor} = Enum.split(line, x)

      # Create blank characters
      blank_chars = List.duplicate(%{}, count)

      # Combine the parts, ensuring we don't exceed the line width
      new_line = before_cursor ++ blank_chars ++ Enum.take(after_cursor, buffer.width - x - count)

      # Update the content
      new_content = List.replace_at(buffer.content, y, new_line)

      %{buffer | content: new_content}
    else
      buffer
    end
  end

  @doc """
  Deletes a specified number of characters starting from the current cursor position.
  Characters to the right of the deleted characters are shifted left, and blank characters are added at the end.
  """
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

  @doc """
  Helper function that handles the line manipulation logic for deleting characters.
  Splits the line at the cursor position, removes characters, and adds blanks at the end.
  """
  defp delete_chars_from_line(line, x, count) do
    {before_cursor, after_cursor} = Enum.split(line, x)

    # Remove the specified number of characters and shift remaining characters left
    remaining_chars = Enum.drop(after_cursor, count)

    # Add blank characters at the end
    blank_chars = List.duplicate(%{}, count)
    before_cursor ++ remaining_chars ++ blank_chars
  end
end
