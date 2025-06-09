defmodule Raxol.Terminal.ANSI.Emitter do
  @moduledoc """
  ANSI escape sequence generation module.

  Provides functions for generating ANSI escape sequences for terminal control:
  - Cursor movements
  - Colors and text attributes
  - Screen manipulation
  - Various terminal modes

  ## Features

  * Cursor control (movement, visibility)
  * Screen manipulation (clearing, scrolling)
  * Text attributes (bold, underline, etc.)
  * Color control (foreground, background)
  * Terminal mode control
  """

  @doc """
  Generates ANSI sequences for cursor movement.

  ## Parameters

  * `n` - Number of positions to move (default: 1)

  ## Returns

  The ANSI escape sequence for the requested cursor movement.
  """
  def cursor_up(n \\ 1), do: "\e[#{n}A"
  def cursor_down(n \\ 1), do: "\e[#{n}B"
  def cursor_forward(n \\ 1), do: "\e[#{n}C"
  def cursor_backward(n \\ 1), do: "\e[#{n}D"
  def cursor_position(row \\ 1, col \\ 1), do: "\e[#{row};#{col}H"
  def cursor_save_position, do: "\e[s"
  def cursor_restore_position, do: "\e[u"
  def cursor_show, do: "\e[?25h"
  def cursor_hide, do: "\e[?25l"

  @doc """
  Generates ANSI sequences for screen manipulation.

  ## Parameters

  * `n` - Number of lines to scroll (default: 1)

  ## Returns

  The ANSI escape sequence for the requested screen operation.
  """
  def clear_screen, do: "\e[2J"
  def clear_screen_from_cursor, do: "\e[0J"
  def clear_screen_to_cursor, do: "\e[1J"
  def clear_line, do: "\e[2K"
  def clear_line_from_cursor, do: "\e[0K"
  def clear_line_to_cursor, do: "\e[1K"
  def scroll_up(n \\ 1), do: "\e[#{n}S"
  def scroll_down(n \\ 1), do: "\e[#{n}T"

  @doc """
  Generates ANSI sequences for text attributes.

  ## Returns

  The ANSI escape sequence for the requested text attribute.
  """
  def reset_attributes, do: "\e[0m"
  def bold, do: "\e[1m"
  def faint, do: "\e[2m"
  def italic, do: "\e[3m"
  def underline, do: "\e[4m"
  def blink, do: "\e[5m"
  def rapid_blink, do: "\e[6m"
  def inverse, do: "\e[7m"
  def conceal, do: "\e[8m"
  def strikethrough, do: "\e[9m"
  def normal_intensity, do: "\e[22m"
  def no_italic, do: "\e[23m"
  def no_underline, do: "\e[24m"
  def no_blink, do: "\e[25m"
  def no_inverse, do: "\e[27m"
  def no_conceal, do: "\e[28m"
  def no_strikethrough, do: "\e[29m"

  @doc """
  Generates ANSI sequences for colors.

  ## Parameters

  * `color_code` - The color code (0-15 for basic colors)

  ## Returns

  The ANSI escape sequence for the requested color.
  """
  def foreground(color_code) when color_code in 0..15,
    do: "\e[38;5;#{color_code}m"

  def background(color_code) when color_code in 0..15,
    do: "\e[48;5;#{color_code}m"

  # Named colors
  for {color_code, color_name} <- %{
        0 => :black,
        1 => :red,
        2 => :green,
        3 => :yellow,
        4 => :blue,
        5 => :magenta,
        6 => :cyan,
        7 => :white,
        8 => :bright_black,
        9 => :bright_red,
        10 => :bright_green,
        11 => :bright_yellow,
        12 => :bright_blue,
        13 => :bright_magenta,
        14 => :bright_cyan,
        15 => :bright_white
      } do
    def foreground(unquote(color_name)), do: foreground(unquote(color_code))
    def background(unquote(color_name)), do: background(unquote(color_code))
  end

  # 256 color support
  def foreground_256(color_code) when color_code in 0..255,
    do: "\e[38;5;#{color_code}m"

  def background_256(color_code) when color_code in 0..255,
    do: "\e[48;5;#{color_code}m"

  # True color (24-bit) support
  def foreground_rgb(r, g, b)
      when r in 0..255 and g in 0..255 and b in 0..255 do
    "\e[38;2;#{r};#{g};#{b}m"
  end

  def background_rgb(r, g, b)
      when r in 0..255 and g in 0..255 and b in 0..255 do
    "\e[48;2;#{r};#{g};#{b}m"
  end

  @doc """
  Generates ANSI sequences for terminal modes.
  """
  def set_mode(mode), do: "\e[?#{mode}h"
  def reset_mode(mode), do: "\e[?#{mode}l"
  def alternate_buffer_on, do: set_mode(1049)
  def alternate_buffer_off, do: reset_mode(1049)
  def bracketed_paste_on, do: set_mode(2004)
  def bracketed_paste_off, do: reset_mode(2004)
  def auto_wrap_on, do: set_mode(7)
  def auto_wrap_off, do: reset_mode(7)
end
