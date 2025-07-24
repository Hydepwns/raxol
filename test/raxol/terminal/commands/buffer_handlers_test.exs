defmodule Raxol.Terminal.Commands.BufferHandlersTest do
  use ExUnit.Case, async: false
  alias Raxol.Terminal.Commands.BufferHandlers
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ANSI.TextFormatting

  setup do
    emulator = Emulator.new(10, 10)
    {:ok, emulator: emulator}
  end

  describe "handle_L/2 (Insert Line)" do
    test "inserts specified number of lines at cursor position", %{
      emulator: emulator
    } do
      emulator = fill_buffer_with_test_data(emulator)
      CursorManager.set_position(emulator.cursor, {5, 0})

      result_emulator = unwrap_ok(BufferHandlers.handle_L(emulator, [2]))
      assert get_line_raw(result_emulator, 5) == ""
      assert get_line_raw(result_emulator, 6) == ""
      assert get_line_raw(result_emulator, 7) == "Line 5"
    end

    test "handles missing parameter", %{emulator: emulator} do
      emulator = fill_buffer_with_test_data(emulator)
      CursorManager.set_position(emulator.cursor, {5, 0})

      result_emulator = unwrap_ok(BufferHandlers.handle_L(emulator, []))
      assert get_line(result_emulator, 5) == ""
      assert get_line(result_emulator, 6) == "Line 5"
    end
  end

  describe "handle_M/2 (Delete Line)" do
    test "deletes specified number of lines at cursor position", %{
      emulator: emulator
    } do
      emulator = fill_buffer_with_test_data(emulator)
      CursorManager.set_position(emulator.cursor, {5, 0})

      result_emulator = unwrap_ok(BufferHandlers.handle_M(emulator, [2]))
      assert get_line(result_emulator, 5) == "Line 7"
      assert get_line(result_emulator, 6) == "Line 8"
      assert get_line(result_emulator, 8) == ""
      assert get_line(result_emulator, 9) == ""
    end

    test "handles missing parameter", %{emulator: emulator} do
      emulator = fill_buffer_with_test_data(emulator)
      CursorManager.set_position(emulator.cursor, {5, 0})

      result_emulator = unwrap_ok(BufferHandlers.handle_M(emulator, []))
      assert get_line(result_emulator, 5) == "Line 6"
      assert get_line(result_emulator, 9) == ""
    end
  end

  describe "handle_P/2 (Delete Character)" do
    test "deletes specified number of characters at cursor position", %{
      emulator: emulator
    } do
      line_content = "0123456789"
      emulator = set_line_chars(emulator, 5, line_content)
      CursorManager.set_position(emulator.cursor, {5, 5})

      result_emulator = unwrap_ok(BufferHandlers.handle_P(emulator, [2]))
      assert get_line_raw(result_emulator, 5) == "01234789  "
    end

    test "handles missing parameter (deletes 1 char)", %{emulator: emulator} do
      line_content = "0123456789"
      emulator = set_line_chars(emulator, 5, line_content)
      CursorManager.set_position(emulator.cursor, {5, 5})

      result_emulator = unwrap_ok(BufferHandlers.handle_P(emulator, []))
      assert get_line_raw(result_emulator, 5) == "012346789 "
    end
  end

  describe "handle_at/2 (Insert Character)" do
    test "inserts specified number of spaces at cursor position", %{
      emulator: emulator
    } do
      line_content = "0123456789"
      emulator = set_line_chars(emulator, 5, line_content)
      CursorManager.set_position(emulator.cursor, {5, 5})

      result_emulator = unwrap_ok(BufferHandlers.handle_at(emulator, [2]))

      assert get_line_raw(result_emulator, 5) == "01234  567"
    end

    test "handles missing parameter (inserts 1 space)", %{emulator: emulator} do
      line_content = "0123456789"
      emulator = set_line_chars(emulator, 5, line_content)
      CursorManager.set_position(emulator.cursor, {5, 5})

      result_emulator = unwrap_ok(BufferHandlers.handle_at(emulator, []))
      assert get_line_raw(result_emulator, 5) == "01234 5678"
    end
  end

  describe "handle_X/2 (Erase Character)" do
    test "erases specified number of characters at cursor position", %{
      emulator: emulator
    } do
      line_content = "0123456789"
      emulator = set_line_chars(emulator, 5, line_content)
      CursorManager.set_position(emulator.cursor, {5, 5})

      result_emulator = unwrap_ok(BufferHandlers.handle_X(emulator, [2]))
      assert get_line_raw(result_emulator, 5) == "01234  789"
    end

    test "handles missing parameter (erases 1 char)", %{emulator: emulator} do
      line_content = "0123456789"
      emulator = set_line_chars(emulator, 5, line_content)
      CursorManager.set_position(emulator.cursor, {5, 5})

      result_emulator = unwrap_ok(BufferHandlers.handle_X(emulator, []))
      assert get_line_raw(result_emulator, 5) == "01234 6789"
    end
  end

  defp fill_buffer_with_test_data(emulator) do
    buffer =
      Enum.reduce(0..9, emulator.main_screen_buffer, fn y, buffer ->
        ScreenBuffer.write_string(buffer, 0, y, "Line #{y}")
      end)

    %{emulator | main_screen_buffer: buffer}
  end

  defp get_line(emulator, y) do
    buffer = emulator.main_screen_buffer

    for x <- 0..9 do
      ScreenBuffer.get_char(buffer, x, y)
    end
    |> Enum.join()
    |> String.trim_trailing()
  end

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
            acc_buffer
          end
        end
      )

    %{emulator | main_screen_buffer: buffer}
  end

  defp get_line_raw(emulator, y) do
    buffer = emulator.main_screen_buffer
    line_cells = ScreenBuffer.get_line(buffer, y) || []
    Enum.map_join(line_cells, & &1.char)
  end

  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok({:error, _reason, value}), do: value
  defp unwrap_ok(value) when is_map(value), do: value
end
