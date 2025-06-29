defmodule Raxol.Terminal.Buffer.CharEditorTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.CharEditor
  alias Raxol.Terminal.ANSI.TextFormatting

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
      assert get_line_text(buffer, 1) == "FG  HIJ"
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

      # Debug: print buffer width
      IO.puts("Buffer width: #{buffer.width}")

      # Debug: print original line length
      original_line = get_line_text_with_spaces(buffer, 1)
      IO.puts("Original line: '#{original_line}' (length: #{String.length(original_line)})")

      # Debug: print original line cells
      original_cells = Enum.at(buffer.cells, 1)
      IO.puts("Original line cells count: #{length(original_cells)}")

      buffer = CharEditor.delete_chars(buffer, 1, 2, 2)

      # Debug: print result line length
      result_line = get_line_text_with_spaces(buffer, 1)
      IO.puts("Result line: '#{result_line}' (length: #{String.length(result_line)})")

      # Debug: print result line cells
      result_cells = Enum.at(buffer.cells, 1)
      IO.puts("Result line cells count: #{length(result_cells)}")

      assert get_line_text_with_spaces(buffer, 1) == "FGJ       "
    end

    test "debug test to understand behavior", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")

      # Debug: print the original line
      original_line = get_line_text(buffer, 1)
      IO.puts("Original line: '#{original_line}' (length: #{String.length(original_line)})")

      # Debug: print the buffer width
      IO.puts("Buffer width: #{buffer.width}")

      # Debug: print the line length
      line = Enum.at(buffer.cells, 1)
      IO.puts("Line cell count: #{length(line)}")

      # Debug: print content length
      content_len = Raxol.Terminal.Buffer.CharEditor.content_length(line)
      IO.puts("Content length: #{content_len}")

      buffer = CharEditor.delete_chars(buffer, 1, 2, 2)
      result_line = get_line_text_with_spaces(buffer, 1)
      IO.puts("Result line: '#{result_line}' (length: #{String.length(result_line)})")

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

  # Helper functions

  defp put_content(buffer, text) do
    text
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {line, y}, buffer ->
      chars = String.graphemes(line)
      width = buffer.width
      # Write each character
      buffer = Enum.with_index(chars)
      |> Enum.reduce(buffer, fn {char, x}, buffer ->
        CharEditor.write_char(buffer, y, x, char)
      end)
      # Pad the rest of the line with spaces
      pad_start = length(chars)
      if pad_start < width do
        Enum.reduce(pad_start..(width - 1), buffer, fn x, buffer ->
          CharEditor.write_char(buffer, y, x, " ")
        end)
      else
        buffer
      end
    end)
  end

  defp get_char(buffer, x, y) do
    case Enum.at(buffer.cells, y) do
      nil -> nil
      line ->
        case Enum.at(line, x) do
          nil -> nil
          cell -> extract_char(cell)
        end
    end
  end

  defp get_line_text(buffer, y) do
    buffer.cells
    |> Enum.at(y)
    |> Enum.map_join("", &extract_char/1)
    |> String.trim_trailing()
  end

  defp get_line_text_with_spaces(buffer, y) do
    buffer.cells
    |> Enum.at(y)
    |> Enum.map_join("", &extract_char/1)
  end

  # Helper to extract char from only Raxol.Terminal.Cell
  defp extract_char(%Raxol.Terminal.Cell{char: char}), do: char
  defp extract_char(_), do: " "
end
