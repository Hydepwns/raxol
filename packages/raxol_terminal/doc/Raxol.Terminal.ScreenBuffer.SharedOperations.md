# `Raxol.Terminal.ScreenBuffer.SharedOperations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen_buffer/shared_operations.ex#L1)

Shared operations for screen buffer modules to eliminate code duplication.
This module contains common functionality used across different screen buffer implementations.

# `delete_lines_core_logic`

```elixir
@spec delete_lines_core_logic(map(), non_neg_integer(), non_neg_integer()) :: map()
```

Core logic for deleting lines from a buffer.
Removes specified lines and adds empty lines at the bottom.

## Parameters
  - buffer: The buffer to modify
  - y: Starting line position
  - count: Number of lines to delete

## Returns
  Updated buffer with deleted lines

# `erase_chars_at_position`

```elixir
@spec erase_chars_at_position(
  map(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: map()
```

Erases a specified number of characters at a given position.
Replaces characters with empty cells using the buffer's default style.

## Parameters
  - buffer: The buffer to modify
  - x: Starting column position
  - y: Row position
  - count: Number of characters to erase

## Returns
  Updated buffer with erased characters

# `insert_char_core_logic`

```elixir
@spec insert_char_core_logic(
  map(),
  non_neg_integer(),
  non_neg_integer(),
  String.t(),
  map() | nil
) :: map()
```

Inserts a character at the specified position, shifting content right.
Core logic for character insertion without damage tracking.

## Parameters
  - buffer: The buffer to modify
  - x: Column position
  - y: Row position
  - char: Character to insert
  - style: Style to apply (uses buffer default if nil)

## Returns
  Buffer with updated cells (damage tracking handled by caller)

# `normalize_selection`

```elixir
@spec normalize_selection(integer(), integer(), integer(), integer()) ::
  {integer(), integer(), integer(), integer()}
```

Normalizes selection coordinates so that start is always before end.
Returns {start_x, start_y, end_x, end_y} in proper order.

## Parameters
  - x1, y1: First selection point
  - x2, y2: Second selection point

## Returns
  Tuple with normalized coordinates {start_x, start_y, end_x, end_y}

# `position_in_selection?`

```elixir
@spec position_in_selection?(
  integer(),
  integer(),
  integer(),
  integer(),
  integer(),
  integer()
) :: boolean()
```

Checks if a position (x, y) is within the selection boundaries.

## Parameters
  - x, y: Position to check
  - start_x, start_y: Selection start coordinates
  - end_x, end_y: Selection end coordinates

## Returns
  Boolean indicating if position is within selection

---

*Consult [api-reference.md](api-reference.md) for complete listing*
