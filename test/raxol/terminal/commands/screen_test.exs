defmodule Raxol.Terminal.Commands.ScreenTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Commands.Screen
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  # Restore the helper function
  defp initial_emulator(width \\ 80, height \\ 24) do
    Emulator.new(width, height)
  end

  # Set up test fixtures
  setup do
    # Create a minimal emulator for testing
    buffer = ScreenBuffer.new(10, 5)

    # Use Emulator.new instead of creating the struct directly
    emulator =
      Emulator.new(10, 5)
      |> Map.put(:main_screen_buffer, buffer)
      |> Map.put(:alternate_screen_buffer, ScreenBuffer.new(10, 5))
      # Update cursor directly on the struct
      |> Map.put(:cursor, %{Emulator.new(0,0).cursor | position: {2, 2}})

    {:ok, %{emulator: emulator}}
  end

  describe "clear_screen/2" do
    test "clears from cursor to end of screen (mode 0)", %{emulator: emulator} do
      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..4, emulator.main_screen_buffer, fn y, acc ->
          Enum.reduce(0..9, acc, fn x, buf ->
            ScreenBuffer.write_char(buf, x, y, "X", %{})
          end)
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}

      # Clear from cursor (2,2) to end of screen
      result = Screen.clear_screen(emulator, 0)

      # Check that cells before cursor are unchanged
      for y <- 0..1 do
        for x <- 0..9 do
          assert ScreenBuffer.get_cell(result.main_screen_buffer, x, y) == "X"
        end
      end

      for x <- 0..1 do
        assert ScreenBuffer.get_cell(result.main_screen_buffer, x, 2) == "X"
      end

      # Check that cells from cursor to end are cleared
      for y <- 2..4 do
        for x <- if(y == 2, do: 2, else: 0)..9 do
          assert ScreenBuffer.get_cell(result.main_screen_buffer, x, y) == nil
        end
      end
    end

    test "clears from beginning of screen to cursor (mode 1)", %{
      emulator: emulator
    } do
      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..4, emulator.main_screen_buffer, fn y, acc ->
          Enum.reduce(0..9, acc, fn x, buf ->
            ScreenBuffer.write_char(buf, x, y, "X", %{})
          end)
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}

      # Clear from beginning of screen to cursor (2,2)
      result = Screen.clear_screen(emulator, 1)

      # Check that cells up to cursor are cleared
      for y <- 0..1 do
        for x <- 0..9 do
          assert ScreenBuffer.get_cell(result.main_screen_buffer, x, y) == nil
        end
      end

      for x <- 0..2 do
        assert ScreenBuffer.get_cell(result.main_screen_buffer, x, 2) == nil
      end

      # Check that cells after cursor are unchanged
      for y <- 2..4 do
        for x <- if(y == 2, do: 3, else: 0)..9 do
          assert ScreenBuffer.get_cell(result.main_screen_buffer, x, y) == "X"
        end
      end
    end

    test "clears entire screen (mode 2)", %{emulator: emulator} do
      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..4, emulator.main_screen_buffer, fn y, acc ->
          Enum.reduce(0..9, acc, fn x, buf ->
            ScreenBuffer.write_char(buf, x, y, "X", %{})
          end)
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}

      # Clear entire screen
      result = Screen.clear_screen(emulator, 2)

      # Check that all cells are cleared
      for y <- 0..4 do
        for x <- 0..9 do
          assert ScreenBuffer.get_cell(result.main_screen_buffer, x, y) == nil
        end
      end
    end
  end

  describe "clear_line/2" do
    test "clears from cursor to end of line (mode 0)", %{emulator: emulator} do
      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..9, emulator.main_screen_buffer, fn x, buf ->
          ScreenBuffer.write_char(buf, x, 2, "X", %{})
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}

      # Clear from cursor (2,2) to end of line
      result = Screen.clear_line(emulator, 0)

      # Check that cells before cursor are unchanged
      for x <- 0..1 do
        assert ScreenBuffer.get_cell(result.main_screen_buffer, x, 2) == "X"
      end

      # Check that cells from cursor to end are cleared
      for x <- 2..9 do
        assert ScreenBuffer.get_cell(result.main_screen_buffer, x, 2) == nil
      end
    end

    test "clears from beginning of line to cursor (mode 1)", %{
      emulator: emulator
    } do
      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..9, emulator.main_screen_buffer, fn x, buf ->
          ScreenBuffer.write_char(buf, x, 2, "X", %{})
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}

      # Clear from beginning of line to cursor (2,2)
      result = Screen.clear_line(emulator, 1)

      # Check that cells before cursor are cleared
      for x <- 0..2 do
        assert ScreenBuffer.get_cell(result.main_screen_buffer, x, 2) == nil
      end

      # Check that cells after cursor are unchanged
      for x <- 3..9 do
        assert ScreenBuffer.get_cell(result.main_screen_buffer, x, 2) == "X"
      end
    end

    test "clears entire line (mode 2)", %{emulator: emulator} do
      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..9, emulator.main_screen_buffer, fn x, buf ->
          ScreenBuffer.write_char(buf, x, 2, "X", %{})
        end)

      emulator = %{emulator | main_screen_buffer: filled_buffer}

      # Clear entire line
      result = Screen.clear_line(emulator, 2)

      # Check that all cells in the line are cleared
      for x <- 0..9 do
        assert ScreenBuffer.get_cell(result.main_screen_buffer, x, 2) == nil
      end
    end
  end

  describe "EL and ED operations" do
    test "EL erases line from cursor to end" do
      emulator = Emulator.process_input(initial_emulator(), "Hello\e[2;3H")
      # Line 1: Hello
      # Line 2: World -> Wor|ld (Cursor at 2,3)
      emulator = Emulator.process_input(emulator, "World")
      emulator = Emulator.process_input(emulator, "\e[3D") # Move cursor to (1, 2)
      emulator = Emulator.process_input(emulator, "\e[K") # Erase Line from Cursor to End

      buffer = Emulator.get_buffer(emulator)
      line1 = ScreenBuffer.get_line(buffer, 0)
      line2 = ScreenBuffer.get_line(buffer, 1)

      # Expect "He" on line 2, followed by default cells
      expected_line2_start = [cell("W"), cell("o")]
      expected_line2_end = List.duplicate(Cell.new(" "), buffer.width - 2)
      assert Enum.map(line2, & &1.char) == ["W", "o"] ++ List.duplicate(" ", buffer.width - 2)
      # Ensure line 1 is untouched
      assert Enum.map(line1, & &1.char) == ["H", "e", "l", "l", "o"] ++ List.duplicate(" ", buffer.width - 5)
    end

    test "EL erases line from beginning to cursor" do
      emulator = Emulator.process_input(initial_emulator(), "Hello\nWorld\e[2;3H")
      emulator = Emulator.process_input(emulator, "\e[1K") # Erase Line from Beginning to Cursor

      buffer = Emulator.get_buffer(emulator)
      line2 = ScreenBuffer.get_line(buffer, 1)

      # Expect default cells then "rld"
      expected_line2_start = List.duplicate(Cell.new(" "), 2)
      expected_line2_end = [cell("r"), cell("l"), cell("d")]
      assert Enum.map(line2, & &1.char) == List.duplicate(" ", 2) ++ ["r", "l", "d"] ++ List.duplicate(" ", buffer.width - 5)
    end

    test "EL erases entire line" do
      emulator = Emulator.process_input(initial_emulator(), "Hello\nWorld\e[2;3H")
      emulator = Emulator.process_input(emulator, "\e[2K") # Erase Entire Line

      buffer = Emulator.get_buffer(emulator)
      line2 = ScreenBuffer.get_line(buffer, 1)
      assert Enum.all?(line2, &(&1.char == " "))
    end

    test "ED erases from cursor to end of screen" do
      emulator = Emulator.process_input(initial_emulator(), "Line1\nLine2\e[1;3H") # Cursor at (2,0) on 'n'
      emulator = Emulator.process_input(emulator, "\e[J") # Erase from cursor to end

      buffer = Emulator.get_buffer(emulator)
      line1 = ScreenBuffer.get_line(buffer, 0)
      line2 = ScreenBuffer.get_line(buffer, 1)

      # Line 1 should be "Li" + spaces
      assert Enum.map(line1, & &1.char) == ["L", "i"] ++ List.duplicate(" ", buffer.width - 2)
      # Line 2 and subsequent should be spaces
      assert Enum.all?(line2, &(&1.char == " "))
      # Add check for a line beyond the initial ones if needed
      if buffer.height > 2 do
        line3 = ScreenBuffer.get_line(buffer, 2)
        assert Enum.all?(line3, &(&1.char == " "))
      end
    end

    test "ED erases from beginning to cursor" do
      emulator = Emulator.process_input(initial_emulator(), "Line1\nLine2\e[2;3H") # Cursor at (2,1) on 'n'
      emulator = Emulator.process_input(emulator, "\e[1J") # Erase from beginning to cursor

      buffer = Emulator.get_buffer(emulator)
      line1 = ScreenBuffer.get_line(buffer, 0)
      line2 = ScreenBuffer.get_line(buffer, 1)

      # Line 1 should be all spaces
      assert Enum.all?(line1, &(&1.char == " "))
      # Line 2 should be spaces up to cursor, then original chars
      assert Enum.map(line2, & &1.char) == List.duplicate(" ", 2) ++ ["n", "e", "2"] ++ List.duplicate(" ", buffer.width - 5)
    end

    test "ED erases entire screen" do
      emulator = Emulator.process_input(initial_emulator(), "Line1\nLine2\e[2;3H")
      emulator = Emulator.process_input(emulator, "\e[2J") # Erase entire screen

      buffer = Emulator.get_buffer(emulator)

      for y <- 0..(buffer.height - 1) do
        line = ScreenBuffer.get_line(buffer, y)
        assert Enum.all?(line, &(&1.char == " "))
      end
    end

    # Helper for creating a cell - adjust if needed
    defp cell(char, style \\ %{}) do
      Raxol.Terminal.Cell.new(char, style)
    end
  end
end
