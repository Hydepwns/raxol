# `Raxol.Terminal.ANSI.Sequences.Colors`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sequences/colors.ex#L1)

ANSI Color Sequence Handler.

Handles parsing and application of ANSI color control sequences,
including 16-color mode, 256-color mode, and true color (24-bit) mode.

# `color_code`

Generate ANSI color code for a given color.

## Parameters

* `color` - The color struct
* `type` - Either :foreground or :background

## Returns

ANSI escape sequence as string

# `color_codes`

Returns a map of ANSI color codes.

## Returns

A map of color names to ANSI codes.

## Examples

    iex> Raxol.Terminal.ANSI.Sequences.Colors.color_codes()
    %{
      black: "[30m",
      red: "[31m",
      # ... other colors ...
      reset: "[0m"
    }

# `parse_color`

Parse a color string into a Color struct.

## Parameters

* `color_str` - Color string in format "rgb:RRRR/GGGG/BBBB" or "#RRGGBB"

## Returns

Color struct or nil if invalid format

# `set_background`

Set the background color.

## Parameters

* `colors` - The color palette
* `color` - Color struct

## Returns

Updated color palette

# `set_background_256`

Set background color using 256-color mode.

## Parameters

* `emulator` - The terminal emulator state
* `index` - Color index (0-255)

## Returns

Updated emulator state

# `set_background_basic`

Set background color using basic 16-color mode.

## Parameters

* `emulator` - The terminal emulator state
* `color_code` - Color code (0-15)

## Returns

Updated emulator state

# `set_background_true`

Set background color using true (24-bit) RGB color.

## Parameters

* `emulator` - The terminal emulator state
* `r` - Red component (0-255)
* `g` - Green component (0-255)
* `b` - Blue component (0-255)

## Returns

Updated emulator state

# `set_color`

Set a color at a specific index in the color palette.

## Parameters

* `colors` - The color palette
* `index` - Color index (0-255)
* `color` - Color struct

## Returns

Updated color palette

# `set_cursor_color`

Set the cursor color.

## Parameters

* `colors` - The color palette
* `color` - Color struct

## Returns

Updated color palette

# `set_foreground`

Set the foreground color.

## Parameters

* `colors` - The color palette
* `color` - Color struct

## Returns

Updated color palette

# `set_foreground_256`

Set foreground color using 256-color mode.

## Parameters

* `emulator` - The terminal emulator state
* `index` - Color index (0-255)

## Returns

Updated emulator state

# `set_foreground_basic`

Set foreground color using basic 16-color mode.

## Parameters

* `emulator` - The terminal emulator state
* `color_code` - Color code (0-15)

## Returns

Updated emulator state

# `set_foreground_true`

Set foreground color using true (24-bit) RGB color.

## Parameters

* `emulator` - The terminal emulator state
* `r` - Red component (0-255)
* `g` - Green component (0-255)
* `b` - Blue component (0-255)

## Returns

Updated emulator state

# `set_highlight_background`

Set the highlight background color.

## Parameters

* `colors` - The color palette
* `color` - Color struct

## Returns

Updated color palette

# `set_highlight_cursor`

Set the highlight cursor color.

## Parameters

* `colors` - The color palette
* `color` - Color struct

## Returns

Updated color palette

# `set_highlight_foreground`

Set the highlight foreground color.

## Parameters

* `colors` - The color palette
* `color` - Color struct

## Returns

Updated color palette

# `set_highlight_mouse_background`

Set the highlight mouse background color.

## Parameters

* `colors` - The color palette
* `color` - Color struct

## Returns

Updated color palette

# `set_highlight_mouse_foreground`

Set the highlight mouse foreground color.

## Parameters

* `colors` - The color palette
* `color` - Color struct

## Returns

Updated color palette

# `set_mouse_background`

Set the mouse background color.

## Parameters

* `colors` - The color palette
* `color` - Color struct

## Returns

Updated color palette

# `set_mouse_foreground`

Set the mouse foreground color.

## Parameters

* `colors` - The color palette
* `color` - Color struct

## Returns

Updated color palette

---

*Consult [api-reference.md](api-reference.md) for complete listing*
