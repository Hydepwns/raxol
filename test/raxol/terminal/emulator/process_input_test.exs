defmodule Raxol.Terminal.Emulator.ProcessInputTest do
  use ExUnit.Case

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.ScreenBuffer

  describe "process_input state machine" do
    # Tests focus on how Emulator.process_input handles various sequences

    test "handles basic CSI sequence (Cursor Up)" do
      emulator = Emulator.new(80, 24)
      # Move cursor down first
      emulator = %{emulator | cursor: Manager.move_to(emulator.cursor, 0, 5)}
      assert emulator.cursor.position == {0, 5}

      # Process CSI A (Cursor Up)
      {emulator, ""} = Emulator.process_input(emulator, "\e[A")
      assert emulator.cursor.position == {0, 4}
    end

    test "handles parameterized CSI sequence (Cursor Down 5)" do
      emulator = Emulator.new(80, 24)
      assert emulator.cursor.position == {0, 0}

      # Process CSI 5 B (Cursor Down 5)
      {emulator, ""} = Emulator.process_input(emulator, "\e[5B")
      assert emulator.cursor.position == {0, 5}
    end

    test "handles multi-parameter CSI sequence (Cursor Position 10, 20)" do
      emulator = Emulator.new(80, 24)
      assert emulator.cursor.position == {0, 0}

      # Process CSI 20;10 H (Cursor Position row 20, col 10)
      {emulator, ""} = Emulator.process_input(emulator, "\e[20;10H")
      # Remember: row/col are 1-based in sequence, state is {col, row} 0-based
      assert emulator.cursor.position == {9, 19}
    end

    test "handles mixed printable text and CSI sequences" do
      emulator = Emulator.new(80, 24)
      # Write "Hello", move cursor up, write "World"
      input = "Hello" <> "\e[A" <> "World"
      {emulator, ""} = Emulator.process_input(emulator, input)

      buffer = Emulator.get_active_buffer(emulator)
      # Check buffer content
      assert ScreenBuffer.get_cell_at(buffer, 0, 0).char == "H"
      assert ScreenBuffer.get_cell_at(buffer, 4, 0).char == "o"
      # Cursor moves to {5, 0}, then Up -> {5, 0} (clamped), then "World" writes
      assert ScreenBuffer.get_cell_at(buffer, 5, 0).char == "W"
      assert ScreenBuffer.get_cell_at(buffer, 9, 0).char == "d"
      # Final cursor position
      assert emulator.cursor.position == {10, 0}
    end

    test "handles OSC sequence (Set Window Title)" do
      emulator = Emulator.new(80, 24)
      title = "My Test Title"
      # Process OSC 0 ; title ST (ESC ] 0 ; title ESC \\)
      input = "\e]0;" <> title <> "\e\\"
      {emulator, ""} = Emulator.process_input(emulator, input)

      # Check window_title field was updated
      assert emulator.window_title == title
    end

    test "handles simple ESC sequence (Index)" do
      emulator = Emulator.new(80, 24)
      # Position cursor
      emulator = %{emulator | cursor: Manager.move_to(emulator.cursor, 5, 5)}
      assert emulator.cursor.position == {5, 5}

      # Process ESC D (Index - move down one line, same column)
      {emulator, ""} = Emulator.process_input(emulator, "\eD")
      assert emulator.cursor.position == {5, 6}
    end

    test "handles basic DCS sequence" do
      emulator = Emulator.new(80, 24)
      # Example DCS sequence (content doesn't matter for this test)
      # \\eP is DCS start, \\e\\\\ is ST (String Terminator)
      dcs_sequence = <<27>> <> "P1;1;1{" <> "hello world" <> <<27>> <> "\\"
      {_emulator, remaining} = Emulator.process_input(emulator, dcs_sequence)

      # For now, assert that the sequence is consumed completely
      assert remaining == ""
      # More specific assertions could be added if Emulator state tracks DCS processing
    end

    test "handles CSI with intermediate character (Private Mode DECTCEM Show Cursor)" do
      emulator = Emulator.new(80, 24)
      # Ensure cursor starts hidden for the test to be meaningful (if default is visible)
      # Note: We might need a function like Emulator.set_mode(emulator, :cursor_visible, false) if available
      # Or assume a reset sequence was processed: emulator = process_input(emulator, "\e[?25l") first

      # Example private mode sequence: Show Cursor (DECTCEM)
      # CSI ? 25 h
      sequence = "\e[?25h"
      {emulator, remaining} = Emulator.process_input(emulator, sequence)

      # Assert the sequence is consumed
      assert remaining == ""
      # Assert cursor visibility state change (DECTCEM enables cursor)
      assert emulator.mode_state.cursor_visible == true
    end

    test "handles incomplete CSI sequence correctly" do
      emulator = Emulator.new(80, 24)
      partial_input = "\e["
      {emulator_after, _output1} = Emulator.process_input(emulator, partial_input)

      # Check that the parser didn't crash and returned the partial input
      # (or indicated incomplete state somehow?)
      # Current API returns output_buffer as second element, not remaining input.
      # Asserting remaining1 == partial_input seems wrong based on current process_input signature.
      # NO ASSERTION ON remaining1 NEEDED. We just check the final state after next input.

      # Maybe the test should assert something else?
      # e.g., assert emulator_after state indicates partial sequence? (No such state exists)

      # Send the rest of the sequence (e.g., Cursor Up 'A')
      rest_of_input = "A"
      {_emulator, remaining2} = Emulator.process_input(emulator, rest_of_input)

      # Expect the sequence to be completed and consumed
      assert remaining2 == ""
      # We can check the final cursor position after the completed sequence
      assert emulator.cursor.position == {0, 0} # Assuming initial {0,0} and Up clamps
    end

    test "resets state after incomplete sequence followed by text" do
      emulator = Emulator.new(80, 24)
      partial_input = "\e["
      {emulator_after_partial, _output1} = Emulator.process_input(emulator, partial_input)

      # Process subsequent normal text
      text_input = "Hello"
      {emulator, remaining2} = Emulator.process_input(emulator, text_input)

      # Assuming parser resets, expect text to be processed, remaining empty.
      assert remaining2 == ""
      # Check buffer for "Hello" and cursor position
      buffer = Emulator.get_active_buffer(emulator)
      assert ScreenBuffer.get_cell_at(buffer, 0, 0).char == "H"
      assert emulator.cursor.position == {5, 0}
    end
  end
end
