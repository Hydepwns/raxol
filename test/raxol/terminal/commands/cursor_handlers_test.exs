defmodule Raxol.Terminal.Commands.CursorHandlersTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Commands.CursorHandlers
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager

  setup do
    emulator = Emulator.new(10, 10)
    {:ok, emulator: emulator}
  end

  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok({:error, _reason, value}), do: value
  defp unwrap_ok(value) when is_map(value), do: value

  describe "handle_H/2 (Cursor Position)" do
    test "moves cursor to specified position", %{emulator: emulator} do
      result = unwrap_ok(CursorHandlers.handle_H(emulator, [3, 4]))
      assert result.cursor.position == {3, 2}
    end

    test "clamps coordinates to screen bounds", %{emulator: emulator} do
      result = unwrap_ok(CursorHandlers.handle_H(emulator, [20, 20]))
      assert result.cursor.position == {9, 9}
    end

    test "handles missing parameters", %{emulator: emulator} do
      result = unwrap_ok(CursorHandlers.handle_H(emulator, []))
      assert result.cursor.position == {0, 0}
    end
  end

  describe "handle_A/2 (Cursor Up)" do
    test "moves cursor up by specified amount", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_A(emulator, [2]))
      assert result.cursor.position == {5, 3}
    end

    test "clamps to top of screen", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 1}}}
      result = unwrap_ok(CursorHandlers.handle_A(emulator, [5]))
      assert result.cursor.position == {5, 0}
    end

    test "handles missing parameter", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_A(emulator, []))
      assert result.cursor.position == {5, 4}
    end
  end

  describe "handle_B/2 (Cursor Down)" do
    test "moves cursor down by specified amount", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_B(emulator, [2]))
      assert result.cursor.position == {5, 7}
    end

    test "clamps to bottom of screen", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 8}}}
      result = unwrap_ok(CursorHandlers.handle_B(emulator, [5]))
      assert result.cursor.position == {5, 9}
    end

    test "handles missing parameter", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_B(emulator, []))
      assert result.cursor.position == {5, 6}
    end
  end

  describe "handle_C/2 (Cursor Forward)" do
    test "moves cursor right by specified amount", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_C(emulator, [2]))
      assert result.cursor.position == {7, 5}
    end

    test "clamps to right edge of screen", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {8, 5}}}
      result = unwrap_ok(CursorHandlers.handle_C(emulator, [5]))
      assert result.cursor.position == {9, 5}
    end

    test "handles missing parameter", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_C(emulator, []))
      assert result.cursor.position == {6, 5}
    end
  end

  describe "handle_D/2 (Cursor Backward)" do
    test "moves cursor left by specified amount", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_D(emulator, [2]))
      assert result.cursor.position == {3, 5}
    end

    test "clamps to left edge of screen", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {1, 5}}}
      result = unwrap_ok(CursorHandlers.handle_D(emulator, [5]))
      assert result.cursor.position == {0, 5}
    end

    test "handles missing parameter", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_D(emulator, []))
      assert result.cursor.position == {4, 5}
    end
  end

  describe "handle_E/2 (Cursor Next Line)" do
    test "moves cursor to start of next line", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_E(emulator, [2]))
      assert result.cursor.position == {0, 7}
    end

    test "clamps to bottom of screen", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 8}}}
      result = unwrap_ok(CursorHandlers.handle_E(emulator, [5]))
      assert result.cursor.position == {0, 9}
    end

    test "handles missing parameter", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_E(emulator, []))
      assert result.cursor.position == {0, 6}
    end
  end

  describe "handle_F/2 (Cursor Previous Line)" do
    test "moves cursor to start of previous line", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_F(emulator, [2]))
      assert result.cursor.position == {0, 3}
    end

    test "clamps to top of screen", %{emulator: emulator} do
      # Start at position (5,1)
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 1}}}
      result = unwrap_ok(CursorHandlers.handle_F(emulator, [5]))
      assert result.cursor.position == {0, 0}
    end

    test "handles missing parameter", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_F(emulator, []))
      assert result.cursor.position == {0, 4}
    end
  end

  describe "handle_G/2 (Cursor Horizontal Absolute)" do
    test "moves cursor to specified column", %{emulator: emulator} do
      # Start at position (5,5)
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_G(emulator, [3]))
      assert result.cursor.position == {2, 5}
    end

    test "clamps to screen width", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_G(emulator, [20]))
      assert result.cursor.position == {9, 5}
    end

    test "handles missing parameter", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_G(emulator, []))
      assert result.cursor.position == {0, 5}
    end
  end

  describe "handle_d/2 (Cursor Vertical Absolute)" do
    test "moves cursor to specified row", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_d(emulator, [3]))
      assert result.cursor.position == {5, 2}
    end

    test "clamps to screen height", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_d(emulator, [20]))
      assert result.cursor.position == {5, 9}
    end

    test "handles missing parameter", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = unwrap_ok(CursorHandlers.handle_d(emulator, []))
      assert result.cursor.position == {5, 0}
    end
  end
end
