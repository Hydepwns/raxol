defmodule Raxol.Terminal.Commands.EraseHandlersTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Commands.EraseHandlers
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ANSI.TextFormatting

  setup do
    # Create a test emulator with a 10x10 screen using the proper constructor
    emulator = Emulator.new(10, 10)
    # Optionally, reset the buffers and cursor if needed
    emulator = %{
      emulator
      | main_screen_buffer: ScreenBuffer.new(10, 10),
        alternate_screen_buffer: ScreenBuffer.new(10, 10),
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

      result = unwrap_ok(EraseHandlers.handle_J(emulator, [0]))

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

    test "erases from beginning of screen to cursor (mode 1)", %{
      emulator: emulator
    } do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of screen
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = unwrap_ok(EraseHandlers.handle_J(emulator, [1]))

      # Verify content before cursor is erased
      for y <- 0..4 do
        for x <- 0..9 do
          assert ScreenBuffer.get_char(result.main_screen_buffer, x, y) == " "
        end
      end

      # Verify content from cursor to end is preserved
      for y <- 5..9 do
        start_x = if y == 5, do: 6, else: 0

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

      result = unwrap_ok(EraseHandlers.handle_J(emulator, [2]))

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

      result = unwrap_ok(EraseHandlers.handle_J(emulator, []))

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

    test "erases scrollback buffer (mode 3)", %{emulator: emulator} do
      # Setup a buffer with a smaller height and scrollback limit for easier testing
      # width 10, height 3, scrollback_limit 2
      small_buffer = ScreenBuffer.new(10, 3, 2)

      emulator = %{
        emulator
        | main_screen_buffer: small_buffer,
          cursor: CursorManager.new(position: {0, 0})
      }

      # Fill the small buffer with initial content (3 lines)
      line0_content = Enum.map(0..9, &"A#{&1}")
      line1_content = Enum.map(0..9, &"B#{&1}")
      line2_content = Enum.map(0..9, &"C#{&1}")

      emulator = set_line_content(emulator, 0, line0_content)
      emulator = set_line_content(emulator, 1, line1_content)
      emulator = set_line_content(emulator, 2, line2_content)

      # Scroll up by 2 lines. This should move A and B lines to scrollback.
      # Viewport should become: C, blank, blank.
      # Scrollback should become: [lineB_data, lineA_data] (newest first)
      emulator_after_scroll =
        Raxol.Terminal.Commands.Screen.scroll_up(emulator, 2)

      # Verify scrollback content before erase
      # lineA_data and lineB_data are {char, style} tuples
      # We expect scrolled_off_lines to be [[A0_cell, A1_cell...], [B0_cell, B1_cell...]]
      # These become the scrollback, newest first. Limit is 2.
      assert length(emulator_after_scroll.main_screen_buffer.scrollback) == 2

      first_scrollback_line_chars =
        Enum.map(
          hd(emulator_after_scroll.main_screen_buffer.scrollback),
          & &1.char
        )

      second_scrollback_line_chars =
        Enum.map(
          hd(tl(emulator_after_scroll.main_screen_buffer.scrollback)),
          & &1.char
        )

      # After scroll_up, the lines scrolled off are line0_content and line1_content.
      # `scrolled_off_lines ++ current_scrollback` means [line0_cells, line1_cells] ++ []
      # So scrollback is [line0_cells, line1_cells]
      assert first_scrollback_line_chars == line0_content
      assert second_scrollback_line_chars == line1_content

      # Verify viewport content after scroll (C, blank, blank)
      assert get_line_chars(emulator_after_scroll, 0) == line2_content
      assert get_line_chars(emulator_after_scroll, 1) == List.duplicate(" ", 10)
      assert get_line_chars(emulator_after_scroll, 2) == List.duplicate(" ", 10)

      # Call Erase in Display with mode 3 (erase scrollback)
      result_emulator =
        unwrap_ok(EraseHandlers.handle_J(emulator_after_scroll, [3]))

      # Verify scrollback is cleared
      assert result_emulator.main_screen_buffer.scrollback == []

      # Verify viewport content is preserved
      assert get_line_chars(result_emulator, 0) == line2_content
      assert get_line_chars(result_emulator, 1) == List.duplicate(" ", 10)
      assert get_line_chars(result_emulator, 2) == List.duplicate(" ", 10)
    end
  end

  describe "handle_K/2 (Erase in Line)" do
    test "erases from cursor to end of line (mode 0)", %{emulator: emulator} do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of line
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = unwrap_ok(EraseHandlers.handle_K(emulator, [0]))

      # Verify content before cursor is preserved
      for x <- 0..4 do
        assert ScreenBuffer.get_char(result.main_screen_buffer, x, 5) == "X"
      end

      # Verify content from cursor to end of line is erased
      for x <- 5..9 do
        assert ScreenBuffer.get_char(result.main_screen_buffer, x, 5) == " "
      end
    end

    test "erases from beginning of line to cursor (mode 1)", %{
      emulator: emulator
    } do
      # Fill buffer with test data
      emulator = fill_buffer_with_test_data(emulator)
      # Move cursor to middle of line
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      result = unwrap_ok(EraseHandlers.handle_K(emulator, [1]))

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

      result = unwrap_ok(EraseHandlers.handle_K(emulator, [2]))

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

      result = unwrap_ok(EraseHandlers.handle_K(emulator, []))

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
    buffer =
      Enum.reduce(0..9, emulator.main_screen_buffer, fn y, buffer ->
        Enum.reduce(0..9, buffer, fn x, buffer ->
          ScreenBuffer.write_char(buffer, x, y, "X", TextFormatting.new())
        end)
      end)

    %{emulator | main_screen_buffer: buffer}
  end

  defp set_line_content(emulator, line_idx, chars) do
    buffer =
      Enum.reduce(
        Enum.with_index(chars),
        emulator.main_screen_buffer,
        fn {char_val, char_idx}, acc_buffer ->
          ScreenBuffer.write_char(
            acc_buffer,
            char_idx,
            line_idx,
            char_val,
            TextFormatting.new()
          )
        end
      )

    %{emulator | main_screen_buffer: buffer}
  end

  defp get_line_chars(emulator, line_idx) do
    line_cells = ScreenBuffer.get_line(emulator.main_screen_buffer, line_idx)
    Enum.map(line_cells, & &1.char)
  end

  # Add a helper at the top of the file for unwrapping handler results
  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok({:error, _reason, value}), do: value
  defp unwrap_ok(value) when is_map(value), do: value
end
