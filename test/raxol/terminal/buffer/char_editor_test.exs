defmodule Raxol.Terminal.Buffer.CharEditorTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.CharEditor
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Cell

  setup do
    buffer = ScreenBuffer.new(10, 5)
    %{buffer: buffer}
  end

  describe "write_char/4" do
    test "writes character at valid position", %{buffer: buffer} do
      buffer = CharEditor.write_char(buffer, 1, 2, "X")
      assert get_char(buffer, 2, 1) == "X"
    end

    test "ignores invalid position", %{buffer: buffer} do
      original = buffer
      buffer = CharEditor.write_char(original, 1, 10, "X")
      assert buffer == original

      buffer = CharEditor.write_char(original, 5, 2, "X")
      assert buffer == original

      buffer = CharEditor.write_char(original, -1, 1, "X")
      assert buffer == original

      buffer = CharEditor.write_char(original, 2, -1, "X")
      assert buffer == original
    end
  end

  describe "write_string/4" do
    test "writes string at valid position", %{buffer: buffer} do
      buffer = CharEditor.write_string(buffer, 1, 2, "Hello")
      assert get_line_text_with_spaces(buffer, 1) == "  Hello   "
    end

    test "truncates string at buffer edge", %{buffer: buffer} do
      buffer = CharEditor.write_string(buffer, 1, 7, "Hello")
      assert get_line_text(buffer, 1) == "       Hel"
    end

    test "ignores invalid position", %{buffer: buffer} do
      original = buffer
      buffer = CharEditor.write_string(original, 10, 1, "Hello")
      assert buffer == original

      buffer = CharEditor.write_string(original, 2, 5, "Hello")
      assert buffer == original

      buffer = CharEditor.write_string(original, -1, 1, "Hello")
      assert buffer == original

      buffer = CharEditor.write_string(original, 2, -1, "Hello")
      assert buffer == original
    end
  end

  describe "insert_chars/4" do
    test "inserts characters at valid position", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.insert_chars(buffer, 1, 2, 2)
      assert get_line_text_with_spaces(buffer, 1) == "FG  HIJ   "
    end

    test "ignores invalid position", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.insert_chars(original, 10, 1, 2)
      assert buffer == original

      buffer = CharEditor.insert_chars(original, 2, 5, 2)
      assert buffer == original

      buffer = CharEditor.insert_chars(original, -1, 1, 2)
      assert buffer == original

      buffer = CharEditor.insert_chars(original, 2, -1, 2)
      assert buffer == original
    end

    test "ignores invalid count", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.insert_chars(original, 2, 1, 0)
      assert buffer == original
    end
  end

  describe "delete_chars/4" do
    test "deletes characters at valid position", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.delete_chars(buffer, 1, 2, 2)
      assert get_line_text_with_spaces(buffer, 1) == "FGJ       "
    end

    test "ignores invalid position", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.delete_chars(original, 10, 1, 2)
      assert buffer == original

      buffer = CharEditor.delete_chars(original, 2, 5, 2)
      assert buffer == original

      buffer = CharEditor.delete_chars(original, -1, 1, 2)
      assert buffer == original

      buffer = CharEditor.delete_chars(original, 2, -1, 2)
      assert buffer == original
    end

    test "ignores invalid count", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.delete_chars(original, 2, 1, 0)
      assert buffer == original
    end
  end

  describe "erase_chars/5" do
    test "erases characters at valid position", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.erase_chars(buffer, 1, 2, 2)
      assert get_line_text_with_spaces(buffer, 1) == "FGJ       "
    end

    test "erases characters with style", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      style = TextFormatting.new(foreground: :red)
      buffer = CharEditor.erase_chars(buffer, 1, 2, 2, style)
      assert get_line_text_with_spaces(buffer, 1) == "FGJ       "

      # Note: We can't easily test the style here without exposing internal cell details
    end

    test "ignores invalid position", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.erase_chars(original, 10, 1, 2)
      assert buffer == original

      buffer = CharEditor.erase_chars(original, 2, 5, 2)
      assert buffer == original

      buffer = CharEditor.erase_chars(original, -1, 1, 2)
      assert buffer == original

      buffer = CharEditor.erase_chars(original, 2, -1, 2)
      assert buffer == original
    end

    test "ignores invalid count", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.erase_chars(original, 2, 1, 0)
      assert buffer == original
    end
  end

  describe "replace_chars/5" do
    test "replaces characters at valid position", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")

      # Debug: print the original line
      original_line = get_line_text(buffer, 1)
      IO.puts("Original line: '#{original_line}' (length: #{String.length(original_line)})")

      # Debug: print the line cells
      line = Enum.at(buffer.cells, 1)
      IO.puts("Line cells: #{inspect(line)}")

      # Debug: print content length
      content_len = Raxol.Terminal.Buffer.CharEditor.content_length(line)
      IO.puts("Content length: #{content_len}")

      buffer = CharEditor.replace_chars(buffer, 1, 2, "XX")

      # Debug: print the result line
      result_line = get_line_text_with_spaces(buffer, 1)
      IO.puts("Result line: '#{result_line}' (length: #{String.length(result_line)})")

      # Debug: print the result line cells
      result_line_cells = Enum.at(buffer.cells, 1)
      IO.puts("Result line cells: #{inspect(result_line_cells)}")

      assert get_line_text_with_spaces(buffer, 1) == "FGXXJ     "
    end

    test "replaces characters with style", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      style = TextFormatting.new(foreground: :red)
      buffer = CharEditor.replace_chars(buffer, 1, 2, "XX", style)
      assert get_line_text_with_spaces(buffer, 1) == "FGXXJ     "

      # Note: We can't easily test the style here without exposing internal cell details
    end

    test "truncates string at buffer edge", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")

      # Debug: print the original line
      original_line = get_line_text_with_spaces(buffer, 1)
      IO.puts("Original line: '#{original_line}' (length: #{String.length(original_line)})")

      # Debug: print the line cells
      line = Enum.at(buffer.cells, 1)
      IO.puts("Line cells: #{inspect(line)}")

      buffer = CharEditor.replace_chars(buffer, 1, 8, "XXX")

      # Debug: print the result line
      result_line = get_line_text_with_spaces(buffer, 1)
      IO.puts("Result line: '#{result_line}' (length: #{String.length(result_line)})")

      assert get_line_text_with_spaces(buffer, 1) == "FGHIJ   XX"
    end

    test "ignores invalid position", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.replace_chars(original, 10, 1, "XX")
      assert buffer == original

      buffer = CharEditor.replace_chars(original, 2, 5, "XX")
      assert buffer == original

      buffer = CharEditor.replace_chars(original, -1, 1, "XX")
      assert buffer == original

      buffer = CharEditor.replace_chars(original, 2, -1, "XX")
      assert buffer == original
    end
  end

  describe "debug delete_from_line" do
    test "debug delete_from_line behavior", %{buffer: buffer} do
      # Create a simple line with "FGHIJ     "
      line = [
        Cell.new("F"), Cell.new("G"), Cell.new("H"), Cell.new("I"), Cell.new("J"),
        Cell.new(" "), Cell.new(" "), Cell.new(" "), Cell.new(" "), Cell.new(" ")
      ]

      # Debug: print the original line
      original_text = Enum.map_join(line, "", &extract_char/1)
      IO.puts("Original line: '#{original_text}' (length: #{length(line)})")

      # Test delete_from_line directly
      result = CharEditor.delete_from_line(line, 2, 2, buffer.default_style)

      # Debug: print the result
      result_text = Enum.map_join(result, "", &extract_char/1)
      IO.puts("Result line: '#{result_text}' (length: #{length(result)})")

      assert result_text == "FGJ       "
    end
  end

  describe "debug put_content" do
    test "debug put_content behavior", %{buffer: buffer} do
      # Test with a simple single line
      buffer = put_content(buffer, "ABC")

      # Debug: print the buffer cells
      IO.puts("Buffer cells: #{inspect(buffer.cells)}")

      # Debug: print line 0
      line_0 = get_line_text_with_spaces(buffer, 0)
      IO.puts("Line 0: '#{line_0}' (length: #{String.length(line_0)})")

      # Debug: print line 1
      line_1 = get_line_text_with_spaces(buffer, 1)
      IO.puts("Line 1: '#{line_1}' (length: #{String.length(line_1)})")

      assert line_0 == "ABC       "
    end
  end

  describe "debug slice" do
    test "debug slice behavior", %{buffer: buffer} do
      # Create a simple line with "FGHIJ     "
      line = [
        Cell.new("F"), Cell.new("G"), Cell.new("H"), Cell.new("I"), Cell.new("J"),
        Cell.new(" "), Cell.new(" "), Cell.new(" "), Cell.new(" "), Cell.new(" ")
      ]

      # Debug: print the original line
      original_text = Enum.map_join(line, "", &extract_char/1)
      IO.puts("Original line: '#{original_text}' (length: #{length(line)})")

      # Test the slice logic from delete_from_line
      line_length = length(line)
      col = 2
      count = 2

      {left_part, right_part} = Enum.split(line, col)
      IO.puts("Left part: '#{Enum.map_join(left_part, "", &extract_char/1)}' (length: #{length(left_part)})")
      IO.puts("Right part: '#{Enum.map_join(right_part, "", &extract_char/1)}' (length: #{length(right_part)})")

      remaining_right = Enum.slice(right_part, count, line_length - col - count)
      IO.puts("Remaining right: '#{Enum.map_join(remaining_right, "", &extract_char/1)}' (length: #{length(remaining_right)})")

      blanks_needed = line_length - length(left_part) - length(remaining_right)
      IO.puts("Blanks needed: #{blanks_needed}")

      blank_cell = Cell.new(" ", buffer.default_style)
      blank_cells = List.duplicate(blank_cell, blanks_needed)

      result = left_part ++ remaining_right ++ blank_cells
      result_text = Enum.map_join(result, "", &extract_char/1)
      IO.puts("Result: '#{result_text}' (length: #{length(result)})")

      assert result_text == "FGJ       "
    end
  end

  # Helper functions

  defp get_char(buffer, x, y) do
    buffer.cells
    |> Enum.at(y)
    |> Enum.at(x)
    |> Cell.get_char()
  end

  defp get_line_text(buffer, y) do
    buffer.cells
    |> Enum.at(y)
    |> Enum.map_join("", &extract_char/1)
  end

  defp get_line_text_with_spaces(buffer, y) do
    buffer.cells
    |> Enum.at(y)
    |> Enum.map_join("", &extract_char/1)
  end

  defp extract_char(cell) do
    Cell.get_char(cell)
  end

  defp put_content(buffer, text) do
    IO.puts("put_content called with text: '#{text}'")
    IO.puts("Buffer dimensions: #{buffer.width}x#{buffer.height}")

    result = text
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {line, y}, buffer ->
      IO.puts("Processing line #{y}: '#{line}'")
      chars = String.graphemes(line)
      width = buffer.width

      # Create a new line with the characters, limited to buffer width
      new_line = chars
      |> Enum.take(width)
      |> Enum.map(&Cell.new/1)

      # Pad the rest of the line with spaces to fill the full width
      padding_needed = width - length(new_line)
      new_line =
        if padding_needed > 0 do
          new_line ++ List.duplicate(Cell.new(" "), padding_needed)
        else
          new_line
        end

      IO.puts("New line #{y} (length: #{length(new_line)}): #{inspect(new_line)}")

      # Replace the line in the buffer
      cells = List.replace_at(buffer.cells, y, new_line)
      %{buffer | cells: cells}
    end)

    IO.puts("Final buffer cells: #{inspect(result.cells)}")
    result
  end
end
