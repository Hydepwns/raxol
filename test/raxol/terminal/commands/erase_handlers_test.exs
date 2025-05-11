defmodule Raxol.Terminal.Commands.EraseHandlersTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Commands.EraseHandlers
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ANSI.TextFormatting

  setup do
    # Create a test emulator with a 10x10 screen
    emulator = %Emulator{
      main_screen_buffer: ScreenBuffer.new(10, 10),
      cursor: CursorManager.new(),
      style: TextFormatting.new()
    }
    {:ok, emulator: emulator}
  end

  describe "handle_J/2 (Erase in Display)" do
    test "erases from cursor to end of screen (mode 0)", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = EraseHandlers.handle_J(emulator, [0])

      # Verify content before cursor is preserved
      for y <- 0..4 do
        for x <- 0..9 do
          assert ScreenBuffer.get_char(result.main_screen_buffer, x, y) == "X"
        end
      end

      # Verify content from cursor to end is erased
      for y <- 5..9 do
        start_x = if y == 5, do: 5, else: 0
        for x <- start_x..9 do
          assert ScreenBuffer.get_char(result.main_screen_buffer, x, y) == " "
        end
      end
    end

    test "erases from beginning of screen to cursor (mode 1)", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = EraseHandlers.handle_J(emulator, [1])

      # Verify content before cursor is erased
      for y <- 0..4 do
        for x <- 0..9 do
          assert ScreenBuffer.get_char(result.main_screen_buffer, x, y) == " "
        end
      end

      # Verify content from cursor to end is preserved
      for y <- 5..9 do
        start_x = if y == 5, do: 5, else: 0
        for x <- start_x..9 do
          assert ScreenBuffer.get_char(result.main_screen_buffer, x, y) == "X"
        end
      end
    end

    test "erases entire screen (mode 2)", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = EraseHandlers.handle_J(emulator, [2])

      # Verify all content is erased
      for y <- 0..9 do
        for x <- 0..9 do
          assert ScreenBuffer.get_char(result.main_screen_buffer, x, y) == " "
        end
      end
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = EraseHandlers.handle_J(emulator, [])

      # Should default to mode 0 (erase from cursor to end)
      for y <- 0..4 do
        for x <- 0..9 do
          assert ScreenBuffer.get_char(result.main_screen_buffer, x, y) == "X"
        end
      end

      for y <- 5..9 do
        start_x = if y == 5, do: 5, else: 0
        for x <- start_x..9 do
          assert ScreenBuffer.get_char(result.main_screen_buffer, x, y) == " "
        end
      end
    end
  end

  describe "handle_K/2 (Erase in Line)" do
    test "erases from cursor to end of line (mode 0)", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of line
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = EraseHandlers.handle_K(emulator, [0])

      # Verify content before cursor is preserved
      for x <- 0..4 do
        assert ScreenBuffer.get_char(result.main_screen_buffer, x, 5) == "X"
      end

      # Verify content from cursor to end of line is erased
      for x <- 5..9 do
        assert ScreenBuffer.get_char(result.main_screen_buffer, x, 5) == " "
      end
    end

    test "erases from beginning of line to cursor (mode 1)", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of line
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = EraseHandlers.handle_K(emulator, [1])

      # Verify content before cursor is erased
      for x <- 0..5 do
        assert ScreenBuffer.get_char(result.main_screen_buffer, x, 5) == " "
      end

      # Verify content from cursor to end of line is preserved
      for x <- 6..9 do
        assert ScreenBuffer.get_char(result.main_screen_buffer, x, 5) == "X"
      end
    end

    test "erases entire line (mode 2)", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of line
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = EraseHandlers.handle_K(emulator, [2])

      # Verify entire line is erased
      for x <- 0..9 do
        assert ScreenBuffer.get_char(result.main_screen_buffer, x, 5) == " "
      end
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of line
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = EraseHandlers.handle_K(emulator, [])

      # Should default to mode 0 (erase from cursor to end)
      for x <- 0..4 do
        assert ScreenBuffer.get_char(result.main_screen_buffer, x, 5) == "X"
      end

      for x <- 5..9 do
        assert ScreenBuffer.get_char(result.main_screen_buffer, x, 5) == " "
      end
    end
  end

  # Helper function to fill buffer with test data
  defp fill_buffer_with_test_data(emulator) do
    buffer = emulator.main_screen_buffer
    for y <- 0..9 do
      for x <- 0..9 do
        buffer = ScreenBuffer.write_char(buffer, x, y, "X", TextFormatting.new())
      end
    end
    %{emulator | main_screen_buffer: buffer}
  end
end
