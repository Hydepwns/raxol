defmodule Raxol.Terminal.Commands.OSCHandlersTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Window
  alias Raxol.Terminal.Commands.OSCHandlers

  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok({:error, _reason, value}), do: value
  defp unwrap_ok(value) when is_map(value), do: value

  defp unwrap_ok(other),
    do: raise("unwrap_ok/1: Unexpected return value: #{inspect(other)}")

  setup do
    emulator = Raxol.Terminal.Emulator.new(80, 24)

    {:ok, emulator: emulator}
  end

  describe "window title and icon" do
    test "sets window title", %{emulator: emulator} do
      result = OSCHandlers.handle_window_title(emulator, "Test Title")
      assert result == {:ok, emulator}
    end

    test "sets icon name", %{emulator: emulator} do
      result = OSCHandlers.handle_icon_name(emulator, "Test Icon")
      assert result == {:ok, emulator}
    end

    test "sets icon title", %{emulator: emulator} do
      result = OSCHandlers.handle_icon_title(emulator, "Test Icon Title")
      assert result == {:ok, emulator}
    end

    test "handles empty titles", %{emulator: emulator} do
      result = OSCHandlers.handle_window_title(emulator, "")
      assert result == {:ok, emulator}
    end

    test "handles nil titles", %{emulator: emulator} do
      result = OSCHandlers.handle_window_title(emulator, nil)
      assert result == {:ok, emulator}
    end

    test "handles very long titles", %{emulator: emulator} do
      long_title = String.duplicate("a", 1000)
      result = OSCHandlers.handle_window_title(emulator, long_title)
      assert result == {:ok, emulator}
    end
  end

  describe "color settings" do
    test "sets color index", %{emulator: emulator} do
      result = OSCHandlers.handle_osc4_color(emulator, 1, "#FF0000")
      assert result == {:ok, emulator}
    end

    test "sets foreground color", %{emulator: emulator} do
      result = OSCHandlers.handle_foreground_color(emulator, "#FF0000")
      assert result == {:ok, emulator}
    end

    test "sets background color", %{emulator: emulator} do
      result = OSCHandlers.handle_background_color(emulator, "#0000FF")
      assert result == {:ok, emulator}
    end

    test "sets cursor color", %{emulator: emulator} do
      result = OSCHandlers.handle_cursor_color(emulator, "#00FF00")
      assert result == {:ok, emulator}
    end

    test "sets mouse foreground color", %{emulator: emulator} do
      result = OSCHandlers.handle_mouse_foreground_color(emulator, "#FF00FF")
      assert result == {:ok, emulator}
    end

    test "sets mouse background color", %{emulator: emulator} do
      result = OSCHandlers.handle_mouse_background_color(emulator, "#00FFFF")
      assert result == {:ok, emulator}
    end

    test "sets highlight foreground color", %{emulator: emulator} do
      result =
        OSCHandlers.handle_highlight_foreground_color(emulator, "#FFFFFF")

      assert result == {:ok, emulator}
    end

    test "sets highlight background color", %{emulator: emulator} do
      result =
        OSCHandlers.handle_highlight_background_color(emulator, "#000000")

      assert result == {:ok, emulator}
    end

    test "handles invalid color formats", %{emulator: emulator} do
      result = OSCHandlers.handle_foreground_color(emulator, "invalid")
      assert result == {:ok, emulator}
    end

    test "handles invalid color indices", %{emulator: emulator} do
      result = OSCHandlers.handle_osc4_color(emulator, 999, "#FF0000")
      assert result == {:ok, emulator}
    end

    test "handles nil colors", %{emulator: emulator} do
      result = OSCHandlers.handle_foreground_color(emulator, nil)
      assert result == {:ok, emulator}
    end
  end

  describe "font settings" do
    test "sets font", %{emulator: emulator} do
      result = OSCHandlers.handle_font(emulator, "Monospace")
      assert result == {:ok, emulator}
    end

    test "handles empty font", %{emulator: emulator} do
      result = OSCHandlers.handle_font(emulator, "")
      assert result == {:ok, emulator}
    end

    test "handles nil font", %{emulator: emulator} do
      result = OSCHandlers.handle_font(emulator, nil)
      assert result == {:ok, emulator}
    end

    test "handles very long font names", %{emulator: emulator} do
      long_font = String.duplicate("a", 1000)
      result = OSCHandlers.handle_font(emulator, long_font)
      assert result == {:ok, emulator}
    end
  end

  describe "clipboard operations" do
    test "sets clipboard content", %{emulator: emulator} do
      result = OSCHandlers.handle_clipboard_set(emulator, "Test Content")
      assert result == {:ok, emulator}
    end

    test "gets clipboard content", %{emulator: emulator} do
      result = OSCHandlers.handle_clipboard_get(emulator)
      assert result == {:ok, emulator}
    end

    test "handles empty clipboard", %{emulator: emulator} do
      result = OSCHandlers.handle_clipboard_set(emulator, "")
      assert result == {:ok, emulator}
    end

    test "handles nil clipboard", %{emulator: emulator} do
      result = OSCHandlers.handle_clipboard_set(emulator, nil)
      assert result == {:ok, emulator}
    end

    test "handles very large clipboard content", %{emulator: emulator} do
      large_content = String.duplicate("a", 10_000)
      result = OSCHandlers.handle_clipboard_set(emulator, large_content)
      assert result == {:ok, emulator}
    end

    test "handles invalid base64 clipboard data", %{emulator: emulator} do
      result = OSCHandlers.handle_clipboard_set(emulator, "invalid base64")
      assert result == {:ok, emulator}
    end
  end

  describe "cursor shape" do
    test "sets cursor shape", %{emulator: emulator} do
      result = OSCHandlers.handle_cursor_shape(emulator, "block")
      assert result == {:ok, emulator}
    end

    test "handles invalid cursor shapes", %{emulator: emulator} do
      result = OSCHandlers.handle_cursor_shape(emulator, "invalid")
      assert result == {:ok, emulator}
    end

    test "handles empty cursor shape", %{emulator: emulator} do
      result = OSCHandlers.handle_cursor_shape(emulator, "")
      assert result == {:ok, emulator}
    end

    test "handles nil cursor shape", %{emulator: emulator} do
      result = OSCHandlers.handle_cursor_shape(emulator, nil)
      assert result == {:ok, emulator}
    end
  end

  describe "handle_4/2" do
    test "sets color using rgb: format", %{emulator: emulator} do
      # Test setting color index 1 to red using rgb: format
      result = OSCHandlers.handle_4(emulator, "1;rgb:FFFF/0000/0000")
      assert result == {:ok, emulator}
    end

    test "sets color using #RRGGBB format", %{emulator: emulator} do
      # Test setting color index 2 to green using #RRGGBB format
      result = OSCHandlers.handle_4(emulator, "2;#00FF00")
      assert result == {:ok, emulator}
    end

    test "sets color using #RGB format", %{emulator: emulator} do
      # Test setting color index 3 to blue using #RGB format
      result = OSCHandlers.handle_4(emulator, "3;#00F")
      assert result == {:ok, emulator}
    end

    test "sets color using #RRGGBBAA format (ignores alpha)", %{
      emulator: emulator
    } do
      # Test setting color index 4 to yellow using #RRGGBBAA format
      result = OSCHandlers.handle_4(emulator, "4;#FFFF0080")
      assert result == {:ok, emulator}
    end

    test "sets color using rgb(r,g,b) format", %{emulator: emulator} do
      # Test setting color index 5 to cyan using rgb(r,g,b) format
      result = OSCHandlers.handle_4(emulator, "5;rgb(0,255,255)")
      assert result == {:ok, emulator}
    end

    test "sets color using rgb(r%,g%,b%) format", %{emulator: emulator} do
      # Test setting color index 6 to magenta using rgb(r%,g%,b%) format
      result = OSCHandlers.handle_4(emulator, "6;rgb(100%,0%,100%)")
      assert result == {:ok, emulator}
    end

    test "queries color and returns correct response", %{emulator: emulator} do
      # First set a color
      result = OSCHandlers.handle_4(emulator, "4;rgb:FFFF/0000/0000")
      assert result == {:ok, emulator}
      # Then query it
      result = OSCHandlers.handle_4(emulator, "4;?")
      assert result == {:ok, emulator}
    end

    test "handles invalid color index", %{emulator: emulator} do
      # Test with invalid color index (256)
      result = OSCHandlers.handle_4(emulator, "256;rgb:FFFF/0000/0000")
      assert result == {:ok, emulator}
    end

    test "handles invalid color format", %{emulator: emulator} do
      # Test with invalid color format
      result = OSCHandlers.handle_4(emulator, "1;invalid")
      assert result == {:ok, emulator}
    end

    test "handles invalid rgb() values", %{emulator: emulator} do
      # Test with out-of-range values
      result = OSCHandlers.handle_4(emulator, "1;rgb(300,0,0)")
      assert result == {:ok, emulator}
    end

    test "handles invalid rgb() percentage values", %{emulator: emulator} do
      # Test with out-of-range percentage values
      result = OSCHandlers.handle_4(emulator, "1;rgb(150%,0%,0%)")
      assert result == {:ok, emulator}
    end

    test "handles malformed rgb() format", %{emulator: emulator} do
      # Test with malformed rgb() format
      result = OSCHandlers.handle_4(emulator, "1;rgb(255,0)")
      assert result == {:ok, emulator}
    end

    test "handles malformed rgb() percentage format", %{emulator: emulator} do
      # Test with malformed rgb() percentage format
      result = OSCHandlers.handle_4(emulator, "1;rgb(100%,0)")
      assert result == {:ok, emulator}
    end

    test "handles malformed #RRGGBBAA format", %{emulator: emulator} do
      # Test with malformed #RRGGBBAA format
      result = OSCHandlers.handle_4(emulator, "1;#FF00")
      assert result == {:ok, emulator}
    end

    test "handles multiple color queries", %{emulator: emulator} do
      # Set multiple colors
      # Red
      result = OSCHandlers.handle_4(emulator, "1;rgb:FFFF/0000/0000")
      assert result == {:ok, emulator}
      # Green
      result = OSCHandlers.handle_4(emulator, "2;rgb:0000/FFFF/0000")
      assert result == {:ok, emulator}
      # Blue
      result = OSCHandlers.handle_4(emulator, "3;rgb:0000/0000/FFFF")
      assert result == {:ok, emulator}

      # Query each color
      result = OSCHandlers.handle_4(emulator, "1;?")
      assert result == {:ok, emulator}
      result = OSCHandlers.handle_4(emulator, "2;?")
      assert result == {:ok, emulator}
      result = OSCHandlers.handle_4(emulator, "3;?")
      assert result == {:ok, emulator}
    end
  end
end
