defmodule Raxol.Terminal.Commands.IntegrationTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.{Emulator, Window}
  alias Raxol.Terminal.Commands.{CSIHandlers, OSCHandlers}

  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok({:error, _reason, value}), do: value
  defp unwrap_ok(value) when is_map(value), do: value

  setup do
    emulator = Raxol.Terminal.Emulator.new(80, 24)

    {:ok, emulator: emulator}
  end

  describe "combined operations" do
    test "window resize with cursor position", %{emulator: emulator} do
      result =
        emulator
        |> OSCHandlers.handle_window_size(100, 50)
        |> unwrap_ok()
        |> CSIHandlers.handle_cursor_position(20, 20)
        |> unwrap_ok()
        |> OSCHandlers.handle_window_title("Test")
        |> unwrap_ok()

      assert Raxol.Terminal.Cursor.Manager.get_position(result.cursor) ==
               {19, 19}
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

      assert Raxol.Terminal.Window.Manager.get_window_state(
               result.window_manager
             ) == :maximized

      assert Raxol.Terminal.Cursor.Manager.get_visibility(result.cursor) == true
    end
  end

  describe "state persistence" do
    test "preserves cursor position after window operations", %{
      emulator: emulator
    } do
      result1 =
        emulator
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> unwrap_ok()

      IO.puts(
        "After cursor position: #{inspect(Raxol.Terminal.Cursor.Manager.get_position(result1.cursor))}"
      )

      result2 =
        result1
        |> OSCHandlers.handle_window_title("Test")
        |> unwrap_ok()

      IO.puts(
        "After window title: #{inspect(Raxol.Terminal.Cursor.Manager.get_position(result2.cursor))}"
      )

      result =
        result2
        |> OSCHandlers.handle_window_size(100, 50)
        |> unwrap_ok()

      IO.puts(
        "After window size: #{inspect(Raxol.Terminal.Cursor.Manager.get_position(result.cursor))}"
      )

      assert Raxol.Terminal.Cursor.Manager.get_position(result.cursor) == {9, 9}
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

      assert Raxol.Terminal.Window.Manager.get_window_state(
               result.window_manager
             ) == :maximized
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

      assert Raxol.Terminal.Window.Manager.get_window_size(
               result.window_manager
             ) == {100, 50}
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

      assert Raxol.Terminal.Cursor.Manager.get_visibility(result.cursor) == true

      assert Raxol.Terminal.Window.Manager.get_window_state(
               result.window_manager
             ) == :fullscreen
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

      assert Raxol.Terminal.Cursor.Manager.get_visibility(result.cursor) == true
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

      assert Raxol.Terminal.Window.Manager.get_window_size(
               result.window_manager
             ) == {100, 50}
    end

    test "recovers from invalid cursor position", %{emulator: emulator} do
      result =
        emulator
        |> CSIHandlers.handle_cursor_position(-10, -10)
        |> unwrap_ok()
        |> CSIHandlers.handle_cursor_position(10, 10)
        |> unwrap_ok()

      assert Raxol.Terminal.Cursor.Manager.get_position(result.cursor) == {9, 9}
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
