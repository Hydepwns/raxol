# `Raxol.Terminal.Modes`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/modes.ex#L1)

Handles terminal modes and state transitions for the terminal emulator.

This module provides functions for managing terminal modes, processing
escape sequences, and handling terminal state transitions.

# `mode`

```elixir
@type mode() :: :insert | :replace | :visual | :command | :normal
```

# `mode_state`

```elixir
@type mode_state() :: %{required(mode()) =&gt; boolean()}
```

# `active?`

Checks if a terminal mode is active.

## Examples

    iex> modes = Modes.new()
    iex> Modes.active?(modes, :normal)
    true
    iex> Modes.active?(modes, :insert)
    false

# `active_modes`

Returns a list of all active terminal modes.

## Examples

    iex> modes = Modes.new()
    iex> Modes.active_modes(modes)
    [:normal, :replace]

# `new`

Creates a new terminal mode state.

## Examples

    iex> modes = Modes.new()
    iex> modes.insert
    false

# `process_escape`

Processes an escape sequence for terminal mode changes.

## Examples

    iex> modes = Modes.new()
    iex> {modes, _} = Modes.process_escape(modes, "?1049h")
    iex> Modes.active?(modes, :alternate_screen)
    true

# `reset_mode`

```elixir
@spec reset_mode(mode_state(), atom()) :: mode_state()
```

Resets a specific terminal mode to its default value.

## Examples

    iex> modes = Modes.new() |> Modes.set_mode(:insert)
    iex> modes.insert
    true
    iex> modes = Modes.reset_mode(modes, :insert)
    iex> modes.insert
    false
    iex> modes = Modes.reset_mode(modes, :replace) # replace defaults to true
    iex> modes.replace
    true

# `restore_state`

Restores a previously saved terminal mode state.

## Examples

    iex> modes = Modes.new()
    iex> {modes, saved_modes} = Modes.save_state(modes)
    iex> modes = Modes.set_mode(modes, :insert)
    iex> modes = Modes.restore_state(modes, saved_modes)
    iex> Modes.active?(modes, :normal)
    true

# `save_state`

Saves the current terminal mode state.

## Examples

    iex> modes = Modes.new()
    iex> {modes, saved_modes} = Modes.save_state(modes)
    iex> modes = Modes.set_mode(modes, :insert)
    iex> modes = Modes.restore_state(modes, saved_modes)
    iex> Modes.active?(modes, :normal)
    true

# `set_mode`

Sets a terminal mode.

## Examples

    iex> modes = Modes.new()
    iex> modes = Modes.set_mode(modes, :insert)
    iex> modes.insert
    true
    iex> modes.replace
    false

# `to_string`

Returns a string representation of the terminal mode state.

## Examples

    iex> modes = Modes.new()
    iex> Modes.to_string(modes)
    "Terminal Modes: normal, replace"

---

*Consult [api-reference.md](api-reference.md) for complete listing*
