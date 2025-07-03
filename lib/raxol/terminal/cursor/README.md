# Raxol Terminal Cursor System

This directory contains the implementation of the Raxol terminal cursor system, which provides advanced cursor management capabilities.

## Components

### Cursor Manager (`manager.ex`)

The cursor manager handles cursor styles, state persistence, and animations. It provides a flexible system for managing cursor appearance and behavior.

Key features:

- Multiple cursor styles (block, underline, bar, custom)
- State persistence
- Animation system
- Position tracking

## Cursor Styles

The cursor manager supports the following cursor styles:

1. **Block**: A solid rectangle cursor (default)
2. **Underline**: A horizontal line cursor
3. **Bar**: A vertical line cursor
4. **Custom**: User-defined cursor shape

## Cursor States

The cursor can be in one of the following states:

1. **Visible**: The cursor is always visible
2. **Hidden**: The cursor is never visible
3. **Blinking**: The cursor alternates between visible and hidden

## Usage

### Basic Cursor Management

```elixir
# Create a new cursor manager
cursor = Raxol.Terminal.Cursor.Manager.new()

# Move the cursor
cursor = Raxol.Terminal.Cursor.Manager.move_to(cursor, 10, 5)

# Set cursor style
cursor = Raxol.Terminal.Cursor.Manager.set_style(cursor, :underline)

# Set cursor state
cursor = Raxol.Terminal.Cursor.Manager.set_state(cursor, :blinking)
```

### Custom Cursor Shapes

```elixir
# Create a new cursor manager
cursor = Raxol.Terminal.Cursor.Manager.new()

# Set a custom cursor shape
cursor = Raxol.Terminal.Cursor.Manager.set_custom_shape(cursor, "█", {2, 1})
```

### Cursor Animation

```elixir
# Create a new cursor manager
cursor = Raxol.Terminal.Cursor.Manager.new()

# Set cursor to blinking state
cursor = Raxol.Terminal.Cursor.Manager.set_state(cursor, :blinking)

# Update cursor blink state
{cursor, visible} = Raxol.Terminal.Cursor.Manager.update_blink(cursor)
```

### Cursor State Persistence

```elixir
# Create a new cursor manager
cursor = Raxol.Terminal.Cursor.Manager.new()

# Save cursor position
cursor = Raxol.Terminal.Cursor.Manager.save_position(cursor)

# Move cursor
cursor = Raxol.Terminal.Cursor.Manager.move_to(cursor, 10, 5)

# Restore saved position
cursor = Raxol.Terminal.Cursor.Manager.restore_position(cursor)
```

### Cursor History

```elixir
# Create a new cursor manager
cursor = Raxol.Terminal.Cursor.Manager.new()

# Add current state to history
cursor = Raxol.Terminal.Cursor.Manager.add_to_history(cursor)

# Move cursor and change style
cursor = Raxol.Terminal.Cursor.Manager.move_to(cursor, 10, 5)
cursor = Raxol.Terminal.Cursor.Manager.set_style(cursor, :underline)

# Restore from history
cursor = Raxol.Terminal.Cursor.Manager.restore_from_history(cursor)
```

## Animation System

The cursor animation system provides the following features:

1. **Blink Rate Control**: Configurable blink rate (default: 530ms)
2. **State Transitions**: Smooth transitions between cursor states
3. **Animation Timing**: Precise control over animation timing
4. **Visibility Control**: Fine-grained control over cursor visibility

## Performance Considerations

- The cursor manager uses minimal state to track cursor position and appearance
- Animation updates are efficient and only occur when needed
- State persistence is lightweight and doesn't impact performance
- History management is optimized for memory usage

## Testing

The cursor manager includes comprehensive tests in `test/raxol/terminal/cursor/manager_test.exs`.

Run the tests with:

```bash
mix test test/raxol/terminal/cursor/
```

## Future Enhancements

Planned enhancements for the cursor system:

1. **Advanced Animations**: More sophisticated cursor animations
2. **Cursor Effects**: Visual effects for cursor transitions
3. **Cursor Themes**: Themeable cursor styles
4. **Cursor Profiles**: Save and load cursor configurations
5. **Cursor Events**: Event system for cursor state changes
