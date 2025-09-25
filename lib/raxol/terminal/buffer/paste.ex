defmodule Raxol.Terminal.Buffer.Paste do
  @moduledoc """
  Handles text pasting operations for terminal buffers.
  """

  alias Raxol.Terminal.ScreenBuffer

  @doc """
  Pastes text into the buffer at the current cursor position.
  """
  @spec paste(ScreenBuffer.t(), String.t()) :: ScreenBuffer.t()
  def paste(buffer, text) when is_binary(text) do
    # Split text into lines for multi-line pasting
    lines = String.split(text, ~r/\r?\n/)

    case lines do
      [] -> buffer
      [single_line] -> paste_single_line(buffer, single_line)
      multiple_lines -> paste_multiple_lines(buffer, multiple_lines)
    end
  end

  def paste(buffer, _), do: buffer

  # Private helper functions

  defp paste_single_line(buffer, line) do
    # Insert text at cursor position character by character
    String.graphemes(line)
    |> Enum.reduce(buffer, fn char, acc ->
      {x, y} = acc.cursor_position
      ScreenBuffer.write_char(acc, x, y, char)
    end)
  end

  defp paste_multiple_lines(buffer, lines) do
    # Paste first line at cursor, then create new lines for remaining text
    case lines do
      [first_line | rest] ->
        # Paste first line at current position
        buffer_after_first = paste_single_line(buffer, first_line)

        # Add remaining lines as new lines
        Enum.reduce(rest, buffer_after_first, fn line, acc ->
          {x, y} = acc.cursor_position

          acc
          # Move to new line
          |> ScreenBuffer.write_char(x, y, "\n")
          |> paste_single_line(line)
        end)

      [] ->
        buffer
    end
  end
end
