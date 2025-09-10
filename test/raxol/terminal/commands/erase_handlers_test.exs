defmodule Raxol.Terminal.Commands.EraseHandlerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.EraseHandler, as: EraseHandlers

  setup do
    emulator = Emulator.new(80, 24, [])
    {:ok, emulator: emulator}
  end


  describe "handle_erase/4 (Erase in Display)" do
    test "erases from cursor to end of screen (mode 0)", %{emulator: emulator} do
      # Set cursor to middle of screen
      updated_cursor = Raxol.Terminal.Cursor.Manager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}

      # Fill screen with content
      emulator = fill_screen_with_content(emulator, "X")

      {:ok, updated_emulator} =
        EraseHandlers.handle_erase(emulator, :screen, 0, {5, 5})

      # Check that content from cursor to end is erased
      # Before cursor should remain
      assert_cell_at(updated_emulator, 4, 5, "X")
      # Cursor position should be erased
      assert_cell_at(updated_emulator, 5, 5, " ")
      # End should be erased
      assert_cell_at(updated_emulator, 79, 23, " ")
    end

    test "erases from beginning of screen to cursor (mode 1)", %{
      emulator: emulator
    } do
      # Set cursor to middle of screen
      updated_cursor = Raxol.Terminal.Cursor.Manager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}

      # Fill screen with content
      emulator = fill_screen_with_content(emulator, "X")

      {:ok, updated_emulator} =
        EraseHandlers.handle_erase(emulator, :screen, 1, {5, 5})

      # Check that content from beginning to cursor is erased
      # Beginning should be erased
      assert_cell_at(updated_emulator, 0, 0, " ")
      # Cursor position should be erased
      assert_cell_at(updated_emulator, 5, 5, " ")
      # After cursor should remain
      assert_cell_at(updated_emulator, 6, 6, "X")
    end

    test "erases entire screen (mode 2)", %{emulator: emulator} do
      # Fill screen with content
      emulator = fill_screen_with_content(emulator, "X")

      {:ok, updated_emulator} =
        EraseHandlers.handle_erase(emulator, :screen, 2, {5, 5})

      # Check that entire screen is erased
      assert_cell_at(updated_emulator, 0, 0, " ")
      assert_cell_at(updated_emulator, 39, 11, " ")
      assert_cell_at(updated_emulator, 79, 23, " ")
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Fill screen with content
      emulator = fill_screen_with_content(emulator, "X")

      {:ok, updated_emulator} =
        EraseHandlers.handle_erase(emulator, :screen, 0, {5, 5})

      # Should default to mode 0 (erase from cursor to end)
      # Since cursor is at {0,0}, cursor position should be erased
      assert_cell_at(updated_emulator, 0, 0, " ")
      # End should be erased
      assert_cell_at(updated_emulator, 79, 23, " ")
    end

    test "erases scrollback buffer (mode 3)", %{emulator: emulator} do
      # Fill screen and scroll to create scrollback
      emulator = fill_screen_with_content(emulator, "X")
      emulator = scroll_up(emulator, 5)

      {:ok, updated_emulator} =
        EraseHandlers.handle_erase(emulator, :screen, 3, {0, 0})

      # Scrollback should be cleared
      assert scrollback_is_empty(updated_emulator)
    end
  end

  describe "handle_erase/4 (Erase in Line)" do
    test "erases from cursor to end of line (mode 0)", %{emulator: emulator} do
      # Set cursor to middle of line (row 0, column 5)
      updated_cursor = Raxol.Terminal.Cursor.Manager.set_position(emulator.cursor, {0, 5})
      emulator = %{emulator | cursor: updated_cursor}

      # Fill line with content
      emulator = fill_line_with_content(emulator, 0, "X")

      {:ok, updated_emulator} =
        EraseHandlers.handle_erase(emulator, :line, 0, {5, 10})

      # Check that content from cursor to end of line is erased
      # Before cursor should remain
      assert_cell_at(updated_emulator, 4, 0, "X")
      # Cursor position should be erased
      assert_cell_at(updated_emulator, 5, 0, " ")
      # End of line should be erased
      assert_cell_at(updated_emulator, 79, 0, " ")
    end

    test "erases from beginning of line to cursor (mode 1)", %{
      emulator: emulator
    } do
      # Set cursor to middle of line (row 0, column 5)
      updated_cursor = Raxol.Terminal.Cursor.Manager.set_position(emulator.cursor, {0, 5})
      emulator = %{emulator | cursor: updated_cursor}

      # Fill line with content
      emulator = fill_line_with_content(emulator, 0, "X")

      {:ok, updated_emulator} =
        EraseHandlers.handle_erase(emulator, :line, 1, {5, 10})

      # Check that content from beginning to cursor is erased
      # Beginning should be erased
      assert_cell_at(updated_emulator, 0, 0, " ")
      # Cursor position should be erased
      assert_cell_at(updated_emulator, 5, 0, " ")
      # After cursor should remain
      assert_cell_at(updated_emulator, 6, 0, "X")
    end

    test "erases entire line (mode 2)", %{emulator: emulator} do
      # Fill line with content
      emulator = fill_line_with_content(emulator, 0, "X")

      {:ok, updated_emulator} =
        EraseHandlers.handle_erase(emulator, :line, 2, {5, 10})

      # Check that entire line is erased
      assert_cell_at(updated_emulator, 0, 0, " ")
      assert_cell_at(updated_emulator, 39, 0, " ")
      assert_cell_at(updated_emulator, 79, 0, " ")
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Fill line with content
      emulator = fill_line_with_content(emulator, 0, "X")

      {:ok, updated_emulator} =
        EraseHandlers.handle_erase(emulator, :line, 0, {5, 10})

      # Should default to mode 0 (erase from cursor to end of line)
      # Since cursor is at {0,0}, cursor position should be erased
      assert_cell_at(updated_emulator, 0, 0, " ")
      # End should be erased
      assert_cell_at(updated_emulator, 79, 0, " ")
    end
  end

  # Helper functions
  defp fill_screen_with_content(emulator, char) do
    # Get the active buffer from the emulator
    buffer = get_screen_buffer(emulator)

    # Fill the entire screen with the specified character
    filled_buffer =
      Enum.reduce(0..(buffer.height - 1), buffer, fn y, acc_buffer ->
        Enum.reduce(0..(buffer.width - 1), acc_buffer, fn x, acc ->
          Raxol.Terminal.ScreenBuffer.write_char(acc, x, y, char)
        end)
      end)

    # Update the emulator with the filled buffer
    update_active_buffer(emulator, filled_buffer)
  end

  defp fill_line_with_content(emulator, line, char) do
    # Get the active buffer from the emulator
    buffer = get_screen_buffer(emulator)

    # Fill the specified line with the character
    filled_buffer =
      Enum.reduce(0..(buffer.width - 1), buffer, fn x, acc ->
        Raxol.Terminal.ScreenBuffer.write_char(acc, x, line, char)
      end)

    # Update the emulator with the filled buffer
    update_active_buffer(emulator, filled_buffer)
  end

  defp scroll_up(emulator, lines) do
    # Get the active buffer from the emulator
    buffer = get_screen_buffer(emulator)

    # Scroll the buffer up by the specified number of lines
    {scrolled_buffer, _scrolled_lines} =
      Raxol.Terminal.ScreenBuffer.scroll_up(buffer, lines)

    # Update the emulator with the scrolled buffer
    update_active_buffer(emulator, scrolled_buffer)
  end

  defp scrollback_is_empty(emulator) do
    # Get the active buffer from the emulator
    buffer = get_screen_buffer(emulator)

    # Check if the scrollback buffer is empty
    buffer.scrollback == []
  end

  defp assert_cell_at(emulator, x, y, expected_char) do
    # Get the active buffer from the emulator
    buffer = get_screen_buffer(emulator)

    # Get the character at the specified position
    actual_char = Raxol.Terminal.ScreenBuffer.get_char(buffer, x, y)

    # Assert that the character matches the expected value
    assert actual_char == expected_char,
           "Expected character '#{expected_char}' at position (#{x}, #{y}), but got '#{actual_char}'"
  end

  # Helper functions to get and update the active buffer
  defp get_screen_buffer(emulator) do
    case emulator.active_buffer_type do
      :main -> emulator.main_screen_buffer
      :alternate -> emulator.alternate_screen_buffer
      _ -> emulator.main_screen_buffer
    end
  end

  defp update_active_buffer(emulator, new_buffer) do
    case emulator.active_buffer_type do
      :main -> %{emulator | main_screen_buffer: new_buffer}
      :alternate -> %{emulator | alternate_screen_buffer: new_buffer}
      _ -> %{emulator | main_screen_buffer: new_buffer}
    end
  end
end
