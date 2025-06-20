defmodule Raxol.Terminal.Commands.OSCHandlersTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.{Emulator, Window}
  alias Raxol.Terminal.Commands.OSCHandlers

  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok({:error, _reason, value}), do: value
  defp unwrap_ok(value) when is_map(value), do: value

  defp unwrap_ok(other),
    do: raise("unwrap_ok/1: Unexpected return value: #{inspect(other)}")

  setup do
    emulator = %Raxol.Terminal.Emulator.Struct{
      window_manager: Raxol.Terminal.Window.Manager.new_for_test(),
      active_buffer: %{width: 80, height: 24}
    }

    {:ok, emulator: emulator}
  end

  describe "window title and icon" do
    test "sets window title", %{emulator: emulator} do
      result = OSCHandlers.handle_window_title(emulator, "Test Title")
      assert result.window_manager.title == "Test Title"
    end

    test "sets icon name", %{emulator: emulator} do
      result = OSCHandlers.handle_icon_name(emulator, "Test Icon")
      assert result.window_manager.icon_name == "Test Icon"
    end

    test "sets icon title", %{emulator: emulator} do
      result = OSCHandlers.handle_icon_title(emulator, "Test Icon Title")
      assert result.window_manager.icon_title == "Test Icon Title"
    end

    test "handles empty titles", %{emulator: emulator} do
      result = OSCHandlers.handle_window_title(emulator, "")
      assert result.window_manager.title == ""
    end

    test "handles nil titles", %{emulator: emulator} do
      result = OSCHandlers.handle_window_title(emulator, nil)
      assert result.window_manager.title == ""
    end

    test "handles very long titles", %{emulator: emulator} do
      long_title = String.duplicate("a", 1000)
      result = OSCHandlers.handle_window_title(emulator, long_title)
      assert result.window_manager.title == long_title
    end
  end

  describe "color settings" do
    test "sets color index", %{emulator: emulator} do
      result = OSCHandlers.handle_osc4_color(emulator, 1, "#FF0000")
      assert result.color_palette[1] == "#FF0000"
    end

    test "sets foreground color", %{emulator: emulator} do
      result = OSCHandlers.handle_foreground_color(emulator, "#FF0000")
      assert result.text_attributes.foreground == "#FF0000"
    end

    test "sets background color", %{emulator: emulator} do
      result = OSCHandlers.handle_background_color(emulator, "#0000FF")
      assert result.text_attributes.background == "#0000FF"
    end

    test "sets cursor color", %{emulator: emulator} do
      result = OSCHandlers.handle_cursor_color(emulator, "#00FF00")
      assert result.cursor_color == "#00FF00"
    end

    test "sets mouse foreground color", %{emulator: emulator} do
      result = OSCHandlers.handle_mouse_foreground_color(emulator, "#FF00FF")
      assert result.mouse_foreground_color == "#FF00FF"
    end

    test "sets mouse background color", %{emulator: emulator} do
      result = OSCHandlers.handle_mouse_background_color(emulator, "#00FFFF")
      assert result.mouse_background_color == "#00FFFF"
    end

    test "sets highlight foreground color", %{emulator: emulator} do
      result =
        OSCHandlers.handle_highlight_foreground_color(emulator, "#FFFFFF")

      assert result.highlight_foreground_color == "#FFFFFF"
    end

    test "sets highlight background color", %{emulator: emulator} do
      result =
        OSCHandlers.handle_highlight_background_color(emulator, "#000000")

      assert result.highlight_background_color == "#000000"
    end

    test "handles invalid color formats", %{emulator: emulator} do
      result = OSCHandlers.handle_foreground_color(emulator, "invalid")
      assert result.text_attributes.foreground == :default
    end

    test "handles invalid color indices", %{emulator: emulator} do
      result = OSCHandlers.handle_osc4_color(emulator, 999, "#FF0000")
      assert result == emulator
    end

    test "handles nil colors", %{emulator: emulator} do
      result = OSCHandlers.handle_foreground_color(emulator, nil)
      assert result.text_attributes.foreground == :default
    end
  end

  describe "font settings" do
    test "sets font", %{emulator: emulator} do
      result = OSCHandlers.handle_font(emulator, "Monospace")
      assert result.font == "Monospace"
    end

    test "handles empty font", %{emulator: emulator} do
      result = OSCHandlers.handle_font(emulator, "")
      assert result.font == ""
    end

    test "handles nil font", %{emulator: emulator} do
      result = OSCHandlers.handle_font(emulator, nil)
      assert result.font == ""
    end

    test "handles very long font names", %{emulator: emulator} do
      long_font = String.duplicate("a", 1000)
      result = OSCHandlers.handle_font(emulator, long_font)
      assert result.font == long_font
    end
  end

  describe "clipboard operations" do
    test "sets clipboard content", %{emulator: emulator} do
      result = OSCHandlers.handle_clipboard_set(emulator, "Test Content")
      assert result.clipboard == "Test Content"
    end

    test "gets clipboard content", %{emulator: emulator} do
      emulator = %{emulator | clipboard: "Test Content"}
      result = OSCHandlers.handle_clipboard_get(emulator)
      assert result.output_buffer =~ ~r/\x1B\]52;c;.*\x07/
    end

    test "handles empty clipboard", %{emulator: emulator} do
      result = OSCHandlers.handle_clipboard_set(emulator, "")
      assert result.clipboard == ""
    end

    test "handles nil clipboard", %{emulator: emulator} do
      result = OSCHandlers.handle_clipboard_set(emulator, nil)
      assert result.clipboard == ""
    end

    test "handles very large clipboard content", %{emulator: emulator} do
      large_content = String.duplicate("a", 10_000)
      result = OSCHandlers.handle_clipboard_set(emulator, large_content)
      assert result.clipboard == large_content
    end

    test "handles invalid base64 clipboard data", %{emulator: emulator} do
      result = OSCHandlers.handle_clipboard_set(emulator, "invalid base64")
      assert result.clipboard == ""
    end
  end

  describe "cursor shape" do
    test "sets cursor shape", %{emulator: emulator} do
      result = OSCHandlers.handle_cursor_shape(emulator, "block")
      assert result.cursor_shape == :block
    end

    test "handles invalid cursor shapes", %{emulator: emulator} do
      result = OSCHandlers.handle_cursor_shape(emulator, "invalid")
      # Default shape
      assert result.cursor_shape == :block
    end

    test "handles empty cursor shape", %{emulator: emulator} do
      result = OSCHandlers.handle_cursor_shape(emulator, "")
      # Default shape
      assert result.cursor_shape == :block
    end

    test "handles nil cursor shape", %{emulator: emulator} do
      result = OSCHandlers.handle_cursor_shape(emulator, nil)
      # Default shape
      assert result.cursor_shape == :block
    end
  end

  describe "handle_4/2" do
    test "sets color using rgb: format", %{emulator: emulator} do
      # Test setting color index 1 to red using rgb: format
      result = OSCHandlers.handle_4(emulator, "1;rgb:FFFF/0000/0000")
      new_emulator = unwrap_ok(result)

      assert new_emulator.color_palette[1] == {255, 0, 0}
    end

    test "sets color using #RRGGBB format", %{emulator: emulator} do
      # Test setting color index 2 to green using #RRGGBB format
      result = OSCHandlers.handle_4(emulator, "2;#00FF00")
      new_emulator = unwrap_ok(result)
      assert new_emulator.color_palette[2] == {0, 255, 0}
    end

    test "sets color using #RGB format", %{emulator: emulator} do
      # Test setting color index 3 to blue using #RGB format
      result = OSCHandlers.handle_4(emulator, "3;#00F")
      new_emulator = unwrap_ok(result)
      assert new_emulator.color_palette[3] == {0, 0, 255}
    end

    test "sets color using #RRGGBBAA format (ignores alpha)", %{
      emulator: emulator
    } do
      # Test setting color index 4 to yellow using #RRGGBBAA format
      result = OSCHandlers.handle_4(emulator, "4;#FFFF0080")
      new_emulator = unwrap_ok(result)
      assert new_emulator.color_palette[4] == {255, 255, 0}
    end

    test "sets color using rgb(r,g,b) format", %{emulator: emulator} do
      # Test setting color index 5 to cyan using rgb(r,g,b) format
      result = OSCHandlers.handle_4(emulator, "5;rgb(0,255,255)")
      new_emulator = unwrap_ok(result)
      assert new_emulator.color_palette[5] == {0, 255, 255}
    end

    test "sets color using rgb(r%,g%,b%) format", %{emulator: emulator} do
      # Test setting color index 6 to magenta using rgb(r%,g%,b%) format
      result = OSCHandlers.handle_4(emulator, "6;rgb(100%,0%,100%)")
      new_emulator = unwrap_ok(result)

      assert new_emulator.color_palette[6] == {255, 0, 255}
    end

    test "queries color and returns correct response", %{emulator: emulator} do
      # First set a color
      result = OSCHandlers.handle_4(emulator, "4;rgb:FFFF/0000/0000")
      emulator = unwrap_ok(result)
      # Then query it
      result = OSCHandlers.handle_4(emulator, "4;?")
      emulator = unwrap_ok(result)
      output = emulator.output_buffer

      # Check that the response is in the correct format
      assert String.contains?(output, "\e]4;4;rgb:")
      assert String.contains?(output, "\e\\")
    end

    test "handles invalid color index", %{emulator: emulator} do
      # Test with invalid color index (256)
      result = OSCHandlers.handle_4(emulator, "256;rgb:FFFF/0000/0000")
      new_emulator = unwrap_ok(result)
      assert new_emulator == emulator
    end

    test "handles invalid color format", %{emulator: emulator} do
      # Test with invalid color format
      result = OSCHandlers.handle_4(emulator, "1;invalid")
      new_emulator = unwrap_ok(result)
      assert new_emulator == emulator
    end

    test "handles invalid rgb() values", %{emulator: emulator} do
      # Test with out-of-range values
      result = OSCHandlers.handle_4(emulator, "1;rgb(300,0,0)")
      new_emulator = unwrap_ok(result)
      assert new_emulator == emulator
    end

    test "handles invalid rgb() percentage values", %{emulator: emulator} do
      # Test with out-of-range percentage values
      result = OSCHandlers.handle_4(emulator, "1;rgb(150%,0%,0%)")
      new_emulator = unwrap_ok(result)
      assert new_emulator == emulator
    end

    test "handles malformed rgb() format", %{emulator: emulator} do
      # Test with malformed rgb() format
      result = OSCHandlers.handle_4(emulator, "1;rgb(255,0)")
      new_emulator = unwrap_ok(result)
      assert new_emulator == emulator
    end

    test "handles malformed rgb() percentage format", %{emulator: emulator} do
      # Test with malformed rgb() percentage format
      result = OSCHandlers.handle_4(emulator, "1;rgb(100%,0)")
      new_emulator = unwrap_ok(result)
      assert new_emulator == emulator
    end

    test "handles malformed #RRGGBBAA format", %{emulator: emulator} do
      # Test with malformed #RRGGBBAA format
      result = OSCHandlers.handle_4(emulator, "1;#FF00")
      new_emulator = unwrap_ok(result)
      assert new_emulator == emulator
    end

    test "handles multiple color queries", %{emulator: emulator} do
      # Set multiple colors
      # Red
      result = OSCHandlers.handle_4(emulator, "1;rgb:FFFF/0000/0000")
      emulator = unwrap_ok(result)
      # Green
      result = OSCHandlers.handle_4(emulator, "2;rgb:0000/FFFF/0000")
      emulator = unwrap_ok(result)
      # Blue
      result = OSCHandlers.handle_4(emulator, "3;rgb:0000/0000/FFFF")
      emulator = unwrap_ok(result)

      # Query each color and accumulate output_buffer
      result = OSCHandlers.handle_4(emulator, "1;?")
      emulator = unwrap_ok(result)
      output = emulator.output_buffer
      result = OSCHandlers.handle_4(emulator, "2;?")
      emulator = unwrap_ok(result)
      output = output <> emulator.output_buffer
      result = OSCHandlers.handle_4(emulator, "3;?")
      emulator = unwrap_ok(result)
      output = output <> emulator.output_buffer

      # Check that all responses are in the output buffer
      assert String.contains?(output, "\e]4;1;rgb:")
      assert String.contains?(output, "\e]4;2;rgb:")
      assert String.contains?(output, "\e]4;3;rgb:")
    end
  end
end
