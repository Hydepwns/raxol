defmodule Raxol.Terminal.Commands.CursorHandlerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Commands.CursorHandler
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager

  setup do
    emulator = Emulator.new(10, 10)
    {:ok, emulator: emulator}
  end

  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok(value) when is_map(value), do: value

  describe "handle_H/2 (Cursor Position)" do
    test "moves cursor to specified position", %{emulator: emulator} do
      result = unwrap_ok(CursorHandler.handle_H(emulator, [3, 2]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {2, 1}
    end

    test "clamps coordinates to screen bounds", %{emulator: emulator} do
      result = unwrap_ok(CursorHandler.handle_H(emulator, [20, 20]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {9, 9}
    end

    test "handles missing parameters", %{emulator: emulator} do
      result = unwrap_ok(CursorHandler.handle_H(emulator, []))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {0, 0}
    end
  end

  describe "handle_A/2 (Cursor Up)" do
    test "moves cursor up by specified amount", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_A(emulator, [2]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {3, 5}
    end

    test "clamps to top of screen", %{emulator: emulator} do
      # Set cursor to position (1, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {1, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_A(emulator, [5]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {0, 5}
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_A(emulator, []))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {4, 5}
    end
  end

  describe "handle_B/2 (Cursor Down)" do
    test "moves cursor down by specified amount", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_B(emulator, [2]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {7, 5}
    end

    test "clamps to bottom of screen", %{emulator: emulator} do
      # Set cursor to position (8, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {8, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_B(emulator, [5]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {9, 5}
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_B(emulator, []))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {6, 5}
    end
  end

  describe "handle_C/2 (Cursor Forward)" do
    test "moves cursor right by specified amount", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_C(emulator, [2]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {5, 7}
    end

    test "clamps to right edge of screen", %{emulator: emulator} do
      # Set cursor to position (5, 8) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 8})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_C(emulator, [5]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {5, 9}
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_C(emulator, []))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {5, 6}
    end
  end

  describe "handle_D/2 (Cursor Backward)" do
    test "moves cursor left by specified amount", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_D(emulator, [2]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {5, 3}
    end

    test "clamps to left edge of screen", %{emulator: emulator} do
      # Set cursor to position (5, 1) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 1})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_D(emulator, [5]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {5, 0}
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_D(emulator, []))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {5, 4}
    end
  end

  describe "handle_E/2 (Cursor Next Line)" do
    test "moves cursor to start of next line", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_E(emulator, [2]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {7, 0}
    end

    test "clamps to bottom of screen", %{emulator: emulator} do
      # Set cursor to position (8, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {8, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_E(emulator, [5]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {9, 0}
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_E(emulator, []))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {6, 0}
    end
  end

  describe "handle_F/2 (Cursor Previous Line)" do
    test "moves cursor to start of previous line", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_F(emulator, [2]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {3, 0}
    end

    test "clamps to top of screen", %{emulator: emulator} do
      # Start at position (1, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {1, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_F(emulator, [5]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {0, 0}
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Set cursor to position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_F(emulator, []))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {4, 0}
    end
  end

  describe "handle_G/2 (Cursor Horizontal Absolute)" do
    test "moves cursor to specified column", %{emulator: emulator} do
      # Start at position (5, 5) - {row, col} format
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_G(emulator, [3]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {5, 2}
    end

    test "clamps to screen width", %{emulator: emulator} do
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_G(emulator, [20]))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {5, 9}
    end

    test "handles missing parameter", %{emulator: emulator} do
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_G(emulator, []))
      # {row, col} format
      assert CursorManager.get_position(result.cursor) == {5, 0}
    end
  end

  describe "handle_d/2 (Cursor Vertical Absolute)" do
    test "moves cursor to specified row", %{emulator: emulator} do
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_d(emulator, [3]))
      assert CursorManager.get_position(result.cursor) == {2, 5}
    end

    test "clamps to screen height", %{emulator: emulator} do
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_d(emulator, [20]))
      assert CursorManager.get_position(result.cursor) == {9, 5}
    end

    test "handles missing parameter", %{emulator: emulator} do
      updated_cursor = CursorManager.set_position(emulator.cursor, {5, 5})
      emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(CursorHandler.handle_d(emulator, []))
      assert CursorManager.get_position(result.cursor) == {0, 5}
    end
  end
end
