# Terminal Commands

This directory contains modules that handle various terminal command operations. It is part of the larger refactoring effort of the Raxol terminal system, as outlined in the `REORGANIZATION_PLAN.md` document.

## Purpose

The modules in this directory replace the monolithic `Raxol.Terminal.CommandExecutor` module (1243 lines) with smaller, more focused modules that each handle a specific aspect of terminal command execution. This improves maintainability, testability, and makes the codebase easier to understand.

## Module Structure

- `Executor.ex` - Main entry point for command execution that delegates to specialized modules
- `Parser.ex` - Handles parsing of command parameters
- `Modes.ex` - Handles DEC private modes and ANSI modes
- `Screen.ex` - Handles screen manipulation commands
- `Formatting.ex` - Handles text formatting commands
- `Device.ex` - Handles device status reports and queries
- `Character.ex` - Handles character set selection and manipulation

## Integration

These modules are used by the terminal emulator to process command sequences that come from input streams. They transform the emulator state based on the commands received. The modules are integrated with the broader terminal system, including the ANSI escape sequence handling, cursor operations, and terminal configuration.

## Backward Compatibility

For backward compatibility, the original `Raxol.Terminal.CommandExecutor` module has been updated to delegate to these modules, with deprecation warnings to guide users to the new API.

## Future Extensions

Additional modules may be added to this directory as further refactoring is done, such as:

- `Input.ex` - For handling input processing and validation
- `Output.ex` - For managing output formatting and display
- `Error.ex` - For handling error reporting and logging

## Style Guidelines

Following the project-wide style guidelines:

- Files should not exceed 300 lines of code
- Public functions should have comprehensive documentation
- Tests should be written for each module

## Examples

```elixir
# Processing a CSI command through the new API
Raxol.Terminal.Commands.Executor.execute_csi_command(
  emulator,
  "5;10",  # Parameters
  "",      # Intermediates
  ?m       # Final byte (SGR command)
)

# Parsing command parameters
Raxol.Terminal.Commands.Parser.parse_params("5;10;15")
# => [5, 10, 15]
```

## Related Directories

- `../ansi/` - Handles ANSI escape sequences
- `../cursor/` - Manages cursor operations
- `../config/` - Contains terminal configuration
- `../input/` - Manages input processing
- `../output/` - Manages output formatting
