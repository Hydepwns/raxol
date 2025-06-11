defmodule Raxol.Terminal.Commands.ScreenTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Commands.Screen
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  defp assert_entire_buffer_cleared(buffer, width \\ 10, height \\ 5) do
    for y <- 0..(height - 1) do
      for x <- 0..(width - 1) do
        cell = ScreenBuffer.get_cell(buffer, x, y)

        assert cell.char == " ",
               "Expected cell at (#{x},#{y}) to be cleared (space), got: #{inspect(cell)}"
      end
    end
  end

  # Set up test fixtures
  # setup do
  #   # Create a minimal emulator for testing using the constructor
  #   initial_emulator = Emulator.new(10, 5)
  #
  #   # Set cursor position using input processing
  #   {emulator, _output} = Emulator.process_input(initial_emulator, "\e[3;3H") # Move to (2, 2) zero-indexed
  #
  #   {:ok, %{emulator: emulator}}
  # end

  describe "clear_screen/2" do
    test "clears from cursor to end of screen (mode 0)" do
      # Setup: Create emulator and move cursor to (2,2)
      initial_emulator = Emulator.new(10, 5)
      # Move to (2, 2) zero-indexed
      {emulator, _output} = Emulator.process_input(initial_emulator, "\e[3;3H")

      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..4, emulator.main_screen_buffer, fn y, acc ->
          Enum.reduce(0..9, acc, fn x, buf ->
            ScreenBuffer.write_char(buf, x, y, "X", TextFormatting.new())
          end)
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}

      # Clear from cursor to end of screen (mode 0)
      emulator_after_clear = Screen.clear_screen(emulator, 0)

      # Check that cells before cursor are unchanged (check char)
      for y <- 0..1 do
        for x <- 0..9 do
          assert ScreenBuffer.get_cell(
                   emulator_after_clear.main_screen_buffer,
                   x,
                   y
                 ).char == "X"
        end
      end

      for x <- 0..1 do
        assert ScreenBuffer.get_cell(
                 emulator_after_clear.main_screen_buffer,
                 x,
                 2
               ).char == "X"
      end

      # Check that cells from cursor to end are cleared (check char is space)
      for y <- 2..4 do
        start_col = if y == 2, do: 2, else: 0

        for x <- start_col..9 do
          cell =
            ScreenBuffer.get_cell(emulator_after_clear.main_screen_buffer, x, y)

          assert cell.char == " ",
                 "Expected cell at (#{x},#{y}) to be cleared (space), got: #{inspect(cell)}"
        end
      end
    end

    test "clears from beginning of screen to cursor (mode 1)" do
      # Setup: Create emulator and move cursor to (2,2)
      initial_emulator = Emulator.new(10, 5)
      # Move to (2, 2) zero-indexed
      {emulator, _output} = Emulator.process_input(initial_emulator, "\e[3;3H")

      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..4, emulator.main_screen_buffer, fn y, acc ->
          Enum.reduce(0..9, acc, fn x, buf ->
            ScreenBuffer.write_char(buf, x, y, "X", TextFormatting.new())
          end)
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}

      # Assert that the specific cell (8,0) is "X" before clearing
      assert ScreenBuffer.get_cell(emulator.main_screen_buffer, 8, 0).char ==
               "X",
             "Cell (8,0) should be 'X' before clear_screen (mode 1) is called"

      # Clear from beginning of screen to cursor (2,2)
      emulator_after_clear = Screen.clear_screen(emulator, 1)

      # Check that cells up to cursor are cleared (check char is space)
      for y <- 0..1 do
        for x <- 0..9 do
          cell =
            ScreenBuffer.get_cell(emulator_after_clear.main_screen_buffer, x, y)

          assert cell.char == " ",
                 "Expected cell at (#{x},#{y}) to be cleared (space), got: #{inspect(cell)}"
        end
      end

      for x <- 0..2 do
        cell =
          ScreenBuffer.get_cell(emulator_after_clear.main_screen_buffer, x, 2)

        assert cell.char == " ",
               "Expected cell at (#{x},2) to be cleared (space), got: #{inspect(cell)}"
      end

      # Check that cells after cursor are unchanged (check char)
      for y <- 2..4 do
        start_col = if y == 2, do: 3, else: 0

        for x <- start_col..9 do
          cell =
            ScreenBuffer.get_cell(emulator_after_clear.main_screen_buffer, x, y)

          assert cell.char == "X",
                 "Expected cell at (#{x},#{y}) to be 'X', got: #{inspect(cell)}"
        end
      end
    end

    test "clears entire screen (mode 2)" do
      # Setup: Create emulator and move cursor to (2,2)
      initial_emulator = Emulator.new(10, 5)
      # Move to (2, 2) zero-indexed
      {emulator, _output} = Emulator.process_input(initial_emulator, "\e[3;3H")

      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..4, emulator.main_screen_buffer, fn y, acc ->
          Enum.reduce(0..9, acc, fn x, buf ->
            ScreenBuffer.write_char(buf, x, y, "X", TextFormatting.new())
          end)
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}

      # Clear entire screen
      result = Screen.clear_screen(emulator, 2)

      # Check that all cells are cleared
      assert_entire_buffer_cleared(result.main_screen_buffer)
    end

    test "clears entire screen and scrollback (mode 3)" do
      # Setup: Create emulator and move cursor to (2,2)
      initial_emulator = Emulator.new(10, 5)
      # Move to (2, 2) zero-indexed
      {emulator, _output} = Emulator.process_input(initial_emulator, "\e[3;3H")

      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..4, emulator.main_screen_buffer, fn y, acc ->
          Enum.reduce(0..9, acc, fn x, buf ->
            ScreenBuffer.write_char(buf, x, y, "X", TextFormatting.new())
          end)
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}
      # Clear entire screen and scrollback
      result = Screen.clear_screen(emulator, 3)

      # Check that all cells are cleared
      assert_entire_buffer_cleared(result.main_screen_buffer)

      # TODO: Add check for scrollback buffer if it\\'s implemented and accessible
    end
  end

  describe "clear_line/2" do
    test "clears from cursor to end of line (mode 0)" do
      initial_emulator = Emulator.new(10, 5)
      {emulator, _output} = Emulator.process_input(initial_emulator, "\e[3;3H")

      filled_buffer =
        Enum.reduce(0..9, emulator.main_screen_buffer, fn x, buf ->
          ScreenBuffer.write_char(buf, x, 2, "X", TextFormatting.new())
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}
      result = Screen.clear_line(emulator, 0)

      for x <- 0..1 do
        cell = ScreenBuffer.get_cell(result.main_screen_buffer, x, 2)
        assert cell.char == "X"
      end

      for x <- 2..9 do
        cell = ScreenBuffer.get_cell(result.main_screen_buffer, x, 2)
        assert cell.char == " "
      end
    end

    test "clears from beginning of line to cursor (mode 1)" do
      # Setup: Create emulator and move cursor to (2,2)
      initial_emulator = Emulator.new(10, 5)
      # Move to (2, 2) zero-indexed
      {emulator, _output} = Emulator.process_input(initial_emulator, "\e[3;3H")

      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..9, emulator.main_screen_buffer, fn x, buf ->
          ScreenBuffer.write_char(buf, x, 2, "X", TextFormatting.new())
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}

      # Clear from beginning of line to cursor (2,2)
      result = Screen.clear_line(emulator, 1)

      # Check that cells before cursor are cleared (check char is space)
      for x <- 0..2 do
        cell = ScreenBuffer.get_cell(result.main_screen_buffer, x, 2)

        assert cell.char == " ",
               "Expected cell at (#{x},2) to be cleared (space), got: #{inspect(cell)}"
      end

      # Check that cells after cursor are unchanged (check char)
      for x <- 3..9 do
        cell = ScreenBuffer.get_cell(result.main_screen_buffer, x, 2)

        assert cell.char == "X",
               "Expected cell at (#{x},2) to be 'X', got: #{inspect(cell)}"
      end
    end

    test "clears entire line (mode 2)" do
      # Setup: Create emulator and move cursor to (2,2)
      initial_emulator = Emulator.new(10, 5)
      # Move to (2, 2) zero-indexed
      {emulator, _output} = Emulator.process_input(initial_emulator, "\e[3;3H")

      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..9, emulator.main_screen_buffer, fn x, buf ->
          ScreenBuffer.write_char(buf, x, 2, "X", TextFormatting.new())
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}

      # Clear entire line
      result = Screen.clear_line(emulator, 2)

      # Check that all cells in the line are cleared (check char is space)
      for x <- 0..9 do
        cell = ScreenBuffer.get_cell(result.main_screen_buffer, x, 2)

        assert cell.char == " ",
               "Expected cell at (#{x},2) to be cleared (space), got: #{inspect(cell)}"
      end
    end
  end

  describe "EL and ED operations" do
    # Setup for EL tests specifically, providing emulator and buffer_width/height
    setup do
      # width 10, height 5
      emulator = Emulator.new(10, 5)
      {:ok, %{emulator: emulator, buffer_width: 10, buffer_height: 5}}
    end

    # test "EL erases line from cursor to end", %{emulator: emulator, buffer_width: _buffer_width} do
    #   # Initial: "Hello" at (0,0), cursor at (5,0)
    #   # Move: to (2,1)
    #   # Write: "World", cursor at (7,1) (0-indexed: __World___)
    #   # Move: 3 left to (4,1) (on 'l' of "World")
    #   # Erase: \e[K (EL mode 0: from cursor to end)
    #   input_str = "Hello\e[2;3HWorld\e[3D\e[K"
    #   {emulator, _output} = Emulator.process_input(emulator, input_str)
    #   buffer = Emulator.get_active_buffer(emulator)
    #
    #   line1_cells = ScreenBuffer.get_line(buffer, 0)
    #   line2_cells = ScreenBuffer.get_line(buffer, 1)
    #
    #   # Line 0 should remain "Hello" followed by spaces
    #   assert Enum.map(line1_cells, & &1.char) == String.graphemes("Hello") ++ List.duplicate(" ", buffer.width - 5)
    #
    #   # Line 1: After "World" at (2,1) -> "  World   "
    #   # Cursor moves to (4,1) (on 'l'). \e[K clears from 'l' to end.
    #   # Expected: "  Wo      "
    #   assert Enum.map(line2_cells, & &1.char) == ~c"  Wo" ++ List.duplicate(" ", buffer.width - 4)
    #
    #   assert Emulator.get_cursor_position(emulator) == {4, 1}
    # end

    # test "EL erases line from beginning to cursor", %{emulator: emulator, buffer_width: _buffer_width} do
    #   input_str = "Hello\e[2;3HWorld\e[3D\e[1K"
    #   {emulator, _output} = Emulator.process_input(emulator, input_str)
    #   buffer = Emulator.get_active_buffer(emulator)
    #   line1_cells = ScreenBuffer.get_line(buffer, 0)
    #   line2_cells = ScreenBuffer.get_line(buffer, 1)
    #
    #   # Line 0 should remain "Hello" followed by spaces
    #   assert Enum.map(line1_cells, & &1.char) == String.graphemes("Hello") ++ List.duplicate(" ", buffer.width - 5)
    #   # Line 1: After "World" at (2,1) -> "  World   "
    #   # Cursor moves to (4,1) (on 'l' of "World"). Content: [' ', ' ', 'W', 'o', 'r', 'l', 'd', ' ', ' ', ' ']. Cursor x-coord is 4.
    #   # \e[1K clears from beginning up to and including cursor (index 4).
    #   # Clears indices 0, 1, 2, 3, 4. Expected: "     ld   "
    #   assert Enum.map(line2_cells, & &1.char) == List.duplicate(" ", 5) ++ String.graphemes("ld") ++ List.duplicate(" ", buffer.width - 7)
    #   assert Emulator.get_cursor_position(emulator) == {4, 1}
    # end

    # test "EL erases entire line", %{emulator: emulator, buffer_width: _buffer_width} do
    #   input_str = "Hello\e[2;3HWorld\e[3D\e[2K"
    #   {emulator, _output} = Emulator.process_input(emulator, input_str)
    #   buffer = Emulator.get_active_buffer(emulator)
    #   line1_cells = ScreenBuffer.get_line(buffer, 0)
    #   line2_cells = ScreenBuffer.get_line(buffer, 1)
    #
    #   # Line 0: "Hello     "
    #   assert Enum.map(line1_cells, & &1.char) == String.graphemes("Hello") ++ List.duplicate(" ", buffer.width - 5)
    #   # Line 1: After "World" at (2,1) -> "  World   "
    #   # Cursor at (4,1). \e[2K clears entire line 1.
    #   assert Enum.map(line2_cells, & &1.char) == List.duplicate(" ", buffer.width)
    #   assert Emulator.get_cursor_position(emulator) == {4, 1} # Cursor position should not change
    # end

    test "ED erases screen from beginning to cursor", %{
      emulator: emulator,
      buffer_width: _buffer_width,
      buffer_height: _buffer_height
    } do
      # Fill screen with 'A's, then put 'B's on line 1, 'C's on line 2, 'D's on line 3
      # Cursor at (1,3) (0-indexed)
      # Erase: \e[1J (ED mode 1: from beginning to cursor)

      text_style = TextFormatting.new()

      # Fill each row with appropriate characters
      filled_buffer = emulator.main_screen_buffer

      # Fill row 0 with 'A's
      filled_buffer =
        Enum.reduce(0..9, filled_buffer, fn x, buf ->
          ScreenBuffer.write_char(buf, x, 0, "A", text_style)
        end)

      # Fill row 1 with 'B's
      filled_buffer =
        Enum.reduce(0..9, filled_buffer, fn x, buf ->
          ScreenBuffer.write_char(buf, x, 1, "B", text_style)
        end)

      # Fill row 2 with 'C's
      filled_buffer =
        Enum.reduce(0..9, filled_buffer, fn x, buf ->
          ScreenBuffer.write_char(buf, x, 2, "C", text_style)
        end)

      # Fill row 3 with 'D's
      filled_buffer =
        Enum.reduce(0..9, filled_buffer, fn x, buf ->
          ScreenBuffer.write_char(buf, x, 3, "D", text_style)
        end)

      # Fill row 4 with 'A's
      filled_buffer =
        Enum.reduce(0..9, filled_buffer, fn x, buf ->
          ScreenBuffer.write_char(buf, x, 4, "A", text_style)
        end)

      emulator = Emulator.update_active_buffer(emulator, filled_buffer)

      # Move to position (1,3) and erase from beginning to cursor
      # Cursor to (1,3) (0-indexed), then erase to beginning
      input_str = "\e[4;2H\e[1J"

      {emulator, _output} = Emulator.process_input(emulator, input_str)
      buffer = Emulator.get_active_buffer(emulator)

      # Lines 0, 1, 2 should be all spaces
      for y <- 0..2 do
        assert Enum.map(ScreenBuffer.get_line(buffer, y), & &1.char) ==
                 List.duplicate(" ", buffer.width)
      end

      # Line 3: Cursor was at (1,3). " DDDDDDDDDD" -> "  DDDDDDDDD"
      # First char (index 0) and second char (index 1, cursor pos) cleared.
      # Expected: "  DDDDDDDDD"
      assert Enum.map(ScreenBuffer.get_line(buffer, 3), & &1.char) ==
               List.duplicate(" ", 2) ++ String.graphemes("DDDDDDDD")

      # Line 4 should be untouched "AAAAAAAAAA"
      assert Enum.map(ScreenBuffer.get_line(buffer, 4), & &1.char) ==
               List.duplicate("A", buffer.width)

      assert Emulator.get_cursor_position(emulator) == {1, 3}
    end

    test "ED erases entire screen", %{
      emulator: emulator,
      buffer_width: _buffer_width,
      buffer_height: _buffer_height
    } do
      # Fill screen with 'A's
      # Cursor at (1,1)
      # Erase: \e[2J (ED mode 2: entire screen)

      # Replace ScreenBuffer.fill/3 with manual iteration using ScreenBuffer.write_char/5
      text_style_a = TextFormatting.new()

      full_a_buffer =
        Enum.reduce(
          0..(emulator.main_screen_buffer.height - 1),
          emulator.main_screen_buffer,
          fn y, acc_buffer ->
            Enum.reduce(
              0..(emulator.main_screen_buffer.width - 1),
              acc_buffer,
              fn x, inner_acc_buffer ->
                ScreenBuffer.write_char(
                  inner_acc_buffer,
                  x,
                  y,
                  "A",
                  text_style_a
                )
              end
            )
          end
        )

      emulator = Emulator.update_active_buffer(emulator, full_a_buffer)

      # Cursor to (1,1), then erase entire screen
      input_str = "\e[2;2H\e[2J"

      {emulator, _output} = Emulator.process_input(emulator, input_str)
      buffer = Emulator.get_active_buffer(emulator)

      # All lines should be spaces
      for y <- 0..(buffer.height - 1) do
        assert Enum.map(ScreenBuffer.get_line(buffer, y), & &1.char) ==
                 List.duplicate(" ", buffer.width)
      end

      # Cursor position does not change for ED
      assert Emulator.get_cursor_position(emulator) == {1, 1}
    end
  end
end
