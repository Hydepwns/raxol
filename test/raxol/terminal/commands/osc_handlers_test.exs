defmodule Raxol.Terminal.Commands.OSCHandlersTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Commands.OSCHandlers
  alias Raxol.Terminal.Emulator

  describe "handle_4/2" do
    setup do
      emulator = Emulator.new(80, 24)
      %{emulator: emulator}
    end

    test "sets color using rgb: format", %{emulator: emulator} do
      # Test setting color index 1 to red using rgb: format
      new_emulator = OSCHandlers.handle_4(emulator, "1;rgb:FFFF/0000/0000")
      assert new_emulator.color_palette[1] == {255, 0, 0}
    end

    test "sets color using #RRGGBB format", %{emulator: emulator} do
      # Test setting color index 2 to green using #RRGGBB format
      new_emulator = OSCHandlers.handle_4(emulator, "2;#00FF00")
      assert new_emulator.color_palette[2] == {0, 255, 0}
    end

    test "sets color using #RGB format", %{emulator: emulator} do
      # Test setting color index 3 to blue using #RGB format
      new_emulator = OSCHandlers.handle_4(emulator, "3;#00F")
      assert new_emulator.color_palette[3] == {0, 0, 255}
    end

    test "sets color using #RRGGBBAA format (ignores alpha)", %{emulator: emulator} do
      # Test setting color index 4 to yellow using #RRGGBBAA format
      new_emulator = OSCHandlers.handle_4(emulator, "4;#FFFF0080")
      assert new_emulator.color_palette[4] == {255, 255, 0}
    end

    test "sets color using rgb(r,g,b) format", %{emulator: emulator} do
      # Test setting color index 5 to cyan using rgb(r,g,b) format
      new_emulator = OSCHandlers.handle_4(emulator, "5;rgb(0,255,255)")
      assert new_emulator.color_palette[5] == {0, 255, 255}
    end

    test "sets color using rgb(r%,g%,b%) format", %{emulator: emulator} do
      # Test setting color index 6 to magenta using rgb(r%,g%,b%) format
      new_emulator = OSCHandlers.handle_4(emulator, "6;rgb(100%,0%,100%)")
      assert new_emulator.color_palette[6] == {255, 0, 255}
    end

    test "queries color and returns correct response", %{emulator: emulator} do
      # First set a color
      emulator = OSCHandlers.handle_4(emulator, "4;rgb:FFFF/0000/0000")
      # Then query it
      new_emulator = OSCHandlers.handle_4(emulator, "4;?")

      # Check that the response is in the correct format
      assert String.contains?(new_emulator.output_buffer, "\e]4;4;rgb:")
      assert String.contains?(new_emulator.output_buffer, "\e\\")
    end

    test "handles invalid color index", %{emulator: emulator} do
      # Test with invalid color index (256)
      new_emulator = OSCHandlers.handle_4(emulator, "256;rgb:FFFF/0000/0000")
      assert new_emulator == emulator
    end

    test "handles invalid color format", %{emulator: emulator} do
      # Test with invalid color format
      new_emulator = OSCHandlers.handle_4(emulator, "1;invalid")
      assert new_emulator == emulator
    end

    test "handles invalid rgb() values", %{emulator: emulator} do
      # Test with out-of-range values
      new_emulator = OSCHandlers.handle_4(emulator, "1;rgb(300,0,0)")
      assert new_emulator == emulator
    end

    test "handles invalid rgb() percentage values", %{emulator: emulator} do
      # Test with out-of-range percentage values
      new_emulator = OSCHandlers.handle_4(emulator, "1;rgb(150%,0%,0%)")
      assert new_emulator == emulator
    end

    test "handles malformed rgb() format", %{emulator: emulator} do
      # Test with malformed rgb() format
      new_emulator = OSCHandlers.handle_4(emulator, "1;rgb(255,0)")
      assert new_emulator == emulator
    end

    test "handles malformed rgb() percentage format", %{emulator: emulator} do
      # Test with malformed rgb() percentage format
      new_emulator = OSCHandlers.handle_4(emulator, "1;rgb(100%,0)")
      assert new_emulator == emulator
    end

    test "handles malformed #RRGGBBAA format", %{emulator: emulator} do
      # Test with malformed #RRGGBBAA format
      new_emulator = OSCHandlers.handle_4(emulator, "1;#FF00")
      assert new_emulator == emulator
    end

    test "handles multiple color queries", %{emulator: emulator} do
      # Set multiple colors
      emulator = OSCHandler.handle_4(emulator, "1;rgb:FFFF/0000/0000") # Red
      emulator = OSCHandler.handle_4(emulator, "2;rgb:0000/FFFF/0000") # Green
      emulator = OSCHandler.handle_4(emulator, "3;rgb:0000/0000/FFFF") # Blue

      # Query each color
      emulator = OSCHandler.handle_4(emulator, "1;?")
      emulator = OSCHandler.handle_4(emulator, "2;?")
      emulator = OSCHandler.handle_4(emulator, "3;?")

      # Check that all responses are in the output buffer
      assert String.contains?(emulator.output_buffer, "\e]4;1;rgb:")
      assert String.contains?(emulator.output_buffer, "\e]4;2;rgb:")
      assert String.contains?(emulator.output_buffer, "\e]4;3;rgb:")
    end
  end
end
