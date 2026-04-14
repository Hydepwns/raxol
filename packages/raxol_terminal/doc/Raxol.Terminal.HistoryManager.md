# `Raxol.Terminal.HistoryManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/history_manager.ex#L1)

Manages terminal command history operations including history storage, retrieval, and navigation.
This module is responsible for handling all history-related operations in the terminal.

# `add_command`

Adds a command to the history.
Returns the updated emulator.

# `clear_history`

Clears the command history.
Returns the updated emulator.

# `get_all_commands`

Gets all commands in history.
Returns the list of commands.

# `get_buffer`

Gets the history buffer instance.
Returns the history buffer.

# `get_command_at`

Gets the command at the specified index.
Returns {:ok, command} or {:error, reason}.

# `get_max_size`

Gets the maximum history size.
Returns the maximum number of commands that can be stored.

# `get_position`

Gets the current history position.
Returns the current position.

# `get_size`

Gets the history size.
Returns the number of commands in history.

# `load_from_file`

Loads history from a file.
Returns {:ok, updated_emulator} or {:error, reason}.

# `next_command`

Moves to the next command in history.
Returns {:ok, updated_emulator, command} or {:error, reason}.

# `previous_command`

Moves to the previous command in history.
Returns {:ok, updated_emulator, command} or {:error, reason}.

# `save_to_file`

Saves the history to a file.
Returns :ok or {:error, reason}.

# `set_max_size`

Sets the maximum history size.
Returns the updated emulator.

# `set_position`

Sets the history position.
Returns the updated emulator.

# `update_buffer`

Updates the history buffer instance.
Returns the updated emulator.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
