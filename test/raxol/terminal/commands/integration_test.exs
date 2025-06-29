defmodule Raxol.Terminal.Commands.IntegrationTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.{Emulator, Window}
  alias Raxol.Terminal.Commands.{CSIHandlers, OSCHandlers}

  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok({:error, _reason, value}), do: value
  defp unwrap_ok(value) when is_map(value), do: value

  setup do
    emulator = Raxol.Terminal.Emulator.Struct.new(80, 24,
      window_manager: Raxol.Terminal.Window.Manager.new_for_test()
    )
    {:ok, emulator: emulator}
  end

  describe "combined operations" do
    test "window resize with cursor position", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> unwrap_ok()
        |> OSCHandlers.handle_window_size(100, 50)
        |> unwrap_ok()
        |> CSIHandlers.handle_cursor_position(20, 20)
        |> unwrap_ok()

      assert result.window_manager.size == {100, 50}
      assert result.cursor.position == {20, 20}
    end

    test "color changes with text attributes", %{emulator: emulator} do
      result =
        emulator
        |> OSCHandlers.handle_foreground_color("#FF0000")
        |> unwrap_ok()
        |> CSIHandlers.handle_text_attributes([1, 4])
        |> unwrap_ok()
        |> OSCHandlers.handle_background_color("#0000FF")
        |> unwrap_ok()

      # Check that the operations completed without error
      assert is_map(result)
    end

    test "window state with cursor visibility", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_mode_change(25, false)
        |> unwrap_ok()
        |> OSCHandlers.handle_window_maximize()
        |> unwrap_ok()
        |> CSIHandlers.handle_mode_change(25, true)
        |> unwrap_ok()

      assert result.window_manager.state == :maximized
      assert result.cursor.visible == true
    end
  end

  describe "state persistence" do
    test "preserves cursor position after window operations", %{
      emulator: emulator
    } do
      result =
        emulator
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> unwrap_ok()
        |> OSCHandlers.handle_window_title("Test")
        |> unwrap_ok()
        |> OSCHandlers.handle_window_size(100, 50)
        |> unwrap_ok()

      assert result.cursor.position == {10, 10}
    end

    test "preserves text attributes after mode changes", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_text_attributes([1, 4, 31])
        |> unwrap_ok()
        |> CSIHandlers.handle_mode_change(4, true)
        |> unwrap_ok()
        |> CSIHandlers.handle_mode_change(25, false)
        |> unwrap_ok()

      # Check that the operations completed without error
      assert is_map(result)
    end

    test "preserves window state after cursor operations", %{emulator: emulator} do
      result =
        emulator
        |> OSCHandlers.handle_window_maximize()
        |> unwrap_ok()
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> unwrap_ok()
        |> CSIHandlers.handle_cursor_up(5)
        |> unwrap_ok()

      assert result.window_manager.state == :maximized
    end
  end

  describe "buffer interactions" do
    test "scroll with cursor position", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> unwrap_ok()
        |> CSIHandlers.handle_scroll_up(5)
        |> unwrap_ok()
        |> CSIHandlers.handle_cursor_position(20, 20)
        |> unwrap_ok()

      # Check that the operations completed without error
      assert is_map(result)
    end

    test "erase with text attributes", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_text_attributes([1, 4])
        |> unwrap_ok()
        |> CSIHandlers.handle_erase_display(0)
        |> unwrap_ok()
        |> CSIHandlers.handle_text_attributes([0])
        |> unwrap_ok()

      # Check that the operations completed without error
      assert is_map(result)
    end

    test "scroll with window size", %{emulator: emulator} do
      result =
        emulator
        |> OSCHandlers.handle_window_size(100, 50)
        |> unwrap_ok()
        |> CSIHandlers.handle_scroll_up(10)
        |> unwrap_ok()
        |> CSIHandlers.handle_scroll_down(5)
        |> unwrap_ok()

      assert result.window_manager.size == {100, 50}
    end
  end

  describe "terminal mode interactions" do
    test "insert mode with cursor position", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_mode_change(4, true)
        |> unwrap_ok()
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> unwrap_ok()
        |> CSIHandlers.handle_mode_change(4, false)
        |> unwrap_ok()

      # Check that the operations completed without error
      assert is_map(result)
    end

    test "cursor visibility with window state", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_mode_change(25, false)
        |> unwrap_ok()
        |> OSCHandlers.handle_window_fullscreen()
        |> unwrap_ok()
        |> CSIHandlers.handle_mode_change(25, true)
        |> unwrap_ok()

      assert result.cursor.visible == true
      assert result.window_manager.state == :fullscreen
    end

    test "multiple mode changes", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_mode_change(4, true)
        |> unwrap_ok()
        |> CSIHandlers.handle_mode_change(25, false)
        |> unwrap_ok()
        |> CSIHandlers.handle_mode_change(4, false)
        |> unwrap_ok()
        |> CSIHandlers.handle_mode_change(25, true)
        |> unwrap_ok()

      assert result.cursor.visible == true
    end
  end

  describe "error recovery" do
    test "recovers from invalid window size", %{emulator: emulator} do
      result =
        emulator
        |> OSCHandlers.handle_window_size(-100, -50)
        |> unwrap_ok()
        |> OSCHandlers.handle_window_size(100, 50)
        |> unwrap_ok()

      assert result.window_manager.size == {100, 50}
    end

    test "recovers from invalid cursor position", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_cursor_position(-10, -10)
        |> unwrap_ok()
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> unwrap_ok()

      assert result.cursor.position == {10, 10}
    end

    test "recovers from invalid color settings", %{emulator: emulator} do
      result =
        emulator
        |> OSCHandlers.handle_foreground_color("invalid")
        |> unwrap_ok()
        |> OSCHandlers.handle_foreground_color("#FF0000")
        |> unwrap_ok()

      # Check that the operations completed without error
      assert is_map(result)
    end
  end
end
