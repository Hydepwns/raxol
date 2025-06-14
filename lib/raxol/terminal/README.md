# Raxol Terminal Subsystem

- Handles terminal I/O, buffer management, parsing, cursor, and command execution.

## Key Modules

- `Buffer.Manager` — Screen buffer operations (double buffering, damage tracking)
- `Cursor.Manager` — Cursor state and movement
- `State.Manager` — Terminal state/configuration
- `Command.Manager` — Command processing and execution
- `Style.Manager` — Text styling and formatting
- `Emulator` — Terminal emulation core
- `Integration` — Connects and synchronizes terminal components
- `ANSI` — Escape sequence parsing and handling

## Extension Points

- Behaviours: `Driver.Behaviour`, `ScreenBuffer.Behaviour`, `Emulator.Behaviour`
- Public APIs: `Integration`, `Emulator`, `Buffer.Manager`

## References

- See [ARCHITECTURE.md](../../../docs/ARCHITECTURE.md) for system overview
- See module docs for implementation details

## Broader Directory Structure

The Raxol Terminal subsystem is part of the broader Raxol framework, which includes:

- `lib/raxol/` — Core framework modules
- `lib/raxol/terminal/` — Terminal subsystem
- `lib/raxol/terminal/ansi/` — ANSI escape sequence handling
- `lib/raxol/terminal/commands/` — Command processing
- `lib/raxol/terminal/config/` — Configuration management
- `lib/raxol/terminal/buffer/` — Buffer management
- `lib/raxol/terminal/cursor/` — Cursor management
- `lib/raxol/terminal/state/` — Terminal state management
- `lib/raxol/terminal/style/` — Text styling and formatting
- `lib/raxol/terminal/emulator/` — Terminal emulation core
- `lib/raxol/terminal/integration/` — Integration layer

## Reorganization Notice

This module is currently undergoing a significant restructuring as part of the Raxol Repository Reorganization Plan. The goal is to break down large monolithic files into smaller, more focused modules for improved maintainability and discoverability.

### Completed Refactoring

- **ANSI Module**: The large `ansi.ex` (1257 lines) has been broken down into:

  - `ansi/parser.ex` - ANSI escape sequence parsing
  - `ansi/emitter.ex` - ANSI sequence generation
  - `ansi/sequences/*.ex` - Handlers for specific sequence types
  - `ansi_facade.ex` - Maintains backward compatibility

- **Command Executor**: The large `command_executor.ex` (1243 lines) has been broken down into:
  - `commands/executor.ex` - Main entry point for command execution
  - `commands/parser.ex` - Parameter parsing utilities
  - `commands/modes.ex` - Mode setting/resetting handlers
  - `commands/screen.ex` - Screen manipulation functions

### In-Progress Refactoring

- **Configuration Module**: Breaking down `configuration.ex` (2394 lines) into modules in the `config/` directory.

### Upcoming Refactoring

- **Screen Buffer**: Breaking down `screen_buffer.ex` (1129 lines)
- **Emulator**: Reorganizing `emulator.ex` (911 lines)
- **Parser**: Refactoring `parser.ex` (1013 lines)

During this transition, we maintain backward compatibility through facade modules and deprecation warnings to guide users to the new APIs.

## Components

### Terminal Emulator

The core terminal emulator (`Raxol.Terminal.Emulator`) provides basic terminal functionality:

- Screen buffer management
- Cursor movement
- Text input handling
- Scrolling functionality
- ANSI escape code processing

### Buffer Manager

The buffer manager (`Raxol.Terminal.Buffer.Manager`) handles screen content:

- Double buffering for efficient screen updates
- Damage tracking for optimized rendering
- Memory-efficient buffer management
- Buffer compression and cleanup

### Scroll Buffer

The scroll buffer (`Raxol.Terminal.Buffer.Scroll`) manages terminal history:

- Virtual scrolling with configurable history size
- Memory-efficient storage of terminal content
- Viewport management for visible content
- Scroll position tracking

### Cursor Manager

The cursor manager (`Raxol.Terminal.Cursor.Manager`) handles cursor behavior:

- Multiple cursor styles (block, underline, bar, custom)
- Cursor state persistence
- Cursor animation system
- Position tracking and bounds checking

### Integration Layer

The integration layer (`Raxol.Terminal.Integration`) connects all components:

- Initializes and manages all terminal components
- Synchronizes buffer and cursor states
- Handles terminal operations
- Manages memory and performance optimizations

## Usage

### Basic Terminal Operations

```elixir
# Create a new terminal with default settings (80x24)
terminal = Raxol.Terminal.Integration.new(80, 24)

# Write text to the terminal
terminal = Raxol.Terminal.Integration.write(terminal, "Hello, World!")

# Move the cursor
terminal = Raxol.Terminal.Integration.move_cursor(terminal, 10, 5)

# Clear the screen
terminal = Raxol.Terminal.Integration.clear_screen(terminal)

# Scroll the terminal
terminal = Raxol.Terminal.Integration.scroll(terminal, 5)
```

