# `Raxol.Terminal.Emulator.Input`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/input.ex#L1)

Handles input processing for the terminal emulator.
Provides functions for key event handling, command history, and input parsing.

# `add_to_history`

```elixir
@spec add_to_history(Raxol.Terminal.Emulator.Struct.t(), String.t()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()}
```

Updates the command history with a new command.
Returns {:ok, updated_emulator}.

# `clear_command_buffer`

```elixir
@spec clear_command_buffer(Raxol.Terminal.Emulator.Struct.t()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()}
```

Clears the command buffer.
Returns {:ok, updated_emulator}.

# `clear_history`

```elixir
@spec clear_history(Raxol.Terminal.Emulator.Struct.t()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()}
```

Clears the command history.
Returns {:ok, updated_emulator}.

# `get_command_buffer`

```elixir
@spec get_command_buffer(Raxol.Terminal.Emulator.Struct.t()) :: String.t()
```

Gets the current command buffer.
Returns the current command buffer.

# `get_history`

```elixir
@spec get_history(Raxol.Terminal.Emulator.Struct.t()) :: list()
```

Gets the command history.
Returns the list of commands in history.

# `new`

Creates a new input handler.

# `process_key_event`

Processes a key event through the emulator.
Returns {:ok, updated_emulator, commands} or {:error, reason}.

# `process_key_press`

Processes a key press event.
Returns {:ok, updated_emulator, commands} or {:error, reason}.

# `process_key_release`

Processes a key release event.
Returns {:ok, updated_emulator, commands} or {:error, reason}.

# `process_mouse_event`

```elixir
@spec process_mouse_event(map(), map()) :: {:ok, map(), list()} | {:error, String.t()}
```

Processes a mouse event.
Returns {:ok, updated_emulator, commands} or {:error, reason}.

# `set_command_buffer`

```elixir
@spec set_command_buffer(Raxol.Terminal.Emulator.Struct.t(), String.t()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()}
```

Sets the command buffer.
Returns {:ok, updated_emulator}.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
