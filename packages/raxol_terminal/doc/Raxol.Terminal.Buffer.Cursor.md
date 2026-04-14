# `Raxol.Terminal.Buffer.Cursor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/cursor.ex#L1)

Manages cursor state and operations for the screen buffer.
This module handles cursor position, visibility, style, and blink state.

# `cursor_style`

```elixir
@type cursor_style() :: :block | :underline | :bar
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Buffer.Cursor{
  blink_state: boolean(),
  position: {non_neg_integer(), non_neg_integer()},
  style: cursor_style(),
  visible: boolean()
}
```

# `blinking?`

Checks if the cursor is blinking.

## Parameters

* `buffer` - The screen buffer to query

## Returns

A boolean indicating if the cursor is blinking.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Cursor.blinking?(buffer)
    true

# `get_cursor_position`

Gets the cursor position from the ScreenBuffer struct.

# `get_position`

Gets the current cursor position.

## Parameters

* `buffer` - The screen buffer to query

## Returns

A tuple {x, y} representing the cursor position.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Cursor.get_position(buffer)
    {0, 0}

# `get_style`

Gets the current cursor style.

## Parameters

* `buffer` - The screen buffer to query

## Returns

The current cursor style.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Cursor.get_style(buffer)
    :block

# `init`

Initializes a new cursor state with default values.

# `move_backward`

Moves the cursor backward by the specified number of columns.

## Parameters

* `buffer` - The screen buffer to modify
* `columns` - Number of columns to move backward

## Returns

The updated screen buffer with new cursor position.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Cursor.move_backward(buffer, 2)
    iex> Cursor.get_position(buffer)
    {0, 0}  # Cursor stays at left edge

# `move_down`

Moves the cursor down by the specified number of lines.

## Parameters

* `buffer` - The screen buffer to modify
* `lines` - Number of lines to move down

## Returns

The updated screen buffer with new cursor position.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Cursor.move_down(buffer, 2)
    iex> Cursor.get_position(buffer)
    {0, 2}

# `move_forward`

Moves the cursor forward by the specified number of columns.

## Parameters

* `buffer` - The screen buffer to modify
* `columns` - Number of columns to move forward

## Returns

The updated screen buffer with new cursor position.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Cursor.move_forward(buffer, 2)
    iex> Cursor.get_position(buffer)
    {2, 0}

# `move_to`

Moves the cursor to the specified position.

## Parameters

* `buffer` - The screen buffer to modify
* `position` - The target position as {x, y}

## Returns

The updated screen buffer with new cursor position.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Cursor.move_to(buffer, {10, 5})
    iex> Cursor.get_position(buffer)
    {10, 5}

# `move_up`

Moves the cursor up by the specified number of lines.

## Parameters

* `buffer` - The screen buffer to modify
* `lines` - Number of lines to move up

## Returns

The updated screen buffer with new cursor position.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Cursor.move_up(buffer, 2)
    iex> Cursor.get_position(buffer)
    {0, 0}  # Cursor stays at top

# `set_blink`

Sets the cursor blink state.

## Parameters

* `buffer` - The screen buffer to modify
* `blink` - Whether the cursor should blink

## Returns

The updated screen buffer with new cursor blink state.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Cursor.set_blink(buffer, false)
    iex> Cursor.blinking?(buffer)
    false

# `set_cursor_position`

Sets the cursor position on the ScreenBuffer struct.

# `set_position`

Sets the cursor position.

## Parameters

* `buffer` - The screen buffer to modify
* `x` - The x-coordinate (column)
* `y` - The y-coordinate (row)

## Returns

The updated screen buffer with new cursor position.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Cursor.set_position(buffer, 10, 5)
    iex> Cursor.get_position(buffer)
    {10, 5}

# `set_style`

Sets the cursor style.

## Parameters

* `buffer` - The screen buffer to modify
* `style` - The cursor style (:block, :underline, :bar)

## Returns

The updated screen buffer with new cursor style.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Cursor.set_style(buffer, :underline)
    iex> Cursor.get_style(buffer)
    :underline

# `set_visibility`

Sets the cursor visibility.

## Parameters

* `buffer` - The screen buffer to modify
* `visible` - Whether the cursor should be visible

## Returns

The updated screen buffer with new cursor visibility.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Cursor.set_visibility(buffer, false)
    iex> Cursor.visible?(buffer)
    false

# `visible?`

Checks if the cursor is visible.

## Parameters

* `buffer` - The screen buffer to query

## Returns

A boolean indicating cursor visibility.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Cursor.visible?(buffer)
    true

---

*Consult [api-reference.md](api-reference.md) for complete listing*
