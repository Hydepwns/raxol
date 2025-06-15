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
      buffer = CharEditor.write_char(buffer, 2, 1, "X")
      assert get_char(buffer, 2, 1) == "X"
    end

    test "ignores invalid position", %{buffer: buffer} do
      original = buffer
      buffer = CharEditor.write_char(original, 10, 1, "X")
      assert buffer == original

      buffer = CharEditor.write_char(original, 2, 5, "X")
      assert buffer == original

      buffer = CharEditor.write_char(original, -1, 1, "X")
      assert buffer == original

      buffer = CharEditor.write_char(original, 2, -1, "X")
      assert buffer == original
    end
  end

  describe "write_string/4" do
    test "writes string at valid position", %{buffer: buffer} do
      buffer = CharEditor.write_string(buffer, 2, 1, "Hello")
      assert get_line_text(buffer, 1) == "  Hello   "
    end

    test "truncates string at buffer edge", %{buffer: buffer} do
      buffer = CharEditor.write_string(buffer, 7, 1, "Hello")
      assert get_line_text(buffer, 1) == "      Hel"
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
      buffer = CharEditor.insert_chars(buffer, 2, 1, 2)
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
      buffer = CharEditor.delete_chars(buffer, 2, 1, 2)
      assert get_line_text(buffer, 1) == "FG  HIJ"
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
      buffer = CharEditor.erase_chars(buffer, 2, 1, 2)
      assert get_line_text(buffer, 1) == "FG  HIJ"
    end

    test "erases characters with style", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      style = TextFormatting.new(foreground: :red)
      buffer = CharEditor.erase_chars(buffer, 2, 1, 2, style)
      assert get_line_text(buffer, 1) == "FG  HIJ"

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
      buffer = CharEditor.replace_chars(buffer, 2, 1, "XX")
      assert get_line_text(buffer, 1) == "FGXXIJ"
    end

    test "replaces characters with style", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      style = TextFormatting.new(foreground: :red)
      buffer = CharEditor.replace_chars(buffer, 2, 1, "XX", style)
      assert get_line_text(buffer, 1) == "FGXXIJ"

      # Note: We can't easily test the style here without exposing internal cell details
    end

    test "truncates string at buffer edge", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.replace_chars(buffer, 8, 1, "XXX")
      assert get_line_text(buffer, 1) == "FGHIJKLXX"
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
      line
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.reduce(buffer, fn {char, x}, buffer ->
        CharEditor.write_char(buffer, x, y, char)
      end)
    end)
  end

  defp get_char(buffer, x, y) do
    case get_in(buffer.cells, [y, x]) do
      nil -> nil
      cell -> Raxol.Terminal.Cell.get_char(cell)
    end
  end

  defp get_line_text(buffer, y) do
    buffer.cells
    |> Enum.at(y)
    |> Enum.map(&Raxol.Terminal.Cell.get_char/1)
    |> Enum.join()
  end
end
