defmodule Raxol.Terminal.Buffer.Paste do
  @moduledoc """
  Handles pasting text into the terminal buffer.
  This module is responsible for inserting text at the cursor position,
  handling multi-line text, and managing buffer overflow.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Writer
  alias Raxol.Terminal.Buffer.LineOperations

  @doc """
  Pastes text into the buffer at the current cursor position.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `text` - The text to paste

  ## Returns

  The updated screen buffer with the pasted text.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = %{buffer | cursor_position: {5, 10}}
      iex> Paste.paste(buffer, "Hello World")
      %ScreenBuffer{cells: [...], cursor_position: {16, 10}}
  """
  @spec paste(ScreenBuffer.t(), String.t()) :: ScreenBuffer.t()
  def paste(%ScreenBuffer{} = buffer, text) when is_binary(text) do
    {cursor_x, cursor_y} = buffer.cursor_position

    # Split text into lines
    lines = String.split(text, "\n")

    case lines do
      [single_line] ->
        # Single line paste
        paste_single_line(buffer, single_line, cursor_x, cursor_y)

      [first_line | remaining_lines] ->
        # Multi-line paste
        paste_multiline(buffer, first_line, remaining_lines, cursor_x, cursor_y)
    end
  end

  @doc """
  Pastes a single line of text at the specified position.
  """
  @spec paste_single_line(
          ScreenBuffer.t(),
          String.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def paste_single_line(buffer, text, x, y) do
    # Check if we need to insert characters to make room
    buffer = ensure_space_for_text(buffer, x, y, String.length(text))

    # Write the text at the cursor position
    Writer.write_string(buffer, x, y, text)
  end

  @doc """
  Pastes multi-line text starting at the specified position.
  """
  @spec paste_multiline(
          ScreenBuffer.t(),
          String.t(),
          [String.t()],
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def paste_multiline(buffer, first_line, remaining_lines, x, y) do
    # Check if we need to insert lines to make room
    lines_needed = length(remaining_lines)
    buffer = ensure_space_for_lines(buffer, y, lines_needed)

    # Write the first line at the cursor position
    buffer = paste_single_line(buffer, first_line, x, y)

    # Write remaining lines
    Enum.reduce_while(remaining_lines, {buffer, y + 1}, fn line,
                                                           {acc_buffer,
                                                            current_y} ->
      if current_y < acc_buffer.height do
        # Write the line starting from column 0
        updated_buffer = Writer.write_string(acc_buffer, 0, current_y, line)
        {:cont, {updated_buffer, current_y + 1}}
      else
        # Buffer is full, stop
        {:halt, {acc_buffer, current_y}}
      end
    end)
    |> elem(0)
  end

  @doc """
  Ensures there's enough space in the current line for the text to be pasted.
  If not, inserts the necessary number of characters.
  """
  @spec ensure_space_for_text(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def ensure_space_for_text(buffer, x, y, text_length) do
    available_space = buffer.width - x

    if text_length > available_space do
      # Need to insert characters to make room
      chars_to_insert = text_length - available_space
      LineOperations.insert_chars_at(buffer, y, x, chars_to_insert)
    else
      buffer
    end
  end

  @doc """
  Ensures there are enough lines available for multi-line paste.
  If not, inserts the necessary number of lines.
  """
  @spec ensure_space_for_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def ensure_space_for_lines(buffer, y, lines_needed) do
    available_lines = buffer.height - y - 1

    if lines_needed > available_lines do
      # Need to insert lines to make room
      lines_to_insert = lines_needed - available_lines

      LineOperations.insert_lines(
        buffer,
        lines_to_insert,
        y,
        0,
        buffer.height - 1,
        buffer.height - 1
      )
    else
      buffer
    end
  end
end
