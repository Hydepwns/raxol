# `Raxol.Terminal.Buffer.Formatting`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/formatting.ex#L1)

Manages text formatting state and operations for the screen buffer.
This module handles text attributes, colors, and style management.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Buffer.Formatting{
  background: {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil,
  blink: boolean(),
  bold: boolean(),
  dim: boolean(),
  foreground: {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil,
  hidden: boolean(),
  italic: boolean(),
  reverse: boolean(),
  strikethrough: boolean(),
  underline: boolean()
}
```

# `attribute_set?`

Checks if a specific attribute is set.

## Parameters

* `buffer` - The screen buffer to query
* `attribute` - The attribute to check

## Returns

A boolean indicating if the attribute is set.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Formatting.attribute_set?(buffer, :bold)
    false

# `get_background`

Gets the current background color.

## Parameters

* `buffer` - The screen buffer to query

## Returns

The current background color or nil if not set.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Formatting.get_background(buffer)
    nil

# `get_foreground`

Gets the current foreground color.

## Parameters

* `buffer` - The screen buffer to query

## Returns

The current foreground color or nil if not set.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Formatting.get_foreground(buffer)
    nil

# `get_set_attributes`

Gets all currently set attributes.

## Parameters

* `buffer` - The screen buffer to query

## Returns

A list of set attributes.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Formatting.set_attribute(buffer, :bold)
    iex> Formatting.get_set_attributes(buffer)
    [:bold]

# `get_style`

Gets the current style.

## Parameters

* `buffer` - The screen buffer to query

## Returns

The current style map.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Formatting.get_style(buffer)
    %{bold: false, dim: false, italic: false, underline: false, blink: false, reverse: false, hidden: false, strikethrough: false, foreground: nil, background: nil}

# `init`

Initializes a new formatting state with default values.

# `reset_all`

Resets all attributes to their default values.

## Parameters

* `buffer` - The screen buffer to modify

## Returns

The updated screen buffer with all attributes reset.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Formatting.reset_all(buffer)
    iex> Formatting.get_style(buffer)
    %{bold: false, dim: false, italic: false, underline: false, blink: false, reverse: false, hidden: false, strikethrough: false, foreground: nil, background: nil}

# `reset_attribute`

Resets a specific attribute.

## Parameters

* `buffer` - The screen buffer to modify
* `attribute` - The attribute to reset (:bold, :dim, :italic, etc.)

## Returns

The updated screen buffer with the attribute reset.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Formatting.reset_attribute(buffer, :bold)
    iex> Formatting.attribute_set?(buffer, :bold)
    false

# `set_attribute`

Sets a specific attribute.

## Parameters

* `buffer` - The screen buffer to modify
* `attribute` - The attribute to set (:bold, :dim, :italic, etc.)

## Returns

The updated screen buffer with the attribute set.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Formatting.set_attribute(buffer, :bold)
    iex> Formatting.attribute_set?(buffer, :bold)
    true

# `set_background`

Sets the background color.

## Parameters

* `buffer` - The screen buffer to modify
* `color` - The RGB color tuple {r, g, b}

## Returns

The updated screen buffer with new background color.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Formatting.set_background(buffer, {0, 0, 255})
    iex> Formatting.get_background(buffer)
    {0, 0, 255}

# `set_foreground`

Sets the foreground color.

## Parameters

* `buffer` - The screen buffer to modify
* `color` - The RGB color tuple {r, g, b}

## Returns

The updated screen buffer with new foreground color.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Formatting.set_foreground(buffer, {255, 0, 0})
    iex> Formatting.get_foreground(buffer)
    {255, 0, 0}

# `update_style`

Updates the style with new attributes.

## Parameters

* `buffer` - The screen buffer to modify
* `style` - The new style map

## Returns

The updated screen buffer with new style.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Formatting.update_style(buffer, %{bold: true})
    iex> Formatting.get_style(buffer)
    %{bold: true, ...}

---

*Consult [api-reference.md](api-reference.md) for complete listing*
