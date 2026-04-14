# `Raxol.Terminal.Commands.CursorHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/cursor_handler.ex#L1)

Handles cursor movement related CSI commands.

This module contains handlers for cursor movement commands like CUP, CUU, CUD, etc.
Each function takes the current emulator state and parsed parameters,
returning the updated emulator state.

# `handle_a`

Handles CSI A - Cursor Up (CUU)

# `handle_a_alias`

```elixir
@spec handle_a_alias(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Up (CUU - 'A')

# `handle_b`

Handles CSI B - Cursor Down (CUD)

# `handle_b_alias`

```elixir
@spec handle_b_alias(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Down (CUD - 'B') - alias for handle_B

# `handle_c`

Handles CSI C - Cursor Forward (CUF)

# `handle_c_alias`

```elixir
@spec handle_c_alias(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Forward (CUF - 'C') - alias for handle_C

# `handle_cha`

Handles CSI G - Cursor Horizontal Absolute (CHA)

# `handle_cpl`

Handles CSI F - Cursor Previous Line (CPL)
Moves cursor to beginning of line n lines up

# `handle_cup`

```elixir
@spec handle_cup(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Position (CUP - 'H")

# `handle_cursor_movement`

```elixir
@spec handle_cursor_movement(
  Raxol.Terminal.Emulator.t(),
  atom(),
  integer()
) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

# `handle_d`

```elixir
@spec handle_d(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Vertical Absolute (VPA - 'd') - alias for handle_decvpa

# `handle_d_alias`

```elixir
@spec handle_d_alias(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Backward (CUB - 'D') - alias for handle_D

# `handle_d_cub`

Handles CSI D - Cursor Back (CUB)

# `handle_decvpa`

```elixir
@spec handle_decvpa(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Vertical Absolute (VPA - 'd")

# `handle_e`

Handles CSI E - Cursor Next Line (CNL)
Moves cursor to beginning of line n lines down

# `handle_e_alias`

```elixir
@spec handle_e_alias(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Next Line (CNL - 'E').

# `handle_f`

```elixir
@spec handle_f(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Previous Line (CPL - 'F').

# `handle_f_alias`

```elixir
@spec handle_f_alias(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Previous Line (CPL - 'F') - alias for handle_f.

# `handle_g`

```elixir
@spec handle_g(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Horizontal Absolute (CHA - 'G').

# `handle_g_alias`

```elixir
@spec handle_g_alias(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Horizontal Absolute (CHA - 'G') - alias for handle_g.

# `handle_h`

Handles CSI H - Cursor Position (CUP)
Sets cursor position to row;column

# `handle_h_alias`

```elixir
@spec handle_h_alias(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

Handles Cursor Position (CUP - 'H') - alias for handle_cup

# `move_cursor_back`

```elixir
@spec move_cursor_back(Raxol.Terminal.Emulator.t(), non_neg_integer()) ::
  Raxol.Terminal.Emulator.t()
```

Moves the cursor back by the specified number of columns.

# `move_cursor_down`

```elixir
@spec move_cursor_down(Raxol.Terminal.Emulator.t(), non_neg_integer()) ::
  Raxol.Terminal.Emulator.t()
```

Moves the cursor down by the specified number of lines.

# `move_cursor_down`

```elixir
@spec move_cursor_down(
  Raxol.Terminal.Emulator.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.Emulator.t()
```

Moves the cursor down by the specified number of lines with width and height bounds.

# `move_cursor_forward`

```elixir
@spec move_cursor_forward(Raxol.Terminal.Emulator.t(), non_neg_integer()) ::
  Raxol.Terminal.Emulator.t()
```

Moves the cursor forward by the specified number of columns.

# `move_cursor_left`

```elixir
@spec move_cursor_left(
  Raxol.Terminal.Emulator.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.Emulator.t()
```

Moves the cursor left by the specified number of columns.

# `move_cursor_right`

```elixir
@spec move_cursor_right(
  Raxol.Terminal.Emulator.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.Emulator.t()
```

Moves the cursor right by the specified number of columns.

# `move_cursor_to`

```elixir
@spec move_cursor_to(Raxol.Terminal.Emulator.t(), integer(), integer()) ::
  Raxol.Terminal.Emulator.t()
```

Moves the cursor to a specific position.

# `move_cursor_to`

```elixir
@spec move_cursor_to(
  Raxol.Terminal.Emulator.t(),
  {integer(), integer()},
  integer(),
  integer()
) :: Raxol.Terminal.Emulator.t()
```

Moves the cursor to a specific position with width and height bounds.

# `move_cursor_to_column`

```elixir
@spec move_cursor_to_column(
  Raxol.Terminal.Emulator.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.Emulator.t()
```

Moves the cursor to a specific column.

# `move_cursor_to_line_start`

```elixir
@spec move_cursor_to_line_start(Raxol.Terminal.Emulator.t()) ::
  Raxol.Terminal.Emulator.t()
```

Moves the cursor to the start of the current line.

# `move_cursor_up`

```elixir
@spec move_cursor_up(Raxol.Terminal.Emulator.t(), non_neg_integer()) ::
  Raxol.Terminal.Emulator.t()
```

Moves the cursor up by the specified number of lines.

# `move_cursor_up`

```elixir
@spec move_cursor_up(
  Raxol.Terminal.Emulator.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.Emulator.t()
```

Moves the cursor up by the specified number of lines with width and height bounds.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
