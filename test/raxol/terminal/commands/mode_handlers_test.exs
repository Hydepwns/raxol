defmodule Raxol.Terminal.Commands.ModeHandlersTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Commands.ModeHandlers
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ANSI.TextFormatting

  setup do
    # Create a test emulator with a 10x10 screen
    emulator = %Emulator{
      main_screen_buffer: ScreenBuffer.new(10, 10),
      cursor: CursorManager.new(),
      style: TextFormatting.new()
    }

    {:ok, emulator: emulator}
  end

  describe "handle_h/2 (Set Mode)" do
    test "enables insert mode (4)", %{emulator: emulator} do
      result = ModeHandlers.handle_h(emulator, [4])
      assert result.insert_mode == true
    end

    test "enables cursor visibility (25)", %{emulator: emulator} do
      result = ModeHandlers.handle_h(emulator, [25])
      assert result.cursor.visible == true
    end

    test "enables origin mode (6)", %{emulator: emulator} do
      result = ModeHandlers.handle_h(emulator, [6])
      assert result.origin_mode == true
    end

    test "enables auto wrap (7)", %{emulator: emulator} do
      result = ModeHandlers.handle_h(emulator, [7])
      assert result.auto_wrap == true
    end

    test "enables reverse video (5)", %{emulator: emulator} do
      result = ModeHandlers.handle_h(emulator, [5])
      assert result.reverse_video == true
    end

    test "enables smooth scroll (4)", %{emulator: emulator} do
      result = ModeHandlers.handle_h(emulator, [4])
      assert result.smooth_scroll == true
    end

    test "sets screen mode to wide (3)", %{emulator: emulator} do
      result = ModeHandlers.handle_h(emulator, [3])
      assert result.screen_mode == :wide
    end

    test "sets column mode to wide (3)", %{emulator: emulator} do
      result = ModeHandlers.handle_h(emulator, [3])
      assert result.column_mode == :wide
    end

    test "handles multiple parameters", %{emulator: emulator} do
      result = ModeHandlers.handle_h(emulator, [4, 25, 6])
      assert result.insert_mode == true
      assert result.cursor.visible == true
      assert result.origin_mode == true
    end

    test "handles missing parameter", %{emulator: emulator} do
      result = ModeHandlers.handle_h(emulator, [])
      assert result == emulator
    end
  end

  describe "handle_l/2 (Reset Mode)" do
    test "disables insert mode (4)", %{emulator: emulator} do
      # First enable insert mode
      emulator = %{emulator | insert_mode: true}
      result = ModeHandlers.handle_l(emulator, [4])
      assert result.insert_mode == false
    end

    test "disables cursor visibility (25)", %{emulator: emulator} do
      # First enable cursor visibility
      emulator = %{emulator | cursor: %{emulator.cursor | visible: true}}
      result = ModeHandlers.handle_l(emulator, [25])
      assert result.cursor.visible == false
    end

    test "disables origin mode (6)", %{emulator: emulator} do
      # First enable origin mode
      emulator = %{emulator | origin_mode: true}
      result = ModeHandlers.handle_l(emulator, [6])
      assert result.origin_mode == false
    end

    test "disables auto wrap (7)", %{emulator: emulator} do
      # First enable auto wrap
      emulator = %{emulator | auto_wrap: true}
      result = ModeHandlers.handle_l(emulator, [7])
      assert result.auto_wrap == false
    end

    test "disables reverse video (5)", %{emulator: emulator} do
      # First enable reverse video
      emulator = %{emulator | reverse_video: true}
      result = ModeHandlers.handle_l(emulator, [5])
      assert result.reverse_video == false
    end

    test "disables smooth scroll (4)", %{emulator: emulator} do
      # First enable smooth scroll
      emulator = %{emulator | smooth_scroll: true}
      result = ModeHandlers.handle_l(emulator, [4])
      assert result.smooth_scroll == false
    end

    test "resets screen mode to normal (3)", %{emulator: emulator} do
      # First set screen mode to wide
      emulator = %{emulator | screen_mode: :wide}
      result = ModeHandlers.handle_l(emulator, [3])
      assert result.screen_mode == :normal
    end

    test "resets column mode to normal (3)", %{emulator: emulator} do
      # First set column mode to wide
      emulator = %{emulator | column_mode: :wide}
      result = ModeHandlers.handle_l(emulator, [3])
      assert result.column_mode == :normal
    end

    test "handles multiple parameters", %{emulator: emulator} do
      # First enable all modes
      emulator = %{
        emulator
        | insert_mode: true,
          cursor: %{emulator.cursor | visible: true},
          origin_mode: true
      }

      result = ModeHandlers.handle_l(emulator, [4, 25, 6])
      assert result.insert_mode == false
      assert result.cursor.visible == false
      assert result.origin_mode == false
    end

    test "handles missing parameter", %{emulator: emulator} do
      result = ModeHandlers.handle_l(emulator, [])
      assert result == emulator
    end
  end

  describe "handle_s/2 (Save Cursor)" do
    test "saves cursor position and attributes", %{emulator: emulator} do
      # Set cursor position and attributes
      emulator = %{
        emulator
        | cursor: %{emulator.cursor | position: {5, 5}},
          style: Map.merge(TextFormatting.new(), %{bold: true, fg_color: :red})
      }

      result = ModeHandlers.handle_s(emulator, [])

      # Verify saved state
      assert result.saved_cursor.position == {5, 5}
      assert result.saved_cursor.style.bold == true
      assert result.saved_cursor.style.fg_color == :red
    end
  end

  describe "handle_u/2 (Restore Cursor)" do
    test "restores cursor position and attributes", %{emulator: emulator} do
      # First save cursor state
      saved_cursor = %{
        position: {5, 5},
        style: Map.merge(TextFormatting.new(), %{bold: true, fg_color: :red})
      }

      emulator = %{emulator | saved_cursor: saved_cursor}

      result = ModeHandlers.handle_u(emulator, [])

      # Verify restored state
      assert result.cursor.position == {5, 5}
      assert result.style.bold == true
      assert result.style.fg_color == :red
    end

    test "handles no saved cursor", %{emulator: emulator} do
      result = ModeHandlers.handle_u(emulator, [])
      assert result == emulator
    end
  end
end
