defmodule Raxol.Terminal.Emulator.GettersSettersTest do
  use ExUnit.Case

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  describe "Emulator Getters/Setters" do
    test "get/set scroll region via ANSI" do
      emulator = Emulator.new(80, 24)
      # Check initial direct access
      assert emulator.scroll_region == nil
      # Use process_input for CSI r sequence to set
      # Set scroll region 5-15 (1-based -> 6, 16 in sequence)
      {emulator, ""} = Emulator.process_input(emulator, "\e[6;16r")
      # Direct access check (0-based)
      assert emulator.scroll_region == {5, 15}
      # Use process_input for CSI r sequence with no params to clear
      {emulator, ""} = Emulator.process_input(emulator, "\e[r")
      # Direct access check
      assert emulator.scroll_region == nil
    end

    test "get/set text style via ANSI SGR" do
      emulator = Emulator.new(80, 24)
      # Check initial direct access
      assert emulator.style == TextFormatting.new()

      # Use process_input for SGR sequence
      # Bold, Red
      {emulator, ""} = Emulator.process_input(emulator, "\e[1;31m")

      # Direct access check
      style = emulator.style
      assert style.bold == true
      assert style.foreground == :red

      # Use process_input to reset (SGR 0)
      {emulator, ""} = Emulator.process_input(emulator, "\e[0m")
      # Direct access check
      assert emulator.style == TextFormatting.new()
    end

    test "get/set options directly" do
      emulator = Emulator.new(80, 24)
      # Direct access check
      assert emulator.options == %{}
      # Set options directly (no standard ANSI for arbitrary options)
      emulator = %{emulator | options: %{foo: :bar}}
      # Direct access check
      assert emulator.options == %{foo: :bar}
    end

    test "get dimensions and resize buffer" do
      emulator = Emulator.new(80, 24)
      # Use ScreenBuffer functions via get_active_buffer
      assert {ScreenBuffer.get_width(Emulator.get_active_buffer(emulator)),
              ScreenBuffer.get_height(Emulator.get_active_buffer(emulator))} ==
               {80, 24}

      # Resize the main buffer directly (Emulator itself doesn't handle resize)
      new_buffer =
        ScreenBuffer.resize(Emulator.get_active_buffer(emulator), 100, 30)

      # Update the emulator state with the resized buffer
      emulator = %{emulator | main_screen_buffer: new_buffer}

      # Use ScreenBuffer functions again to check new dimensions
      assert {ScreenBuffer.get_width(Emulator.get_active_buffer(emulator)),
              ScreenBuffer.get_height(Emulator.get_active_buffer(emulator))} ==
               {100, 30}

      # Verify buffer properties directly
      buffer = Emulator.get_active_buffer(emulator)
      assert buffer.width == 100
      assert buffer.height == 30
    end

    # Specific getters like get_mode_state, get_charset_state aren't typical;
    # state is usually accessed directly or tested via behavior (ANSI sequences).
  end
end
