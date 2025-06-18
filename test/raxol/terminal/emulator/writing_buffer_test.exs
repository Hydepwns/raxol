defmodule Raxol.Terminal.Emulator.WritingBufferTest do
  use ExUnit.Case
  import Mox

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  # Removed unused alias: Raxol.Terminal.ANSI.ScreenModes

  # Setup block to ensure a fresh emulator and Mox state for each test
  setup :verify_on_exit!

  setup do
    # Default size, tests can override if needed
    emulator = Emulator.new(80, 24)
    %{emulator: emulator}
  end

  describe "Emulator Writing and Buffer" do
    test "write adds text to screen buffer and moves cursor", %{
      emulator: emulator
    } do
      # emulator = Emulator.new(80, 24) # Removed: Use emulator from context
      {emulator, _} = Emulator.process_input(emulator, "Hello")
      # Check buffer content -> use main_screen_buffer
      buffer = Emulator.get_active_buffer(emulator)
      line0_cells = Enum.at(buffer.cells, 0)
      line0_text = Enum.map_join(line0_cells, & &1.char)
      assert String.starts_with?(line0_text, "Hello")
      # Check cursor position (simple case, no wrap)
      assert emulator.cursor.position == {5, 0},
             "Cursor should be at col 5, row 0"
    end

    test "clear_buffer creates a new empty buffer", %{emulator: emulator} do
      # emulator = Emulator.new(80, 24) # Removed: Use emulator from context
      # Use field access - THIS IS INCORRECT, new buffer is NOT empty
      # refute ScreenBuffer.is_empty?(Emulator.get_active_buffer(emulator))

      # emulator = Emulator.new(80, 24) # Removed
      # Use field access - THIS IS INCORRECT, new buffer is NOT empty
      # assert ScreenBuffer.is_empty?(Emulator.get_active_buffer(emulator))
      # Clear buffer doesn't reset cursor, Emulator.new() does.

      # buffer_before = Emulator.get_active_buffer(emulator) # Not needed
      # Replace the direct call with processing the ANSI clear screen sequence
      # Use the correct Elixir escape sequence representation: \e
      {emulator_after, _output} = Emulator.process_input(emulator, "\e[2J")
      buffer_after = Emulator.get_active_buffer(emulator_after)
      # Verify the buffer cells contain spaces (cleared), ignore style
      all_spaces =
        Enum.all?(buffer_after.cells, fn row ->
          Enum.all?(row, fn cell -> cell.char == " " end)
        end)

      assert all_spaces,
             "All cells should contain space character after clearing"
    end

    test "get_buffer returns the screen buffer struct", %{emulator: emulator} do
      # emulator = Emulator.new(80, 24) # Removed: Use emulator from context
      buffer = Emulator.get_active_buffer(emulator)
      assert is_struct(buffer, ScreenBuffer)
      assert buffer.width == 80
    end

    test "handles basic text input with newline", %{emulator: emulator} do
      # emulator = Emulator.new(80, 24) # Removed: Use emulator from context
      # Use process_input
      # Ignore the output string, as it's not relevant to this test
      {emulator_after, _output} =
        Emulator.process_input(emulator, "Hello\nWorld")

      # Corrected assertion: After "Hello\nWorld" with LNM off, cursor should be at {10, 1}
      assert emulator_after.cursor.position == {10, 1},
             "Cursor should be at col 10, row 1"

      # Verify buffer content
      buffer = Emulator.get_active_buffer(emulator_after)

      # Expected Screen: Line 0: "Hello", Line 1: "World" (cursor at {10, 1})
      expected_cells_line0 =
        [
          Cell.new("H"),
          Cell.new("e"),
          Cell.new("l"),
          Cell.new("l"),
          Cell.new("o")
        ] ++ List.duplicate(Cell.new(" "), 75)

      expected_cells_line1 =
        [
          Cell.new("W"),
          Cell.new("o"),
          Cell.new("r"),
          Cell.new("l"),
          Cell.new("d")
        ] ++ List.duplicate(Cell.new(" "), 75)

      # Compare relevant fields directly for line 0
      actual_cells_line0 = Enum.at(buffer.cells, 0)

      assert length(actual_cells_line0) == length(expected_cells_line0),
             "Line 0 (Newline Test): Length mismatch"

      Enum.zip(actual_cells_line0, expected_cells_line0)
      |> Enum.with_index()
      |> Enum.each(fn {{actual, expected}, index} ->
        assert actual.char == expected.char,
               "Line 0 (Newline Test): Char mismatch at index #{index}"

        assert actual.style == expected.style,
               "Line 0 (Newline Test): Style mismatch at index #{index}: Act: #{inspect(actual.style)} Exp: #{inspect(expected.style)}"

        assert actual.is_wide_placeholder == expected.is_wide_placeholder,
               "Line 0 (Newline Test): Wide placeholder mismatch at index #{index}"
      end)

      # Check cursor position
      assert emulator_after.cursor.position == {10, 1},
             "Cursor should be at col 10, row 1"
    end

    test "handles basic text input with newline AND MORE", %{emulator: emulator} do
      # emulator = Emulator.new(80, 24) # Removed: Use emulator from context
      # Use process_input
      # Correct the escape sequence for newline
      {emulator_after, ""} =
        Emulator.process_input(emulator, "Line 1\n Line 2")

      # Check cursor position after processing
      assert emulator_after.cursor.position == {13, 1},
             "Cursor should be at col 13, row 1"

      # Check buffer content after processing
      buffer = Emulator.get_active_buffer(emulator_after)

      # Expected Screen: Line 0: "Line 1", Line 1: "       Line 2" (starts at col 7 after space)
      expected_buffer = %Raxol.Terminal.ScreenBuffer{
        width: 80,
        height: 24,
        cells:
          [
            # Line 0: "Line 1" + padding
            [
              Cell.new("L"),
              Cell.new("i"),
              Cell.new("n"),
              Cell.new("e"),
              Cell.new(" "),
              Cell.new("1")
            ] ++ List.duplicate(Cell.new(" "), 74),
            # Line 1: "       Line 2" + padding
            List.duplicate(Cell.new(" "), 7) ++
              [
                Cell.new("L"),
                Cell.new("i"),
                Cell.new("n"),
                Cell.new("e"),
                Cell.new(" "),
                Cell.new("2")
              ] ++ List.duplicate(Cell.new(" "), 67)
          ] ++ List.duplicate(List.duplicate(Cell.new(" "), 80), 22),
        scrollback: [],
        scrollback_limit: 1000,
        selection: nil,
        scroll_region: nil
      }

      # Assert relevant buffer fields directly
      assert buffer.width == expected_buffer.width
      assert buffer.height == expected_buffer.height

      # Revert to comparing the entire cells list directly
      assert buffer.cells == expected_buffer.cells,
             "Screen buffer cells mismatch"

      # Check cursor position
      assert emulator_after.cursor.position == {13, 1},
             "Cursor should be at col 13, row 1"
    end

    test "get_cell_at retrieves cell at valid coordinates", %{
      emulator: emulator
    } do
      # emulator = Emulator.new(80, 24) # Removed: Use emulator from context
      # Use ScreenBuffer.get_cell_at via get_active_buffer
      cell =
        ScreenBuffer.get_cell_at(Emulator.get_active_buffer(emulator), 0, 0)

      assert is_struct(cell, Cell)
      # Can add more assertions, e.g., default cell content
      # Assuming default is space
      assert cell.char == " "
      # Revert back to comparing the whole style map
      assert cell.style == Raxol.Terminal.ANSI.TextFormatting.new()
    end

    test "process single char H", %{emulator: emulator} do
      # emulator = Emulator.new(80, 24) # Removed: Use emulator from context
      {emulator_after, _output} = Emulator.process_input(emulator, "H")

      assert emulator_after.cursor.position == {1, 0},
             "Cursor after "H" should be {1, 0}"
    end

    # This test needs specific dimensions, so create a new emulator instance here
    test "basic autowrap at end of line", %{emulator: _emulator_from_setup} do
      # width=10, height=1, autowrap is default ON
      emulator = Emulator.new(10, 1)

      # Write 10 chars to fill the line
      {emulator, _} = Emulator.process_input(emulator, "1234567890")

      # Check state AFTER 10 chars (BEFORE wrap should trigger)
      assert emulator.cursor.position == {9, 0},
             "Cursor should be at col 9, row 0 BEFORE wrap"

      assert emulator.last_col_exceeded == true,
             "last_col_exceeded should be true BEFORE wrap"

      # Write 11th char to trigger the wrap
      {emulator_after_wrap, _} = Emulator.process_input(emulator, "X")

      # === Check state AFTER wrap is triggered ===
      buffer_after_wrap = Emulator.get_active_buffer(emulator_after_wrap)
      # Check line 0 (should be unchanged)
      line0_text_original =
        buffer_after_wrap
        |> ScreenBuffer.get_line(0)
        |> Enum.map_join(& &1.char)

      assert String.trim_trailing(line0_text_original) == "1234567890",
             "Line 0 should be unchanged after wrap"

      # Check cursor position and flag
      # Note: The cursor should move to the next line (row 1), column 1 (0-based)
      assert emulator_after_wrap.cursor.position == {1, 1},
             "Cursor should be at {1, 1} AFTER wrap"

      assert emulator_after_wrap.last_col_exceeded == false,
             "last_col_exceeded should be false AFTER wrap"
    end

    # This test needs specific dimensions and modes, so create a new emulator instance here
    test "autowrap disabled prevents wrapping", %{
      emulator: _emulator_from_setup
    } do
      emulator = Emulator.new(10, 1)
      # Disable autowrap explicitly using the ANSI sequence for RM ?7l
      # Use the correct Elixir escape sequence representation: \e
      {emulator, _} = Emulator.process_input(emulator, "\e[?7l")

      # Write 9 chars
      {emulator_after_9, _} = Emulator.process_input(emulator, "123456789")

      assert emulator_after_9.cursor.position == {9, 0},
             "Cursor should be at col 9, row 0 after 9 chars"

      refute emulator_after_9.last_col_exceeded,
             "last_col_exceeded should be false after 9 chars"

      # Write 10th char
      {emulator, _} = Emulator.process_input(emulator_after_9, "0")

      # Check state AFTER 10th char (autowrap off)
      assert emulator.cursor.position == {9, 0},
             "Cursor should be at col 9, row 0 (autowrap off) after 10th char"

      assert emulator.last_col_exceeded == true,
             "last_col_exceeded should be true (autowrap off) after 10th char"

      # Write 11th char
      {emulator_after_char11, _} = Emulator.process_input(emulator, "X")

      # Check state AFTER 11th char (autowrap off)
      # Buffer should NOT have scrolled, line 0 should contain overwritten 'X' at the end
      buffer_after_char11 = Emulator.get_active_buffer(emulator_after_char11)

      line0_text_after =
        buffer_after_char11
        |> ScreenBuffer.get_line(0)
        |> Enum.map_join(& &1.char)

      assert String.trim_trailing(line0_text_after) == "123456789X",
             "Line 0 should contain "...9X" after overwrite"

      # Cursor should be at col 9 (index 9) after writing stopped at the margin
      assert emulator_after_char11.cursor.position == {9, 0},
             "Cursor should be at col 9, row 0 (autowrap off)"
    end
  end
end
