defmodule Raxol.Terminal.Commands.CursorHandlerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Commands.CursorHandler
  alias Raxol.Terminal.Emulator

  setup do
    emulator = Emulator.new(10, 10)
    # Create a proper cursor map structure
    cursor = %{position: {0, 0}, row: 0, col: 0}
    emulator = %{emulator | cursor: cursor}
    {:ok, emulator: emulator}
  end

  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok(value) when is_map(value), do: value

  describe "handle_h/2 (Cursor Position)" do
    test "moves cursor to specified position", %{emulator: emulator} do
      result = unwrap_ok(CursorHandler.handle_h(emulator, [3, 2]))
      # {row, col} format
      assert result.cursor.position == {2, 1}
    end

    test "clamps coordinates to screen bounds", %{emulator: emulator} do
      result = unwrap_ok(CursorHandler.handle_h(emulator, [20, 20]))
      # {row, col} format
      assert result.cursor.position == {9, 9}
    end

    test "handles missing parameters", %{emulator: emulator} do
      result = unwrap_ok(CursorHandler.handle_h(emulator, []))
      # {row, col} format
      assert result.cursor.position == {0, 0}
    end
  end

  describe "handle_a/2 (Cursor Up)" do
    test "moves cursor up by specified amount", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_a(emulator, [2]))
      # {row, col} format
      assert result.cursor.position == {3, 5}
    end

    test "clamps to top of screen", %{emulator: emulator} do
      # Set cursor to position (1, 5) - {row, col} format
      updated_cursor = %{position: {1, 5}, row: 1, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_a(emulator, [5]))
      # {row, col} format
      assert result.cursor.position == {0, 5}
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_a(emulator, []))
      # {row, col} format
      assert result.cursor.position == {4, 5}
    end
  end

  describe "handle_b/2 (Cursor Down)" do
    test "moves cursor down by specified amount", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_b(emulator, [2]))
      # {row, col} format
      assert result.cursor.position == {7, 5}
    end

    test "clamps to bottom of screen", %{emulator: emulator} do
      # Set cursor to position (8, 5) - {row, col} format
      updated_cursor = %{position: {8, 5}, row: 8, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_b(emulator, [5]))
      # {row, col} format
      assert result.cursor.position == {9, 5}
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_b(emulator, []))
      # {row, col} format
      assert result.cursor.position == {6, 5}
    end
  end

  describe "handle_c/2 (Cursor Forward)" do
    test "moves cursor right by specified amount", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_c(emulator, [2]))
      # {row, col} format
      assert result.cursor.position == {5, 7}
    end

    test "clamps to right edge of screen", %{emulator: emulator} do
      # Set cursor to position (5, 8) - {row, col} format
      updated_cursor = %{position: {5, 8}, row: 5, col: 8}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_c(emulator, [5]))
      # {row, col} format
      assert result.cursor.position == {5, 9}
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_c(emulator, []))
      # {row, col} format
      assert result.cursor.position == {5, 6}
    end
  end

  describe "handle_d_cub/2 (Cursor Backward)" do
    test "moves cursor left by specified amount", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_d_cub(emulator, [2]))
      # {row, col} format
      assert result.cursor.position == {5, 3}
    end

    test "clamps to left edge of screen", %{emulator: emulator} do
      # Set cursor to position (5, 1) - {row, col} format
      updated_cursor = %{position: {5, 1}, row: 5, col: 1}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_d_cub(emulator, [5]))
      # {row, col} format
      assert result.cursor.position == {5, 0}
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_d_cub(emulator, []))
      # {row, col} format
      assert result.cursor.position == {5, 4}
    end
  end

  describe "handle_e/2 (Cursor Next Line)" do
    test "moves cursor to start of next line", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_e(emulator, [2]))
      # {row, col} format
      assert result.cursor.position == {7, 0}
    end

    test "clamps to bottom of screen", %{emulator: emulator} do
      # Set cursor to position (8, 5) - {row, col} format
      updated_cursor = %{position: {8, 5}, row: 8, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_e(emulator, [5]))
      # {row, col} format
      assert result.cursor.position == {9, 0}
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_e(emulator, []))
      # {row, col} format
      assert result.cursor.position == {6, 0}
    end
  end

  describe "handle_cpl/2 (Cursor Previous Line)" do
    test "moves cursor to start of previous line", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_cpl(emulator, [2]))
      # {row, col} format
      assert result.cursor.position == {3, 0}
    end

    test "clamps to top of screen", %{emulator: emulator} do
      # Start at position (1, 5) - {row, col} format
      updated_cursor = %{position: {1, 5}, row: 1, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_cpl(emulator, [5]))
      # {row, col} format
      assert result.cursor.position == {0, 0}
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_cpl(emulator, []))
      # {row, col} format
      assert result.cursor.position == {4, 0}
    end
  end

  describe "handle_cha/2 (Cursor Horizontal Absolute)" do
    test "moves cursor to specified column", %{emulator: emulator} do
      # Start at position (5, 5) - {row, col} format
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_cha(emulator, [3]))
      # {row, col} format
      assert result.cursor.position == {5, 2}
    end

    test "clamps to screen width", %{emulator: emulator} do
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_cha(emulator, [20]))
      # {row, col} format
      assert result.cursor.position == {5, 9}
    end

    test "handles missing parameter", %{emulator: emulator} do
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_cha(emulator, []))
      # {row, col} format
      assert result.cursor.position == {5, 0}
    end
  end

  describe "handle_d/2 (Cursor Vertical Absolute)" do
    test "moves cursor to specified row", %{emulator: emulator} do
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_d(emulator, [3]))
      assert result.cursor.position == {2, 5}
    end

    test "clamps to screen height", %{emulator: emulator} do
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_d(emulator, [20]))
      assert result.cursor.position == {9, 5}
    end

    test "handles missing parameter", %{emulator: emulator} do
      updated_cursor = %{position: {5, 5}, row: 5, col: 5}
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_d(emulator, []))
      assert result.cursor.position == {0, 5}
    end
  end
end
