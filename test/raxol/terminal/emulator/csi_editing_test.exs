defmodule Raxol.Terminal.Emulator.CsiEditingTest do
  use ExUnit.Case

  # Import helpers
  import Raxol.Test.EmulatorHelpers

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager
  # Needed for style check
  alias Raxol.Terminal.Cell

  describe "CSI editing functions" do
    # Tests focus on buffer manipulation via CSI sequences processed by Emulator

    test 'ICH - Insert Character inserts spaces and shifts content' do
      # 10 wide, 1 high
      emulator = Emulator.new(10, 1)
      {emulator, _} = Emulator.process_input(emulator, "abcdef")
      # CUP to column 2 (index 1)
      {emulator, _} = Emulator.process_input(emulator, "\e[2G")
      assert emulator.cursor.position == {1, 0}

      # Insert 3 characters (CSI 3 @)
      {emulator, _} = Emulator.process_input(emulator, "\e[3@")

      buffer = Emulator.get_active_buffer(emulator)
      expected_content = ["a", " ", " ", " ", "b", "c", "d", "e", "f", " "]

      Enum.each(0..9, fn x ->
        cell = ScreenBuffer.get_cell_at(buffer, x, 0)
        assert cell.char == Enum.at(expected_content, x)
        # Verify inserted spaces have default style
        if x in 1..3 do
          assert cell.style == Raxol.Terminal.ANSI.TextFormatting.new()
        end
      end)
    end

    test 'DCH - Delete Character removes characters and shifts content left' do
      # 10 wide, 1 high
      emulator = Emulator.new(10, 1)
      {emulator, _} = Emulator.process_input(emulator, "abcdefghij")
      # CUP to column 3 (index 2)
      {emulator, _} = Emulator.process_input(emulator, "\e[3G")
      assert emulator.cursor.position == {2, 0}

      # Delete 2 characters (CSI 2 P)
      {emulator, _} = Emulator.process_input(emulator, "\e[2P")

      buffer = Emulator.get_active_buffer(emulator)
      expected_content = ["a", "b", "e", "f", "g", "h", "i", "j", " ", " "]

      Enum.each(0..9, fn x ->
        cell = ScreenBuffer.get_cell_at(buffer, x, 0)

        assert cell.char == Enum.at(expected_content, x),
               "Mismatch at index #{x}: Expected #{Enum.at(expected_content, x)}, got #{cell.char}"

        # Verify trailing blanks have default style
        if x >= 8 do
          # Use TextFormatting.new() for comparison
          assert cell.style == Raxol.Terminal.ANSI.TextFormatting.new()
        end
      end)
    end

    test 'IL - Insert Line inserts blank lines within scroll region' do
      # 5 wide, 5 high
      emulator = Emulator.new(5, 5)
      # Use local helper
      emulator = fill_buffer(emulator, 0, 5)

      # Set scroll region rows 2-4 (indices 1-3)
      {emulator, _} = Emulator.process_input(emulator, "\e[2;4r")
      assert emulator.scroll_region == {1, 3}

      # Move cursor to row 3 (index 2, inside region)
      {emulator, _} = Emulator.process_input(emulator, "\e[3;1H")
      assert emulator.cursor.position == {0, 2}

      # Insert 2 lines (CSI 2 L)
      {emulator, _} = Emulator.process_input(emulator, "\e[2L")

      buffer = Emulator.get_active_buffer(emulator)

      # Revised expected lines based on IL inserting AT cursor within region AND 5-char width truncation
      expected_lines = ["Line ", "Line ", "     ", "     ", "Line "]

      Enum.each(0..4, fn y ->
        line_cells = ScreenBuffer.get_line(buffer, y)
        line_text = Enum.map_join(line_cells, &(&1.char || " "))
        expected_line_trimmed = String.trim(Enum.at(expected_lines, y))
        actual_line_trimmed = String.trim(line_text)

        assert actual_line_trimmed == expected_line_trimmed,
               "Mismatch at line #{y}: Expected "#{expected_line_trimmed}", got "#{actual_line_trimmed}""
      end)

      # Clean up scroll region
      {_emulator, _} = Emulator.process_input(emulator, "\e[r")
    end

    test 'DL - Delete Line deletes current line and shifts lines up' do
      # Revert to using process_input for setup
      emulator = Emulator.new(80, 5)
      # Write to line 0
      {emulator, _} = Emulator.process_input(emulator, "\e[1;1HLine 0")
      # Write to line 1
      {emulator, _} = Emulator.process_input(emulator, "\e[2;1HLine 1")
      # Write to line 2
      {emulator, _} = Emulator.process_input(emulator, "\e[3;1HLine 2")
      # Write to line 3
      {emulator, _} = Emulator.process_input(emulator, "\e[4;1HLine 3")
      # Move cursor to line 1 (index 1) for the DL operation
      {emulator, _} = Emulator.process_input(emulator, "\e[2;1H")
      assert emulator.cursor.position == {0, 1}

      # Assertions before DL
      line1_before = get_line_text(emulator, 1)
      line2_before = get_line_text(emulator, 2)
      line3_before = get_line_text(emulator, 3)
      assert String.starts_with?(line1_before, "Line 1")
      assert String.starts_with?(line2_before, "Line 2")

      # Process CSI M (Delete Line)
      {emulator, _} = Emulator.process_input(emulator, "\e[M")

      # Get text after DL
      line1_after = get_line_text(emulator, 1)
      line2_after = get_line_text(emulator, 2)
      line4_after = get_line_text(emulator, 4)

      # Line 1 should now contain text from old Line 2
      assert String.starts_with?(line1_after, "Line 2")
      # Line 2 should now contain text from old Line 3
      assert String.starts_with?(line2_after, "Line 3")
      # Line 4 (last line) should be blank
      assert String.trim(line4_after) == ""
    end

    test 'DL respects count parameter n' do
      emulator = Emulator.new(80, 5)
      # Use fill_buffer helper
      emulator = fill_buffer(emulator, 0, 5)
      # Use process_input with CUP instead of direct update
      # Move cursor to line 1 (index 1)
      {emulator, _} = Emulator.process_input(emulator, "\e[2;1H")

      line3_before = get_line_text(emulator, 3)
      line4_before = get_line_text(emulator, 4)
      assert String.starts_with?(get_line_text(emulator, 1), "Line 1")
      assert String.starts_with?(get_line_text(emulator, 2), "Line 2")
      assert String.starts_with?(line3_before, "Line 3")

      # Process CSI 2 M (Delete 2 lines)
      {emulator, _} = Emulator.process_input(emulator, "\e[2M")

      # Line 1 should now contain text from old Line 3
      assert String.starts_with?(get_line_text(emulator, 1), "Line 3")
      # Line 2 should now contain text from old Line 4
      assert String.starts_with?(get_line_text(emulator, 2), "Line 4")
      # Lines 3 and 4 should be blank
      assert String.trim(get_line_text(emulator, 3)) == ""
      assert String.trim(get_line_text(emulator, 4)) == ""
    end

    test 'DL respects scroll region' do
      emulator = Emulator.new(80, 6)
      emulator = fill_buffer(emulator, 0, 6)
      # Set scroll region line 2 to 4 (index 1 to 3)
      {emulator, _} = Emulator.process_input(emulator, "\e[2;4r")
      # Use process_input with CUP instead of direct update
      # Move cursor to line 2 (index 1)
      {emulator, _} = Emulator.process_input(emulator, "\e[2;1H")

      line0_before = get_line_text(emulator, 0)
      line2_before = get_line_text(emulator, 2)
      line3_before = get_line_text(emulator, 3)
      line4_before = get_line_text(emulator, 4)
      line5_before = get_line_text(emulator, 5)
      assert String.starts_with?(get_line_text(emulator, 1), "Line 1")
      assert String.starts_with?(line2_before, "Line 2")

      # Process CSI M (Delete line)
      {emulator, _} = Emulator.process_input(emulator, "\e[M")

      # Line 0 unchanged (outside region)
      assert get_line_text(emulator, 0) == line0_before
      # Line 1 (top of region) contains old line 2
      assert get_line_text(emulator, 1) == line2_before
      # Line 2 contains old line 3
      assert get_line_text(emulator, 2) == line3_before
      # Line 3 (bottom of region) is blank
      assert String.trim(get_line_text(emulator, 3)) == ""
      # Line 4 unchanged (outside region)
      assert get_line_text(emulator, 4) == line4_before
      # Line 5 unchanged (outside region)
      assert get_line_text(emulator, 5) == line5_before
    end

    test 'DL outside scroll region has no effect' do
      emulator = Emulator.new(80, 5)
      emulator = fill_buffer(emulator, 0, 5)
      # Set scroll region lines 2 to 4 (index 1 to 3)
      {emulator, _} = Emulator.process_input(emulator, "\e[2;4r")
      # Use process_input with CUP instead of direct update
      # Move cursor to line 0 (index 0)
      {emulator, _} = Emulator.process_input(emulator, "\e[1;1H")

      buffer_before = Emulator.get_active_buffer(emulator)

      # Process CSI M (Delete line)
      {emulator_after, _} = Emulator.process_input(emulator, "\e[M")

      # Buffer should be unchanged
      assert Emulator.get_active_buffer(emulator_after) == buffer_before
    end
  end
end
