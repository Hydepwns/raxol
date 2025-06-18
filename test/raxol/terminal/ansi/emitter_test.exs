defmodule Raxol.Terminal.ANSI.EmitterTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.Emitter

  test 'generates cursor movement sequences' do
    assert Emitter.cursor_up() == "\e[1A"
    assert Emitter.cursor_up(5) == "\e[5A"
    assert Emitter.cursor_down() == "\e[1B"
    assert Emitter.cursor_down(10) == "\e[10B"
    assert Emitter.cursor_forward() == "\e[1C"
    assert Emitter.cursor_forward(2) == "\e[2C"
    assert Emitter.cursor_backward() == "\e[1D"
    assert Emitter.cursor_backward(3) == "\e[3D"
    assert Emitter.cursor_position() == "\e[1;1H"
    assert Emitter.cursor_position(5, 10) == "\e[5;10H"
    assert Emitter.cursor_save_position() == "\e[s"
    assert Emitter.cursor_restore_position() == "\e[u"
    assert Emitter.cursor_show() == "\e[?25h"
    assert Emitter.cursor_hide() == "\e[?25l"
  end

  test 'generates screen manipulation sequences' do
    assert Emitter.clear_screen() == "\e[2J"
    assert Emitter.clear_screen_from_cursor() == "\e[0J"
    assert Emitter.clear_screen_to_cursor() == "\e[1J"
    assert Emitter.clear_line() == "\e[2K"
    assert Emitter.clear_line_from_cursor() == "\e[0K"
    assert Emitter.clear_line_to_cursor() == "\e[1K"
    assert Emitter.scroll_up() == "\e[1S"
    assert Emitter.scroll_up(5) == "\e[5S"
    assert Emitter.scroll_down() == "\e[1T"
    assert Emitter.scroll_down(3) == "\e[3T"
  end

  test 'generates text attribute sequences' do
    assert Emitter.reset_attributes() == "\e[0m"
    assert Emitter.bold() == "\e[1m"
    assert Emitter.faint() == "\e[2m"
    assert Emitter.italic() == "\e[3m"
    assert Emitter.underline() == "\e[4m"
    assert Emitter.blink() == "\e[5m"
    assert Emitter.rapid_blink() == "\e[6m"
    assert Emitter.inverse() == "\e[7m"
    assert Emitter.conceal() == "\e[8m"
    assert Emitter.strikethrough() == "\e[9m"
    assert Emitter.normal_intensity() == "\e[22m"
    assert Emitter.no_italic() == "\e[23m"
    assert Emitter.no_underline() == "\e[24m"
    assert Emitter.no_blink() == "\e[25m"
    assert Emitter.no_inverse() == "\e[27m"
    assert Emitter.no_conceal() == "\e[28m"
    assert Emitter.no_strikethrough() == "\e[29m"
  end

  test 'generates color sequences' do
    # Basic colors
    # Red
    assert Emitter.foreground(1) == "\e[38;5;1m"
    # Blue
    assert Emitter.background(4) == "\e[48;5;4m"

    # Named colors
    assert Emitter.foreground(:red) == "\e[38;5;1m"
    assert Emitter.background(:blue) == "\e[48;5;4m"

    # 256 colors
    assert Emitter.foreground_256(100) == "\e[38;5;100m"
    assert Emitter.background_256(200) == "\e[48;5;200m"

    # RGB colors
    assert Emitter.foreground_rgb(100, 150, 200) == "\e[38;2;100;150;200m"
    assert Emitter.background_rgb(50, 100, 150) == "\e[48;2;50;100;150m"
  end

  test 'generates terminal mode sequences' do
    # Show cursor
    assert Emitter.set_mode(25) == "\e[?25h"
    # Hide cursor
    assert Emitter.reset_mode(25) == "\e[?25l"
    assert Emitter.alternate_buffer_on() == "\e[?1049h"
    assert Emitter.alternate_buffer_off() == "\e[?1049l"
    assert Emitter.bracketed_paste_on() == "\e[?2004h"
    assert Emitter.bracketed_paste_off() == "\e[?2004l"
  end
end
