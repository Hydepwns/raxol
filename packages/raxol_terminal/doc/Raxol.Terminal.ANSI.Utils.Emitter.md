# `Raxol.Terminal.ANSI.Utils.Emitter`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/utils.ex#L260)

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

# `alternate_buffer_off`

# `alternate_buffer_on`

# `auto_wrap_off`

# `auto_wrap_on`

# `background`

# `background_256`

# `background_rgb`

# `blink`

# `bold`

# `bracketed_paste_off`

# `bracketed_paste_on`

# `clear_line`

# `clear_line_from_cursor`

# `clear_line_to_cursor`

# `clear_screen`

Generates ANSI sequences for screen manipulation.

## Parameters

* `n` - Number of lines to scroll (default: 1)

## Returns

The ANSI escape sequence for the requested screen operation.

# `clear_screen_from_cursor`

# `clear_screen_to_cursor`

# `conceal`

# `cursor_backward`

# `cursor_down`

# `cursor_forward`

# `cursor_hide`

# `cursor_position`

# `cursor_restore_position`

# `cursor_save_position`

# `cursor_show`

# `cursor_up`

Generates ANSI sequences for cursor movement.

## Parameters

* `n` - Number of positions to move (default: 1)

## Returns

The ANSI escape sequence for the requested cursor movement.

# `faint`

# `foreground`

Generates ANSI sequences for colors.

## Parameters

* `color_code` - The color code (0-15 for basic colors)

## Returns

The ANSI escape sequence for the requested color.

# `foreground_256`

# `foreground_rgb`

# `inverse`

# `italic`

# `no_blink`

# `no_conceal`

# `no_inverse`

# `no_italic`

# `no_strikethrough`

# `no_underline`

# `normal_intensity`

# `rapid_blink`

# `reset_attributes`

Generates ANSI sequences for text attributes.

## Returns

The ANSI escape sequence for the requested text attribute.

# `reset_mode`

# `scroll_down`

Alias for scroll_down_ansi/1 for backward compatibility.

# `scroll_down_ansi`

# `scroll_up`

Alias for scroll_up_ansi/1 for backward compatibility.

# `scroll_up_ansi`

# `set_mode`

Generates ANSI sequences for terminal modes.

# `strikethrough`

# `underline`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
