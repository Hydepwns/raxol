# `Raxol.Terminal.Commands.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/manager.ex#L1)

Manages terminal command processing and execution.
This module is responsible for handling command parsing, validation, and execution.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Commands.Manager{
  command_buffer: String.t(),
  command_history: [String.t()],
  history_index: integer(),
  last_key_event: term()
}
```

# `add_to_history`

# `add_to_history_state`

Adds a command to the history.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear_command_buffer`

# `clear_command_history`

# `clear_history`

Clears the command history.

# `execute_command`

# `get_command_buffer`

# `get_command_history`

# `get_command_state`

# `get_current`

```elixir
@spec get_current(Raxol.Terminal.Emulator.t()) :: String.t() | nil
```

Gets the current command.
Returns the current command or nil.

# `get_current_command`

# `get_history_command`

Gets a command from history by index.

# `get_last_key_event`

Gets the last key event.

# `handle_manager_cast`

# `handle_manager_info`

# `new`

```elixir
@spec new() :: Raxol.Terminal.Commands.Command.t()
```

Creates a new command manager.

# `new`

```elixir
@spec new(keyword()) :: Raxol.Terminal.Commands.Command.t()
```

Creates a new command manager with options.

# `process_command`

```elixir
@spec process_command(Raxol.Terminal.Emulator.t(), String.t()) ::
  {Raxol.Terminal.Emulator.t(), any()}
```

Processes a command string.
Returns the updated emulator and any output.

# `process_key_event`

Processes a key event and updates the command buffer accordingly.

# `search_history`

Searches command history for a matching command.

# `set_command_state`

# `set_current`

```elixir
@spec set_current(Raxol.Terminal.Emulator.t(), String.t()) ::
  Raxol.Terminal.Emulator.t()
```

Sets the current command.
Returns the updated emulator.

# `set_current_command`

# `start_link`

# `update_command_buffer`

Updates the command buffer.

# `update_last_key_event`

Updates the last key event.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
