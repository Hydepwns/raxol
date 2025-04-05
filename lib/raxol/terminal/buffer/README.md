# Raxol Terminal Buffer System

This directory contains the implementation of the Raxol terminal buffer system, which provides advanced screen buffer and cursor management capabilities.

## Components

### Buffer Manager (`manager.ex`)

The buffer manager handles double buffering and damage tracking for the terminal screen. It maintains two buffers (active and back) and tracks which regions of the screen have been modified.

Key features:
- Double buffering implementation
- Damage tracking system
- Buffer synchronization
- Memory management

### Scroll Buffer (`scroll.ex`)

The scroll buffer provides virtual scrolling capabilities with memory-efficient buffer management. It handles large scrollback buffers by compressing data when memory usage exceeds limits.

Key features:
- Virtual scrolling implementation
- Memory-efficient buffer management
- Scroll position tracking
- Buffer compression

### Cursor Manager (`cursor/manager.ex`)

The cursor manager handles cursor styles, state persistence, and animations. It provides a flexible system for managing cursor appearance and behavior.

Key features:
- Multiple cursor styles (block, underline, bar, custom)
- State persistence
- Animation system
- Position tracking

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

### Scroll Buffer

```elixir
# Create a new scroll buffer
scroll = Raxol.Terminal.Buffer.Scroll.new(1000)

# Add a line to the buffer
line = [Cell.new("A"), Cell.new("B")]
scroll = Raxol.Terminal.Buffer.Scroll.add_line(scroll, line)

# Get a view of the buffer
view = Raxol.Terminal.Buffer.Scroll.get_view(scroll, 10)

# Scroll the buffer
scroll = Raxol.Terminal.Buffer.Scroll.scroll(scroll, 5)
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
- `test/raxol/terminal/buffer/scroll_test.exs`: Tests for the scroll buffer
- `test/raxol/terminal/cursor/manager_test.exs`: Tests for the cursor manager

Run the tests with:

```bash
mix test test/raxol/terminal/buffer/
mix test test/raxol/terminal/cursor/
```

## Future Enhancements

Planned enhancements for the buffer system:

1. **Advanced Compression**: More sophisticated compression algorithms for the scroll buffer.
2. **Buffer Partitioning**: Split large buffers into smaller chunks for better memory management.
3. **Lazy Loading**: Load buffer content on demand to reduce initial memory usage.
4. **Buffer Persistence**: Save buffer state to disk for session restoration.
5. **Buffer Search**: Efficient text search within the buffer. 