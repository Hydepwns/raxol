# `Raxol.Terminal.TerminalUtils`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/terminal_utils.ex#L1)

Utility functions for terminal operations, providing cross-platform and
consistent handling of terminal capabilities and dimensions.

# `cursor_position`

```elixir
@spec cursor_position() :: {:error, :not_implemented}
```

Returns the current cursor position, if available.

# `detect_dimensions`

```elixir
@spec detect_dimensions() :: {pos_integer(), pos_integer()}
```

Detects terminal dimensions using a multi-layered approach:
1. Uses `:io.columns` and `:io.rows` (preferred)
2. Falls back to termbox2 NIF if `:io` methods fail
3. Falls back to `stty size` system command if needed
4. Finally uses hardcoded default dimensions if all else fails

Returns a tuple of {width, height}.

# `detect_with_io`

```elixir
@spec detect_with_io(atom()) :: {:ok, pos_integer(), pos_integer()} | {:error, term()}
```

Detects terminal dimensions using :io.columns and :io.rows.
Returns {:ok, width, height} or {:error, reason}.

# `detect_with_stty`

```elixir
@spec detect_with_stty() :: {:ok, pos_integer(), pos_integer()} | {:error, term()}
```

Detects terminal dimensions using the stty size command.
Returns {:ok, width, height} or {:error, reason}.

# `detect_with_termbox`

```elixir
@spec detect_with_termbox() :: {:ok, pos_integer(), pos_integer()} | {:error, term()}
```

Detects terminal dimensions using the termbox2 NIF.
Returns {:ok, width, height} or {:error, reason}.

# `get_bounds_map`

```elixir
@spec get_bounds_map() :: %{x: 0, y: 0, width: pos_integer(), height: pos_integer()}
```

Creates a bounds map with dimensions, starting at origin (0,0)

# `get_dimensions_map`

```elixir
@spec get_dimensions_map() :: %{width: pos_integer(), height: pos_integer()}
```

Gets terminal dimensions and returns them in a map format.

# `has_terminal_device?`

```elixir
@spec has_terminal_device?() :: boolean()
```

Checks if stdout is connected to a real terminal device.

Unlike `real_tty?/0` which uses Erlang's IO system (fails in -noshell mode),
this checks at the OS level via prim_tty NIF. Use this for terminal
initialization that needs to work with `mix run` (which sets -noshell).

# `real_tty?`

```elixir
@spec real_tty?() :: boolean()
```

Returns true if the current process is attached to a real TTY device.

Uses Erlang's :io.columns/0 to detect whether the standard IO device
supports terminal operations, which works reliably from within the BEAM
(unlike shelling out to `tty` which doesn't inherit stdin).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
