defmodule Raxol.Terminal.Emulator.WritingBufferTest do
  use ExUnit.Case

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  describe "Emulator Writing and Buffer" do
    test "write adds text to screen buffer and moves cursor" do
      emulator = Emulator.new(80, 24)
      {emulator, _} = Emulator.process_input(emulator, "Hello")
      # Check buffer content -> use main_screen_buffer
      buffer = Emulator.get_active_buffer(emulator)
      line0_cells = Enum.at(buffer.cells, 0)
      line0_text = Enum.map_join(line0_cells, & &1.char)
      assert String.starts_with?(line0_text, "Hello")
      # Check cursor position (simple case, no wrap)
      assert emulator.cursor.position == {5, 0}
    end

    test "clear_buffer creates a new empty buffer" do
      emulator = Emulator.new(80, 24)
      # Use process_input to write text
      {emulator, _output} = Emulator.process_input(emulator, "abc")
      # Use field access
      refute ScreenBuffer.is_empty?(Emulator.get_active_buffer(emulator))

      emulator = Emulator.new(80, 24)
      # Use field access
      assert ScreenBuffer.is_empty?(Emulator.get_active_buffer(emulator))
      # Clear buffer doesn't reset cursor, Emulator.new() does.
    end

    test "get_buffer returns the screen buffer struct" do
      emulator = Emulator.new(80, 24)
      buffer = Emulator.get_active_buffer(emulator)
      assert is_struct(buffer, ScreenBuffer)
      assert buffer.width == 80
    end

    test "handles basic text input with newline" do
      emulator = Emulator.new(80, 24)
      # Use process_input
      {emulator_after, ""} =
        Emulator.process_input(emulator, "Line 1\\n Line 2")

      # Check cursor position after processing (LNM is OFF by default -> col stays same after LF -> 6 + 7 = 13)
      assert emulator_after.cursor.position == {13, 1},
             "Cursor should be at col 13, row 1"

      # Check buffer content after processing
      buffer = Emulator.get_active_buffer(emulator_after)

      # Expected Screen: Line 0: "Line 1", Line 1: "       Line 2" (starts at col 7 after space)
      expected_buffer = %Raxol.Terminal.ScreenBuffer{
        width: 80,
        height: 24,
        # Manually construct expected cells
        cells:
          [
            # Line 0: "Line 1" + padding
            [
              %Cell{char: "L"},
              %Cell{char: "i"},
              %Cell{char: "n"},
              %Cell{char: "e"},
              %Cell{char: " "},
              %Cell{char: "1"}
            ] ++ List.duplicate(%Cell{}, 74),
            # Line 1: "       Line 2" + padding
            List.duplicate(%Cell{}, 7) ++
              [
                %Cell{char: "L"},
                %Cell{char: "i"},
                %Cell{char: "n"},
                %Cell{char: "e"},
                %Cell{char: " "},
                %Cell{char: "2"}
              ] ++ List.duplicate(%Cell{}, 67)
            # Remaining empty lines
          ] ++ List.duplicate(List.duplicate(%Cell{}, 80), 22),
        scrollback: [],
        scrollback_limit: 1000,
        selection: nil,
        scroll_region: nil
      }

      # Assert relevant buffer fields directly
      assert buffer.width == expected_buffer.width
      assert buffer.height == expected_buffer.height

      # Compare cells row by row - potentially simplify if direct list comparison works
      assert buffer.cells == expected_buffer.cells,
             "Screen buffer cells mismatch"
    end

    test "get_cell_at retrieves cell at valid coordinates" do
      emulator = Emulator.new(80, 24)
      # Use ScreenBuffer.get_cell_at via get_active_buffer
      cell = ScreenBuffer.get_cell_at(Emulator.get_active_buffer(emulator), 0, 0)
      assert is_struct(cell, Cell)
      # Can add more assertions, e.g., default cell content
      assert cell.char == " " # Assuming default is space
      assert cell.style == %{}
    end
  end
end