### Cursor Management

```elixir
# Set cursor style
terminal = Raxol.Terminal.Integration.set_cursor_style(terminal, :underline)

# Show/hide cursor
terminal = Raxol.Terminal.Integration.hide_cursor(terminal)
terminal = Raxol.Terminal.Integration.show_cursor(terminal)

# Save and restore cursor position
terminal = Raxol.Terminal.Integration.save_cursor(terminal)
terminal = Raxol.Terminal.Integration.restore_cursor(terminal)
```

### Scroll Buffer Management

```elixir
# Get scroll position
position = Raxol.Terminal.Integration.get_scroll_position(terminal)

# Get scroll height
height = Raxol.Terminal.Integration.get_scroll_height(terminal)

# Get scroll view
view = Raxol.Terminal.Integration.get_scroll_view(terminal, 10)

# Clear scroll buffer
terminal = Raxol.Terminal.Integration.clear_scroll_buffer(terminal)
```

### Buffer Management

```elixir
# Get damage regions
regions = Raxol.Terminal.Integration.get_damage_regions(terminal)

# Clear damage regions
terminal = Raxol.Terminal.Integration.clear_damage_regions(terminal)

# Switch buffers
terminal = Raxol.Terminal.Integration.switch_buffers(terminal)
```

## Memory Management

The integration layer includes built-in memory management:

- Tracks memory usage across all components
- Enforces memory limits
- Performs automatic cleanup when needed
- Compresses buffer content when memory usage is high

```elixir
# Update memory usage tracking
terminal = Raxol.Terminal.Integration.update_memory_usage(terminal)

# Check if within memory limits
within_limits? = Raxol.Terminal.Integration.within_memory_limits?(terminal)
```

## Performance Considerations

1. **Double Buffering**

   - Reduces screen flicker
   - Optimizes rendering performance
   - Minimizes memory allocations

2. **Damage Tracking**

   - Only updates changed screen regions
   - Reduces unnecessary redraws
   - Improves rendering efficiency

3. **Memory Management**

   - Automatic cleanup of unused buffers
   - Compression of historical content
   - Configurable memory limits

4. **Scroll Buffer Optimization**
   - Virtual scrolling for large histories
   - Efficient storage of terminal content
   - Smart viewport management

## Testing

The terminal system includes comprehensive tests:

- Unit tests for each component
- Integration tests for component interaction
- Performance tests for memory usage
- Stress tests for large content handling

Run the tests with:

```bash
mix test
```

## Future Enhancements

1. **Advanced Terminal Features**

   - Multiple terminal windows
   - Split screen support
   - Tab management
   - Session persistence

2. **Performance Improvements**

   - GPU acceleration
   - Hardware rendering
   - Async buffer updates
   - Predictive scrolling

3. **User Experience**

   - Custom themes
   - Configurable key bindings
   - Plugin system
   - Extension API

4. **Development Tools**
   - Debug mode
   - Performance profiling
   - Memory usage visualization
   - Terminal state inspection

# Raxol Terminal Module

This module provides terminal emulation functionality for the Raxol framework.

## Known Issues

### Credo Warning: stdin Parsing

When running Credo, you may see the following warning:

```
info: Some source files could not be parsed correctly and are excluded:
   1) lib/raxol/terminal/input_handler.ex
```

This is a known issue with Credo's parsing of stdin-related code. It doesn't affect the functionality of the terminal emulator and can be safely ignored.

#### Why This Happens

The terminal emulator processes input from stdin, which Credo sometimes has trouble parsing correctly. This is a limitation of Credo's static analysis and not a problem with the code itself.

#### How to Handle It

1. **Ignore the warning**: The warning is informational and doesn't indicate a problem with your code.

2. **Exclude the file from Credo analysis**: If you want to suppress the warning, you can add the following to your `.credo.exs` file:

```elixir
files: %{
  excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/", ~r"input_handler\.ex$"]
}
```

3. **Use a local Credo config**: You can also create a `.credo.exs` file in the `lib/raxol/terminal` directory to exclude the file from analysis:

```elixir
%{
  configs: [
    %{
      name: "terminal",
      files: %{
        excluded: [~r"input_handler\.ex$"]
      },
      checks: []
    }
  ]
}
```

## Terminal Emulator Features

The terminal emulator provides the following features:

- Character handling (wide characters, bidirectional text, combining characters)
- Screen buffer management
- Cursor positioning and styling
- Input handling
- Clipboard operations
- Tab completion
- Terminal modes and escape sequences

## Usage

```elixir
# Create a new terminal emulator
emulator = Raxol.Terminal.Emulator.new(80, 24)

# Process input
{emulator, _} = Raxol.Terminal.Emulator.process_input(emulator, "Hello, World!")

# Get the screen buffer contents
buffer = Raxol.Terminal.Emulator.get_buffer(emulator)
```
