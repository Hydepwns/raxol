defmodule Raxol.Terminal.Commands.BufferHandlersTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Commands.BufferHandlers
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ANSI.TextFormatting

  setup do
    # Create a test emulator with a 10x10 screen using the proper constructor
    emulator = Emulator.new(10, 10)
    {:ok, emulator: emulator}
  end

  describe "handle_L/2 (Insert Line)" do
    test "inserts specified number of lines at cursor position", %{
      emulator: emulator
    } do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {0, 5}}}

      {:ok, result} = BufferHandlers.handle_L(emulator, [2])

      # Verify lines were inserted
      assert get_line(result, 5) == ""
      assert get_line(result, 6) == ""
      # Verify original content was shifted down
      assert get_line(result, 7) == "Line 5"
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {0, 5}}}

      {:ok, result} = BufferHandlers.handle_L(emulator, [])

      # Verify one line was inserted
      assert get_line(result, 5) == ""
      # Verify original content was shifted down
      assert get_line(result, 6) == "Line 5"
    end
  end

  describe "handle_M/2 (Delete Line)" do
    test "deletes specified number of lines at cursor position", %{
      emulator: emulator
    } do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {0, 5}}}

      {:ok, result} = BufferHandlers.handle_M(emulator, [2])

      # Verify lines were deleted and content shifted up
      assert get_line(result, 5) == "Line 7"
      assert get_line(result, 6) == "Line 8"
      # Verify bottom lines are cleared
      assert get_line(result, 8) == ""
      assert get_line(result, 9) == ""
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {0, 5}}}

      {:ok, result} = BufferHandlers.handle_M(emulator, [])

      # Verify one line was deleted and content shifted up
      assert get_line(result, 5) == "Line 6"
      # Verify bottom line is cleared
      assert get_line(result, 9) == ""
    end
  end

  describe "handle_P/2 (Delete Character)" do
    test "deletes specified number of characters at cursor position", %{
      emulator: emulator
    } do
      # Set specific line content for this test
      line_content = "0123456789"
      emulator = set_line_chars(emulator, 5, line_content)
      # Cursor on '5'
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      {:ok, result_emulator} = BufferHandlers.handle_P(emulator, [2])
      # Expected: "01234789  " (01234 shifted_789 padding_spaces)
      assert get_line_raw(result_emulator, 5) == "01234789  "
    end

    test "handles missing parameter (deletes 1 char)", %{emulator: emulator} do
      line_content = "0123456789"
      emulator = set_line_chars(emulator, 5, line_content)
      # Cursor on '5'
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      {:ok, result_emulator} = BufferHandlers.handle_P(emulator, [])
      # Expected: "012346789 " (01234 shifted_6789 padding_space)
      assert get_line_raw(result_emulator, 5) == "012346789 "
    end
  end

  describe "handle_at/2 (Insert Character)" do
    test "inserts specified number of spaces at cursor position", %{
      emulator: emulator
    } do
      # Set specific line content for this test
      line_content = "0123456789"
      emulator = set_line_chars(emulator, 5, line_content)
      # Cursor on '5'
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      {:ok, result_emulator} = BufferHandlers.handle_at(emulator, [2])

      # Expected: "01234  567" (01234 two_spaces original_567, '89' are truncated due to width 10)
      assert get_line_raw(result_emulator, 5) == "01234  567"
    end

    test "handles missing parameter (inserts 1 space)", %{emulator: emulator} do
      line_content = "0123456789"
      emulator = set_line_chars(emulator, 5, line_content)
      # Cursor on '5'
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      {:ok, result_emulator} = BufferHandlers.handle_at(emulator, [])
      # Expected: "01234 5678" (01234 one_space original_5678, '9' is truncated)
      assert get_line_raw(result_emulator, 5) == "01234 5678"
    end
  end

  describe "handle_X/2 (Erase Character)" do
    test "erases specified number of characters at cursor position", %{
      emulator: emulator
    } do
      # Set specific line content for this test
      line_content = "0123456789"
      emulator = set_line_chars(emulator, 5, line_content)
      # Cursor on '5'
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      {:ok, result_emulator} = BufferHandlers.handle_X(emulator, [2])
      # Expected: "01234  789" (01234 two_spaces 789)
      assert get_line_raw(result_emulator, 5) == "01234  789"
    end

    test "handles missing parameter (erases 1 char)", %{emulator: emulator} do
      line_content = "0123456789"
      emulator = set_line_chars(emulator, 5, line_content)
      # Cursor on '5'
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      {:ok, result_emulator} = BufferHandlers.handle_X(emulator, [])
      # Expected: "01234 6789" (01234 one_space 6789)
      assert get_line_raw(result_emulator, 5) == "01234 6789"
    end
  end

  # Helper function to fill buffer with test data
  defp fill_buffer_with_test_data(emulator) do
    buffer =
      Enum.reduce(0..9, emulator.main_screen_buffer, fn y, buffer ->
        ScreenBuffer.write_string(buffer, 0, y, "Line #{y}")
      end)

    %{emulator | main_screen_buffer: buffer}
  end

  # Helper function to get line content as string
  defp get_line(emulator, y) do
    buffer = emulator.main_screen_buffer

    for x <- 0..9 do
      ScreenBuffer.get_char(buffer, x, y)
    end
    |> Enum.join()
    |> String.trim_trailing()
  end

  # Helper to set specific chars on a line
  defp set_line_chars(emulator, line_y, string_content) do
    chars = String.graphemes(string_content)

    buffer =
      Enum.reduce(
        Enum.with_index(chars),
        emulator.main_screen_buffer,
        fn {char_val, char_idx}, acc_buffer ->
          if char_idx < ScreenBuffer.get_width(acc_buffer) do
            ScreenBuffer.write_char(
              acc_buffer,
              char_idx,
              line_y,
              char_val,
              TextFormatting.new()
            )
          else
            # Ignore chars beyond buffer width
            acc_buffer
          end
        end
      )

    %{emulator | main_screen_buffer: buffer}
  end

  # Helper to get raw line content as string, without trimming
  defp get_line_raw(emulator, y) do
    buffer = emulator.main_screen_buffer
    line_cells = ScreenBuffer.get_line(buffer, y) || []
    Enum.map_join(line_cells, & &1.char)
  end
end
