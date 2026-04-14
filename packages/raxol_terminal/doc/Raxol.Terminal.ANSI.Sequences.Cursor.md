# `Raxol.Terminal.ANSI.Sequences.Cursor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sequences/cursor.ex#L1)

ANSI Cursor Sequence Handler.

Handles parsing and application of ANSI cursor control sequences,
including movement, position saving/restoring, and visibility.

# `move_cursor`

Move cursor to absolute position.

## Parameters

* `emulator` - The terminal emulator state
* `row` - Row to move to (1-indexed)
* `col` - Column to move to (1-indexed)

## Returns

Updated emulator state

# `move_cursor_backward`

Move cursor backward by specified number of columns.

## Parameters

* `emulator` - The terminal emulator state
* `n` - Number of columns to move backward

## Returns

Updated emulator state

# `move_cursor_down`

Move cursor down by specified number of rows.

## Parameters

* `emulator` - The terminal emulator state
* `n` - Number of rows to move down

## Returns

Updated emulator state

# `move_cursor_forward`

Move cursor forward by specified number of columns.

## Parameters

* `emulator` - The terminal emulator state
* `n` - Number of columns to move forward

## Returns

Updated emulator state

# `move_cursor_up`

Move cursor up by specified number of rows.

## Parameters

* `emulator` - The terminal emulator state
* `n` - Number of rows to move up

## Returns

Updated emulator state

# `restore_cursor_position`

Restore previously saved cursor position.

## Parameters

* `emulator` - The terminal emulator state

## Returns

Updated emulator state with restored cursor position

# `save_cursor_position`

Save current cursor position.

## Parameters

* `emulator` - The terminal emulator state

## Returns

Updated emulator state with saved cursor position

# `set_cursor_visibility`

Set cursor visibility.

## Parameters

* `emulator` - The terminal emulator state
* `visible` - Boolean indicating visibility

## Returns

Updated emulator state

---

*Consult [api-reference.md](api-reference.md) for complete listing*
