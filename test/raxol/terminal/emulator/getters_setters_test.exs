defmodule Raxol.Terminal.Emulator.GettersSettersTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager

  test ~c"get_scroll_region/1 returns nil by default" do
    emulator = Emulator.new(80, 24)
    # scroll_region is nil by default in the Emulator struct
    assert Emulator.get_scroll_region(emulator) == nil
  end

  test ~c"set_scroll_region/2 updates the scroll region" do
    emulator = Emulator.new(80, 24)
    # DECSTBM uses 1-based indexing, so region (2, 10) -> {1, 9} 0-based
    {emulator_after_set, _} = Emulator.process_input(emulator, "\e[2;10r")
    assert Emulator.get_scroll_region(emulator_after_set) == {1, 9}
    # Resetting with \e[r should restore to full viewport {0, height - 1}
    # According to VT100/ANSI, \e[r resets scroll region to full window.
    # The actual behavior for what emulator.scroll_region becomes (nil or {0, height-1})
    # depends on the implementation within Emulator.process_input or ModeManager.
    # For now, let's assume it sets it to nil, which means full window.
    # If the implementation sets it to {0, height-1}, this assertion will need adjustment.
    {emulator_after_reset, _} =
      Emulator.process_input(emulator_after_set, "\e[r")

    assert Emulator.get_scroll_region(emulator_after_reset) == nil
  end

  test ~c"get_cursor_position/1 returns the current cursor position" do
    emulator = Emulator.new(80, 24)
    assert Emulator.get_cursor_position(emulator) == {0, 0}
  end

  test ~c"set_cursor_position/2 updates the cursor position" do
    emulator = Emulator.new(80, 24)
    {emulator_after_set, _} = Emulator.process_input(emulator, "\e[2;10H")
    assert Emulator.get_cursor_position(emulator_after_set) == {1, 9}
  end

  test ~c"get_cursor_visible/1 returns true by default" do
    emulator = Emulator.new(80, 24)
    assert Emulator.get_cursor_visible(emulator) == true
  end

  test ~c"set_cursor_visible/2 updates cursor visibility" do
    emulator = Emulator.new(80, 24)
    # Hide cursor with DECTCEM
    {emulator_after_hide, _} = Emulator.process_input(emulator, "\e[?25l")
    assert Emulator.get_cursor_visible(emulator_after_hide) == false

    # Show cursor with DECTCEM
    {emulator_after_show, _} =
      Emulator.process_input(emulator_after_hide, "\e[?25h")

    assert Emulator.get_cursor_visible(emulator_after_show) == true
  end

  test ~c"get_style/1 returns the default style initially" do
    emulator = Emulator.new(80, 24)
    style = emulator.style
    assert style.foreground == nil
    assert style.background == nil
    assert style.bold == false
    assert style.italic == false
    assert style.underline == false
    assert style.blink == false
    assert style.reverse == false
    assert style.conceal == false
    assert style.strikethrough == false
  end

  test ~c"set_style/2 updates the current text style" do
    emulator = Emulator.new(80, 24)
    # Set red foreground, bold, and underline
    {emulator_after_set, _} = Emulator.process_input(emulator, "\e[31;1;4m")
    style = emulator_after_set.style
    assert style.foreground == :red
    assert style.bold == true
    assert style.underline == true
  end

  test ~c"reset_style/1 resets the style to default" do
    emulator = Emulator.new(80, 24)
    # First set some styles
    {emulator_after_set, _} = Emulator.process_input(emulator, "\e[31;1;4m")
    # Then reset
    {emulator_after_reset, _} =
      Emulator.process_input(emulator_after_set, "\e[0m")

    style = emulator_after_reset.style
    assert style.foreground == nil
    assert style.background == nil
    assert style.bold == false
    assert style.italic == false
    assert style.underline == false
    assert style.blink == false
    assert style.reverse == false
    assert style.conceal == false
    assert style.strikethrough == false
  end
end
