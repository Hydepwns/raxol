defmodule Raxol.Terminal.Commands.BufferHandlersTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Commands.BufferHandlers
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

  describe "handle_L/2 (Insert Line)" do
    test "inserts specified number of lines at cursor position", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {0, 5}}}

      result = BufferHandlers.handle_L(emulator, [2])

      # Verify lines were inserted
      assert get_line(result, 5) == String.duplicate(" ", 10)
      assert get_line(result, 6) == String.duplicate(" ", 10)
      # Verify original content was shifted down
      assert get_line(result, 7) == "Line 5"
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {0, 5}}}

      result = BufferHandlers.handle_L(emulator, [])

      # Verify one line was inserted
      assert get_line(result, 5) == String.duplicate(" ", 10)
      # Verify original content was shifted down
      assert get_line(result, 6) == "Line 5"
    end
  end

  describe "handle_M/2 (Delete Line)" do
    test "deletes specified number of lines at cursor position", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {0, 5}}}

      result = BufferHandlers.handle_M(emulator, [2])

      # Verify lines were deleted and content shifted up
      assert get_line(result, 5) == "Line 7"
      assert get_line(result, 6) == "Line 8"
      # Verify bottom lines are cleared
      assert get_line(result, 8) == String.duplicate(" ", 10)
      assert get_line(result, 9) == String.duplicate(" ", 10)
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {0, 5}}}

      result = BufferHandlers.handle_M(emulator, [])

      # Verify one line was deleted and content shifted up
      assert get_line(result, 5) == "Line 6"
      # Verify bottom line is cleared
      assert get_line(result, 9) == String.duplicate(" ", 10)
    end
  end

  describe "handle_P/2 (Delete Character)" do
    test "deletes specified number of characters at cursor position", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of line
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = BufferHandlers.handle_P(emulator, [2])

      # Verify characters were deleted and content shifted left
      assert get_line(result, 5) == "Line 5   "
      # Verify remaining space is filled with spaces
      assert String.ends_with?(get_line(result, 5), "   ")
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of line
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = BufferHandlers.handle_P(emulator, [])

      # Verify one character was deleted and content shifted left
      assert get_line(result, 5) == "Line 5 "
      # Verify remaining space is filled with a space
      assert String.ends_with?(get_line(result, 5), " ")
    end
  end

  describe "handle_at/2 (Insert Character)" do
    test "inserts specified number of spaces at cursor position", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of line
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = BufferHandlers.handle_at(emulator, [2])

      # Verify spaces were inserted and content shifted right
      assert get_line(result, 5) == "Line  5"
      # Verify content was shifted right
      assert String.starts_with?(get_line(result, 5), "Line  ")
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of line
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = BufferHandlers.handle_at(emulator, [])

      # Verify one space was inserted and content shifted right
      assert get_line(result, 5) == "Line 5"
      # Verify content was shifted right
      assert String.starts_with?(get_line(result, 5), "Line ")
    end
  end

  describe "handle_X/2 (Erase Character)" do
    test "erases specified number of characters at cursor position", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of line
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = BufferHandlers.handle_X(emulator, [2])

      # Verify characters were erased
      assert get_line(result, 5) == "Line 5"
      # Verify erased characters are replaced with spaces
      assert String.contains?(get_line(result, 5), "  ")
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of line
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = BufferHandlers.handle_X(emulator, [])

      # Verify one character was erased
      assert get_line(result, 5) == "Line 5"
      # Verify erased character is replaced with a space
      assert String.contains?(get_line(result, 5), " ")
    end
  end

  # Helper function to fill buffer with test data
  defp fill_buffer_with_test_data(emulator) do
    buffer = emulator.main_screen_buffer
    for y <- 0..9 do
      buffer = ScreenBuffer.write_string(buffer, 0, y, "Line #{y}")
    end
    %{emulator | main_screen_buffer: buffer}
  end

  # Helper function to get line content as string
  defp get_line(emulator, y) do
    buffer = emulator.main_screen_buffer
    for x <- 0..9 do
      ScreenBuffer.get_char(buffer, x, y)
    end
    |> Enum.join()
  end
end
