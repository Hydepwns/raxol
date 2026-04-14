# `Raxol.Terminal.Emulator.Core`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/emulator_core.ex#L1)

Handles core emulator functionality including input processing and scrolling.

This module provides core emulator operations including:
- Input processing
- Scrolling logic
- Cursor position management
- Buffer management

# `ensure_cursor_in_visible_region`

Ensures the cursor is in the visible region by scrolling if necessary.

## Parameters

* `emulator` - The emulator state

## Returns

Updated emulator with cursor in visible region.

# `get_screen_buffer`

```elixir
@spec get_screen_buffer(Raxol.Terminal.Emulator.t()) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Gets the active buffer from the emulator.

## Parameters

* `emulator` - The emulator state

## Returns

The active screen buffer.

# `maybe_scroll`

```elixir
@spec maybe_scroll(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
```

Checks if scrolling is needed and performs it if necessary.

## Parameters

* `emulator` - The emulator state

## Returns

Updated emulator after scrolling.

# `process_input`

```elixir
@spec process_input(Raxol.Terminal.Emulator.t(), binary()) ::
  {Raxol.Terminal.Emulator.t(), binary()}
```

Processes input for the emulator.

## Parameters

* `emulator` - The emulator state
* `input` - Input to process

## Returns

A tuple {updated_emulator, output}.

# `resize`

```elixir
@spec resize(
  Raxol.Terminal.Emulator.t(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.Emulator.t()
```

Resizes the terminal emulator to new dimensions.

## Parameters

* `emulator` - The emulator state
* `width` - New width
* `height` - New height

## Returns

Updated emulator with new dimensions.

# `update_active_buffer`

Updates the active buffer in the emulator.

## Parameters

* `emulator` - The emulator state
* `new_buffer` - The new buffer to set

## Returns

Updated emulator with new buffer.

# `write_string`

Writes a string to the emulator with charset translation.

## Parameters

* `emulator` - The emulator state
* `x` - X coordinate
* `y` - Y coordinate
* `string` - String to write
* `style` - Style to apply

## Returns

Updated emulator.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
