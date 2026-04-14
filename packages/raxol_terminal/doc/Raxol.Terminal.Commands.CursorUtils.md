# `Raxol.Terminal.Commands.CursorUtils`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/cursor_utils.ex#L1)

Shared utility functions for cursor handling commands.
Eliminates code duplication between CursorHandler and CSIHandler.

# `calculate_new_cursor_position`

```elixir
@spec calculate_new_cursor_position(
  {non_neg_integer(), non_neg_integer()},
  atom(),
  non_neg_integer(),
  pos_integer(),
  pos_integer()
) :: {non_neg_integer(), non_neg_integer()}
```

Calculates new cursor position based on direction and movement amount.
Ensures the new position is within the emulator bounds.

## Parameters
  - current_pos: Current {row, col} position
  - direction: Direction to move (:up, :down, :left, :right)
  - amount: Number of positions to move
  - width: Emulator width for boundary checking
  - height: Emulator height for boundary checking

## Returns
  New {row, col} position clamped to bounds

# `restore_cursor_position`

Restores a previously saved cursor position from the emulator state.

# `save_cursor_position`

Saves the current cursor position into the emulator state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
