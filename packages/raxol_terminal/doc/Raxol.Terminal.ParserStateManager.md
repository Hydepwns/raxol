# `Raxol.Terminal.ParserStateManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser_state_manager.ex#L1)

Consolidated terminal parser state manager combining simple emulator operations with
comprehensive parser state management.

This module consolidates functionality from:
- Simple parser state operations on Emulator structs
- Comprehensive parser state management from Parser.State.Manager

## Usage
For simple emulator operations:
    emulator = ParserStateManager.reset_parser_state(emulator)

For comprehensive parser operations:
    manager = ParserStateManager.create_parser_manager()
    manager = ParserStateManager.process_char(manager, ?A)

## Migration from Parser.State.Manager
Use `create_parser_manager/0` instead of `Parser.State.Manager.new/0`

# `add_intermediate`

Adds an intermediate character to the buffer.
Returns the updated emulator.

# `add_param`

Adds a parameter to the current parser state.
Returns the updated emulator.

# `clear_intermediates`

Clears all intermediate characters.
Returns the updated emulator.

# `clear_params`

Clears all parser parameters.
Returns the updated emulator.

# `create_parser_manager`

# `get_intermediates`

Gets the current intermediate characters buffer.
Returns the intermediates buffer as a binary string.

# `get_mode`

Gets the current parser mode (state).
Returns the current mode.

# `get_params`

Gets the current parser parameters.
Returns the list of parameters.

# `get_parser_state`

Gets the current parser state.
Returns the parser state.

# `process_char`

Processes a character in the current parser state.
Returns the updated emulator and any output.

# `process_parser_char`

# `reset_parser_state`

Resets the parser state to its initial state.
Returns the updated emulator.

# `set_intermediates`

Sets the intermediate characters buffer.
Returns the updated emulator.

# `set_mode`

Sets the parser mode (state).
Returns the updated emulator.

# `set_params`

Sets the parser parameters.
Returns the updated emulator.

# `update_parser_state`

Updates the parser state.
Returns the updated emulator.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
