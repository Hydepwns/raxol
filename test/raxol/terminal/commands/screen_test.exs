defmodule Raxol.Terminal.Commands.ScreenTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Commands.Screen
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer

  # Set up test fixtures
  setup do
    # Create a minimal emulator for testing
    buffer = ScreenBuffer.new(10, 5)

    # Use Emulator.new instead of creating the struct directly
    emulator =
      Emulator.new(10, 5)
      |> Map.put(:main_screen_buffer, buffer)
      |> Map.put(:alternate_screen_buffer, ScreenBuffer.new(10, 5))
      |> put_in([:cursor, :position], {2, 2})

    {:ok, %{emulator: emulator}}
  end

  describe "clear_screen/2" do
    test "clears from cursor to end of screen (mode 0)", %{emulator: emulator} do
      # Fill buffer with test data
      filled_buffer =
        Enum.reduce(0..4, emulator.main_screen_buffer, fn y, acc ->
          Enum.reduce(0..9, acc, fn x, buf ->
            ScreenBuffer.put_cell(buf, x, y, "X", %{})
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
            ScreenBuffer.put_cell(buf, x, y, "X", %{})
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
            ScreenBuffer.put_cell(buf, x, y, "X", %{})
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
          ScreenBuffer.put_cell(buf, x, 2, "X", %{})
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
          ScreenBuffer.put_cell(buf, x, 2, "X", %{})
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
          ScreenBuffer.put_cell(buf, x, 2, "X", %{})
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
end
