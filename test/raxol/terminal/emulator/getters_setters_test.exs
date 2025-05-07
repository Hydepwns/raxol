defmodule Raxol.Terminal.Emulator.GettersSettersTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Emulator

  test "get_scroll_region/1 returns nil by default" do
    emulator = Emulator.new(80, 24)
    # Expect the default full buffer dimensions instead of nil
    assert Emulator.get_scroll_region(emulator) == {0, 23}
  end

  test "set_scroll_region/2 updates the scroll region" do
    emulator = Emulator.new(80, 24)
    # DECSTBM uses 1-based indexing, so region (2, 10) -> {1, 9} 0-based
    {emulator_after_set, _} = Emulator.process_input(emulator, "\e[2;10r")
    assert Emulator.get_scroll_region(emulator_after_set) == {1, 9}
    # Resetting with \e[r should restore to full viewport {0, height - 1}
    {emulator_after_reset, _} = Emulator.process_input(emulator_after_set, "\e[r")
    assert Emulator.get_scroll_region(emulator_after_reset) == {0, 23}
  end

  test "get_cursor_position/1 returns the current cursor position" do
    emulator = Emulator.new(80, 24)
    assert Emulator.get_cursor_position(emulator) == {0, 0}
  end

  test "set_cursor_position/2 updates the cursor position" do
    emulator = Emulator.new(80, 24)
    {emulator_after_set, _} = Emulator.process_input(emulator, "\e[2;10H")
    assert Emulator.get_cursor_position(emulator_after_set) == {1, 9}
  end

  test "get_cursor_visible/1 returns true by default" do
    emulator = Emulator.new(80, 24)
    assert Emulator.get_cursor_visible(emulator) == true
  end

  test "set_cursor_visible/2 updates cursor visibility" do
    emulator = Emulator.new(80, 24)
    # Hide cursor with DECTCEM
    {emulator_after_hide, _} = Emulator.process_input(emulator, "\e[?25l")
    assert Emulator.get_cursor_visible(emulator_after_hide) == false

    # Show cursor with DECTCEM
    {emulator_after_show, _} = Emulator.process_input(emulator_after_hide, "\e[?25h")
    assert Emulator.get_cursor_visible(emulator_after_show) == true
  end

  test "get_style/1 returns the default style initially" do
    emulator = Emulator.new(80, 24)
    style = Emulator.get_style(emulator)
    assert style.foreground == nil
    assert style.background == nil
    assert style.bold == false
    assert style.italic == false
    assert style.underline == false
    assert style.blink == false
    assert style.reverse == false
    assert style.conceal == false
    assert style.strike == false
  end

  test "set_style/2 updates the current text style" do
    emulator = Emulator.new(80, 24)
    # Set red foreground, bold, and underline
    {emulator_after_set, _} = Emulator.process_input(emulator, "\e[31;1;4m")
    style = Emulator.get_style(emulator_after_set)
    assert style.foreground == :red
    assert style.bold == true
    assert style.underline == true
  end

  test "reset_style/1 resets the style to default" do
    emulator = Emulator.new(80, 24)
    # First set some styles
    {emulator_after_set, _} = Emulator.process_input(emulator, "\e[31;1;4m")
    # Then reset
    {emulator_after_reset, _} = Emulator.process_input(emulator_after_set, "\e[0m")
    style = Emulator.get_style(emulator_after_reset)
    assert style.foreground == nil
    assert style.background == nil
    assert style.bold == false
    assert style.italic == false
    assert style.underline == false
    assert style.blink == false
    assert style.reverse == false
    assert style.conceal == false
    assert style.strike == false
  end
end
