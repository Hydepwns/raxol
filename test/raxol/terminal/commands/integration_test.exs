defmodule Raxol.Terminal.Commands.IntegrationTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.{Emulator, Window}
  alias Raxol.Terminal.Commands.{CSIHandlers, OSCHandlers}

  setup do
    emulator = Emulator.new()
    {:ok, emulator: emulator}
  end

  describe "combined operations" do
    test "window resize with cursor position", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> OSCHandlers.handle_window_size(100, 50)
        |> CSIHandlers.handle_cursor_position(20, 20)

      assert result.window_manager.size == {100, 50}
      assert result.cursor == %{x: 20, y: 20}
    end

    test "color changes with text attributes", %{emulator: emulator} do
      result =
        emulator
        |> OSCHandlers.handle_foreground_color("#FF0000")
        |> CSIHandlers.handle_text_attributes([1, 4])
        |> OSCHandlers.handle_background_color("#0000FF")

      assert result.text_attributes.foreground == "#FF0000"
      assert result.text_attributes.background == "#0000FF"
      assert result.text_attributes.bold == true
      assert result.text_attributes.underline == true
    end

    test "window state with cursor visibility", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_mode_change(25, false)
        |> OSCHandlers.handle_window_maximize()
        |> CSIHandlers.handle_mode_change(25, true)

      assert result.window_manager.state == :maximized
      assert result.cursor_visible == true
    end
  end

  describe "state persistence" do
    test "preserves cursor position after window operations", %{
      emulator: emulator
    } do
      result =
        emulator
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> OSCHandlers.handle_window_title("Test")
        |> OSCHandlers.handle_window_size(100, 50)

      assert result.cursor == %{x: 10, y: 10}
    end

    test "preserves text attributes after mode changes", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_text_attributes([1, 4, 31])
        |> CSIHandlers.handle_mode_change(4, true)
        |> CSIHandlers.handle_mode_change(25, false)

      assert result.text_attributes.bold == true
      assert result.text_attributes.underline == true
      assert result.text_attributes.foreground == :red
    end

    test "preserves window state after cursor operations", %{emulator: emulator} do
      result =
        emulator
        |> OSCHandlers.handle_window_maximize()
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> CSIHandlers.handle_cursor_up(5)

      assert result.window_manager.state == :maximized
    end
  end

  describe "buffer interactions" do
    test "scroll with cursor position", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> CSIHandlers.handle_scroll_up(5)
        |> CSIHandlers.handle_cursor_position(20, 20)

      assert result.scroll_offset == 5
      assert result.cursor == %{x: 20, y: 20}
    end

    test "erase with text attributes", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_text_attributes([1, 4])
        |> CSIHandlers.handle_erase_display(0)
        |> CSIHandlers.handle_text_attributes([0])

      assert result.text_attributes.bold == false
      assert result.text_attributes.underline == false
    end

    test "scroll with window size", %{emulator: emulator} do
      result =
        emulator
        |> OSCHandlers.handle_window_size(100, 50)
        |> CSIHandlers.handle_scroll_up(10)
        |> CSIHandlers.handle_scroll_down(5)

      assert result.window_manager.size == {100, 50}
      assert result.scroll_offset == 5
    end
  end

  describe "terminal mode interactions" do
    test "insert mode with cursor position", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_mode_change(4, true)
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> CSIHandlers.handle_mode_change(4, false)

      assert result.insert_mode == false
      assert result.cursor == %{x: 10, y: 10}
    end

    test "cursor visibility with window state", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_mode_change(25, false)
        |> OSCHandlers.handle_window_fullscreen()
        |> CSIHandlers.handle_mode_change(25, true)

      assert result.cursor_visible == true
      assert result.window_manager.state == :fullscreen
    end

    test "multiple mode changes", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_mode_change(4, true)
        |> CSIHandlers.handle_mode_change(25, false)
        |> CSIHandlers.handle_mode_change(4, false)
        |> CSIHandlers.handle_mode_change(25, true)

      assert result.insert_mode == false
      assert result.cursor_visible == true
    end
  end

  describe "error recovery" do
    test "recovers from invalid window size", %{emulator: emulator} do
      result =
        emulator
        |> OSCHandlers.handle_window_size(-100, -50)
        |> OSCHandlers.handle_window_size(100, 50)

      assert result.window_manager.size == {100, 50}
    end

    test "recovers from invalid cursor position", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_cursor_position(-10, -10)
        |> CSIHandlers.handle_cursor_position(10, 10)

      assert result.cursor == %{x: 10, y: 10}
    end

    test "recovers from invalid color settings", %{emulator: emulator} do
      result =
        emulator
        |> OSCHandlers.handle_foreground_color("invalid")
        |> OSCHandlers.handle_foreground_color("#FF0000")

      assert result.text_attributes.foreground == "#FF0000"
    end
  end
end
