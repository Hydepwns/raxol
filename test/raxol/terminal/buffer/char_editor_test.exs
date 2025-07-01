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

    test "write_string/4 ignores invalid position", %{buffer: buffer} do
      original = buffer
      buffer = CharEditor.write_string(original, 10, 1, "Hello")
      assert_buffer_equal(buffer, original)

      original = buffer
      buffer = CharEditor.write_string(original, 2, 5, "Hello")
      assert_buffer_equal(buffer, original)

      original = buffer
      buffer = CharEditor.write_string(original, -1, 1, "Hello")
      assert_buffer_equal(buffer, original)

      original = buffer
      buffer = CharEditor.write_string(original, 2, -1, "Hello")
      assert_buffer_equal(buffer, original)
    end
  end

  describe "insert_chars/4" do
    test "inserts characters at valid position", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.insert_chars(buffer, 1, 2, 2)
      assert get_line_text_with_spaces(buffer, 1) == "FG  HIJ   "
    end

    test "insert_chars/4 ignores invalid position", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.insert_chars(original, 10, 1, 2)
      assert_buffer_equal(buffer, original)

      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.insert_chars(original, 2, 5, 2)
      assert_buffer_equal(buffer, original)

      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.insert_chars(original, -1, 1, 2)
      assert_buffer_equal(buffer, original)

      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.insert_chars(original, 2, -1, 2)
      assert_buffer_equal(buffer, original)
    end

    test "ignores invalid count", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.insert_chars(original, 2, 1, 0)
      assert_buffer_equal(buffer, original)
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
      assert_buffer_equal(buffer, original)

      # Use fresh copy for each test
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.delete_chars(original, 2, 5, 2)
      assert_buffer_equal(buffer, original)

      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.delete_chars(original, -1, 1, 2)
      assert_buffer_equal(buffer, original)

      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.delete_chars(original, 2, -1, 2)
      assert_buffer_equal(buffer, original)
    end

    test "ignores invalid count", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.delete_chars(original, 2, 1, 0)
      assert_buffer_equal(buffer, original)
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
      assert_buffer_equal(buffer, original)

      # Use fresh copy for each test
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.erase_chars(original, 2, 5, 2)
      assert_buffer_equal(buffer, original)

      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.erase_chars(original, -1, 1, 2)
      assert_buffer_equal(buffer, original)

      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.erase_chars(original, 2, -1, 2)
      assert_buffer_equal(buffer, original)
    end

    test "ignores invalid count", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = CharEditor.erase_chars(original, 2, 1, 0)
      assert_buffer_equal(buffer, original)
    end
  end

  describe "replace_chars/5" do
    test "replaces characters at valid position", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")

      # Debug: print the original line
      original_line = get_line_text(buffer, 1)

      IO.puts(
        "Original line: '#{original_line}' (length: #{String.length(original_line)})"
      )

      # Debug: print the line cells
      line = Enum.at(buffer.cells, 1)
      IO.puts("Line cells: #{inspect(line)}")

      # Debug: print content length
      content_len = Raxol.Terminal.Buffer.CharEditor.content_length(line)
      IO.puts("Content length: #{content_len}")

      buffer = CharEditor.replace_chars(buffer, 1, 2, "XX")

      # Debug: print the result line
      result_line = get_line_text_with_spaces(buffer, 1)

      IO.puts(
        "Result line: '#{result_line}' (length: #{String.length(result_line)})"
      )

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

      IO.puts(
        "Original line: '#{original_line}' (length: #{String.length(original_line)})"
      )

      # Debug: print the line cells
      line = Enum.at(buffer.cells, 1)
      IO.puts("Line cells: #{inspect(line)}")

      buffer = CharEditor.replace_chars(buffer, 1, 8, "XXX")

      # Debug: print the result line
      result_line = get_line_text_with_spaces(buffer, 1)

      IO.puts(
        "Result line: '#{result_line}' (length: #{String.length(result_line)})"
      )

      assert get_line_text_with_spaces(buffer, 1) == "FGHIJ   XX"
    end

    test "replace_chars/5 ignores invalid position", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      result = CharEditor.replace_chars(original, 10, 1, "XX")
      assert_buffer_equal(result, original)

      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      result = CharEditor.replace_chars(original, 2, 5, "XX")
      assert_buffer_equal(result, original)

      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      result = CharEditor.replace_chars(original, -1, 1, "XX")
      assert_buffer_equal(result, original)

      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      result = CharEditor.replace_chars(original, 2, -1, "XX")
      assert_buffer_equal(result, original)
    end
  end

  describe "debug delete_from_line" do
    test "debug delete_from_line behavior", %{buffer: buffer} do
      # Create a simple line with "FGHIJ     "
      line = [
        Cell.new("F"),
        Cell.new("G"),
        Cell.new("H"),
        Cell.new("I"),
        Cell.new("J"),
        Cell.new(" "),
        Cell.new(" "),
        Cell.new(" "),
        Cell.new(" "),
        Cell.new(" ")
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
        Cell.new("F"),
        Cell.new("G"),
        Cell.new("H"),
        Cell.new("I"),
        Cell.new("J"),
        Cell.new(" "),
        Cell.new(" "),
        Cell.new(" "),
        Cell.new(" "),
        Cell.new(" ")
      ]

      # Debug: print the original line
      original_text = Enum.map_join(line, "", &extract_char/1)
      IO.puts("Original line: '#{original_text}' (length: #{length(line)})")

      # Test the slice logic from delete_from_line
      line_length = length(line)
      col = 2
      count = 2

      {left_part, right_part} = Enum.split(line, col)

      IO.puts(
        "Left part: '#{Enum.map_join(left_part, "", &extract_char/1)}' (length: #{length(left_part)})"
      )

      IO.puts(
        "Right part: '#{Enum.map_join(right_part, "", &extract_char/1)}' (length: #{length(right_part)})"
      )

      remaining_right = Enum.slice(right_part, count, line_length - col - count)

      IO.puts(
        "Remaining right: '#{Enum.map_join(remaining_right, "", &extract_char/1)}' (length: #{length(remaining_right)})"
      )

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

    result = process_text_lines(buffer, text)
    result = normalize_cell_dirty_flags(result)

    IO.puts("Final buffer cells: #{inspect(result.cells)}")
    result
  end

  defp process_text_lines(buffer, text) do
    text
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {line, y}, buffer ->
      process_single_line(buffer, line, y)
    end)
  end

  defp process_single_line(buffer, line, y) do
    IO.puts("Processing line #{y}: '#{line}'")
    new_line = create_line_with_padding(line, buffer.width, buffer.default_style)

    IO.puts("New line #{y} (length: #{length(new_line)}): #{inspect(new_line)}")

    cells = List.replace_at(buffer.cells, y, new_line)
    %{buffer | cells: cells}
  end

  defp create_line_with_padding(line, width, default_style) do
    chars = String.graphemes(line)

    new_line =
      chars
      |> Enum.take(width)
      |> Enum.map(&Cell.new/1)

    padding_needed = width - length(new_line)

    if padding_needed > 0 do
      new_line ++ create_padding_cells(padding_needed, default_style)
    else
      new_line
    end
  end

  defp normalize_cell_dirty_flags(buffer) do
    %{
      buffer
      | cells:
          Enum.map(buffer.cells, fn line ->
            Enum.map(line, fn cell -> %{cell | dirty: false} end)
          end)
    }
  end

  defp create_padding_cells(count, default_style) do
    Enum.map(1..count, fn _ ->
      %Cell{
        char: " ",
        style: default_style,
        dirty: false,
        wide_placeholder: false
      }
    end)
  end

  # Custom deep equality assertion for buffer structs
  defp assert_buffer_equal(buffer1, buffer2) do
    assert_buffer_metadata_equal(buffer1, buffer2)
    assert_buffer_cells_equal(buffer1, buffer2)
  end

  defp assert_buffer_metadata_equal(buffer1, buffer2) do
    assert buffer1.width == buffer2.width
    assert buffer1.height == buffer2.height
    assert buffer1.scrollback_limit == buffer2.scrollback_limit
    assert buffer1.cursor_position == buffer2.cursor_position
    assert buffer1.alternate_screen == buffer2.alternate_screen
    assert buffer1.cursor_visible == buffer2.cursor_visible
    assert buffer1.scroll_position == buffer2.scroll_position
    assert buffer1.scroll_region == buffer2.scroll_region
    assert buffer1.selection == buffer2.selection
    assert buffer1.damage_regions == buffer2.damage_regions
    assert_style_equal(buffer1.default_style, buffer2.default_style)
  end

  defp assert_buffer_cells_equal(buffer1, buffer2) do
    assert length(buffer1.cells) == length(buffer2.cells)

    Enum.zip(buffer1.cells, buffer2.cells)
    |> Enum.with_index()
    |> Enum.each(fn {{row1, row2}, row_index} ->
      assert_buffer_row_equal(row1, row2, row_index)
    end)
  end

  defp assert_buffer_row_equal(row1, row2, row_index) do
    assert length(row1) == length(row2)

    Enum.zip(row1, row2)
    |> Enum.with_index()
    |> Enum.each(fn {{cell1, cell2}, col_index} ->
      assert_cell_equal(cell1, cell2, row_index, col_index)
    end)
  end

  defp assert_style_equal(style1, style2) do
    assert style1.bold == style2.bold
    assert style1.italic == style2.italic
    assert style1.underline == style2.underline
    assert style1.blink == style2.blink
    assert style1.reverse == style2.reverse
    assert style1.foreground == style2.foreground
    assert style1.background == style2.background
    assert style1.double_width == style2.double_width
    assert style1.double_height == style2.double_height
    assert style1.faint == style2.faint
    assert style1.conceal == style2.conceal
    assert style1.strikethrough == style2.strikethrough
    assert style1.fraktur == style2.fraktur
    assert style1.double_underline == style2.double_underline
    assert style1.framed == style2.framed
    assert style1.encircled == style2.encircled
    assert style1.overlined == style2.overlined
    assert style1.hyperlink == style2.hyperlink
  end

  defp assert_cell_equal(cell1, cell2, row_index, col_index) do
    if cell1.char != cell2.char or cell1.dirty != cell2.dirty or cell1.wide_placeholder != cell2.wide_placeholder do
      flunk("""
      Cell mismatch at position (#{row_index}, #{col_index}):
      Expected: char="#{cell1.char}", dirty=#{cell1.dirty}, wide_placeholder=#{cell1.wide_placeholder}
      Got:      char="#{cell2.char}", dirty=#{cell2.dirty}, wide_placeholder=#{cell2.wide_placeholder}
      """)
    end

    assert_style_equal(cell1.style, cell2.style)
  end
end
