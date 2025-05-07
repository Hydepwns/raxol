# Raxol Terminal Buffer System

This directory contains the implementation of the Raxol terminal buffer system, which provides advanced screen buffer and cursor management capabilities.

## Components

The buffer system is composed of several modules, each handling specific responsibilities:

### State Management & Core

- **State (`state.ex`)**: Defines the core `State.t()` struct representing the buffer's grid (lines of Cells), dimensions, default style, scroll region, etc. Provides basic state accessors.
- **Manager (`manager.ex`)**: A `GenServer` that coordinates the overall buffer system. It manages the active/back buffers (`State.t()`), the scrollback buffer (`Scrollback.t()`), damage tracking (`DamageTracker.t()`), cursor position, and memory usage. It orchestrates operations performed by the specialized modules below.
- **Updater (`updater.ex`)**: Handles low-level updates to the buffer state, such as setting individual cells or entire lines.
- **Utils (`utils.ex`)**: Provides miscellaneous helper functions used by various buffer modules (e.g., creating blank lines).

### Buffer Operations

- **Writer (`writer.ex`)**: Handles writing characters and strings to the buffer state, including handling wide characters.
- **Eraser (`eraser.ex`)**: Handles erasing parts of the buffer state (specific regions, parts of lines, whole lines, screen areas).
- **Scroller (`scroller.ex`)**: Handles the logic for scrolling the buffer content up or down within the defined scroll region. Interacts with the Scrollback module.
- **LineEditor (`line_editor.ex`)**: Handles insertion and deletion of entire lines within the buffer state, respecting the scroll region.
- **CharEditor (`char_editor.ex`)**: Handles insertion and deletion of individual characters within a line, shifting subsequent characters as needed.

### Supporting Components

- **Scrollback (`scrollback.ex`)**: Manages the scrollback buffer, storing lines that scroll off the main view and providing them back when scrolling down. Handles the scrollback limit.
- **Selection (`selection.ex`)**: Manages the state of text selection within the buffer, including start/end points and retrieving selected text.
- **DamageTracker (`damage_tracker.ex`)**: Tracks "damaged" regions (areas that have changed and likely need redrawing) using an efficient data structure.
- **MemoryManager (`memory_manager.ex`)**: Provides functions to calculate the approximate memory usage of buffers and check usage against defined limits.

### Legacy / Facade

- **Operations (`operations.ex`)**: Previously contained implementations for many buffer operations. Now primarily acts as a facade, delegating most calls to the specialized modules listed above.

### (External Component)

- **Cursor Manager (`cursor/manager.ex`)**: Although located in a subdirectory, the cursor manager handles cursor styles, state persistence, and animations. It interacts with the buffer manager to get/set cursor position but is managed separately.

## Usage

### Buffer Manager

```elixir
# Create a new buffer manager
manager = Raxol.Terminal.Buffer.Manager.new(80, 24)

# Mark a region as damaged
manager = Raxol.Terminal.Buffer.Manager.mark_damaged(manager, 0, 0, 10, 5)

# Switch buffers
manager = Raxol.Terminal.Buffer.Manager.switch_buffers(manager)

# Check memory usage
manager = Raxol.Terminal.Buffer.Manager.update_memory_usage(manager)
if Raxol.Terminal.Buffer.Manager.within_memory_limits?(manager) do
  # Continue processing
end
```

### Scrollback

```elixir
# Create a new scrollback buffer
scrollback = Raxol.Terminal.Buffer.Scrollback.new(1000)

# Add a line to the buffer
line = [%Raxol.Terminal.Cell{char: "A"}, %Raxol.Terminal.Cell{char: "B"}]
scrollback = Raxol.Terminal.Buffer.Scrollback.add_line(scrollback, line)

# Get lines from the scrollback (e.g., for scrolling down)
{lines_to_restore, scrollback} = Raxol.Terminal.Buffer.Scrollback.take_lines(scrollback, 5)

# Get scrollback size
size = Raxol.Terminal.Buffer.Scrollback.size(scrollback)
```

### Cursor Manager

```elixir
# Create a new cursor manager
cursor = Raxol.Terminal.Cursor.Manager.new()

# Move the cursor
cursor = Raxol.Terminal.Cursor.Manager.move_to(cursor, 10, 5)

# Set cursor style
cursor = Raxol.Terminal.Cursor.Manager.set_style(cursor, :underline)

# Set cursor state
cursor = Raxol.Terminal.Cursor.Manager.set_state(cursor, :blinking)

# Update cursor blink state
{cursor, visible} = Raxol.Terminal.Cursor.Manager.update_blink(cursor)
```

## Memory Management

The buffer system includes several memory optimization features:

1. **Double Buffering**: Only one buffer is actively rendered at a time, reducing memory pressure.
2. **Damage Tracking**: Only modified regions of the screen are updated, minimizing unnecessary operations.
3. **Buffer Compression**: The scroll buffer compresses data when memory usage exceeds limits.
4. **Memory Limits**: Configurable memory limits prevent excessive memory usage.

## Performance Considerations

- The buffer manager uses efficient data structures for damage tracking.
- The scroll buffer implements virtual scrolling to handle large buffers efficiently.
- The cursor manager uses minimal state to track cursor position and appearance.
- All components are designed to work together with minimal overhead.

## Testing

Each component includes comprehensive tests:

- `test/raxol/terminal/buffer/manager_test.exs`: Tests for the buffer manager
- `test/raxol/terminal/buffer/state_test.exs`: Tests for the buffer state
- `test/raxol/terminal/buffer/updater_test.exs`: Tests for the buffer updater
- `test/raxol/terminal/buffer/writer_test.exs`: Tests for the buffer writer
- `test/raxol/terminal/buffer/eraser_test.exs`: Tests for the buffer eraser
- `test/raxol/terminal/buffer/scroller_test.exs`: Tests for the buffer scroller
- `test/raxol/terminal/buffer/line_editor_test.exs`: Tests for the line editor
- `test/raxol/terminal/buffer/char_editor_test.exs`: Tests for the character editor
- `test/raxol/terminal/buffer/scrollback_test.exs`: Tests for the scrollback buffer
- `test/raxol/terminal/buffer/selection_test.exs`: Tests for the selection logic
- `test/raxol/terminal/buffer/damage_tracker_test.exs`: Tests for the damage tracker
- `test/raxol/terminal/buffer/memory_manager_test.exs`: Tests for the memory manager
- `test/raxol/terminal/buffer/utils_test.exs`: Tests for the buffer utilities
- `test/raxol/terminal/cursor/manager_test.exs`: Tests for the cursor manager (external)

Run the tests with:

```bash
mix test test/raxol/terminal/buffer/
mix test test/raxol/terminal/cursor/ # For the cursor manager
```

## Future Enhancements

Planned enhancements for the buffer system:

1. **Advanced Compression**: More sophisticated compression algorithms for the scroll buffer.
2. **Buffer Partitioning**: Split large buffers into smaller chunks for better memory management.
3. **Lazy Loading**: Load buffer content on demand to reduce initial memory usage.
4. **Buffer Persistence**: Save buffer state to disk for session restoration.
5. **Buffer Search**: Efficient text search within the buffer.
