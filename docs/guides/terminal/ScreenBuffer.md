---
title: Screen Buffer Component
description: Documentation for the screen buffer component in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [screen buffer, terminal, documentation]
---

# Screen Buffer Component

The screen buffer component is responsible for managing the terminal's screen buffer, including character storage, scrolling, and viewport management.

## Features

- Double buffering for smooth rendering
- Damage tracking for efficient updates
- Virtual scrolling with configurable history
- Memory-efficient storage with compression
- Viewport management
- Selection handling
- Buffer state persistence
- Enhanced compression algorithms
- Asynchronous buffer updates
- Performance monitoring and optimization

## Usage

```elixir
# Create a new screen buffer
buffer = Raxol.Terminal.ScreenBuffer.new(80, 24)

# Write characters to the buffer
buffer = Raxol.Terminal.ScreenBuffer.write_char(buffer, "Hello, World!")

# Scroll the buffer
buffer = Raxol.Terminal.ScreenBuffer.scroll(buffer, 1)

# Get buffer content
content = Raxol.Terminal.ScreenBuffer.get_content(buffer)

# Use enhanced buffer manager for advanced features
manager = Raxol.Terminal.Buffer.EnhancedManager.new(80, 24, [
  compression_algorithm: :simple,
  compression_threshold: 1024
])

# Compress buffer to reduce memory usage
manager = Raxol.Terminal.Buffer.EnhancedManager.compress_buffer(manager)
```

## Configuration

The screen buffer component can be configured with the following options:

```elixir
config = %{
  width: 80,
  height: 24,
  history_size: 1000,
  compression_enabled: true,
  damage_tracking_enabled: true
}

buffer = Raxol.Terminal.ScreenBuffer.new(config)

# Enhanced manager configuration
enhanced_config = [
  compression_algorithm: :simple,  # :simple, :run_length, :lz4
  compression_level: 6,
  compression_threshold: 1024,
  pool_size: 100
]

manager = Raxol.Terminal.Buffer.EnhancedManager.new(80, 24, enhanced_config)
```

## Implementation Details

### Buffer Structure

The screen buffer uses a two-dimensional array of cells, where each cell contains:

- Character content
- Foreground color
- Background color
- Text attributes
- Width information (for wide characters)

### Memory Management

The buffer implements several memory optimization techniques:

1. **Compression**

   - Historical content is compressed
   - Repeated characters are stored efficiently
   - Empty lines are optimized
   - Multiple compression algorithms supported:
     - Simple compression for empty cell optimization
     - Run-length encoding for repeated characters
     - LZ4 compression (framework ready)
   - Style attribute minimization
   - Threshold-based compression activation

2. **Damage Tracking**

   - Only modified regions are updated
   - Changes are batched for efficiency
   - Minimal memory allocation during updates

3. **Enhanced Features**

   - Asynchronous buffer updates
   - Buffer pooling for efficient memory management
   - Performance monitoring and optimization
   - Automatic compression state updates

### Compression Algorithms

The enhanced buffer manager supports multiple compression strategies:

- **Simple Compression**: Optimizes empty cells and reduces style redundancy
- **Run-length Encoding**: Groups identical consecutive cells for better compression
- **LZ4 Compression**: High-performance compression algorithm (framework ready)
- **Style Minimization**: Removes default style attributes to save memory

### Performance Monitoring

The enhanced buffer manager tracks various performance metrics:

- Update operation timing
- Compression operation timing
- Memory usage statistics
- Operation counts
- Compression ratios

These metrics enable automatic optimization and performance tuning.

## API Reference

### Basic Operations

```elixir
# Initialize a new buffer
@spec new(width :: integer, height :: integer) :: t()

# Write a character to the buffer
@spec write_char(buffer :: t(), char :: String.t()) :: t()

# Write a string to the buffer
@spec write_string(buffer :: t(), string :: String.t()) :: t()

# Clear the buffer
@spec clear(buffer :: t()) :: t()
```

### Scrolling

```elixir
# Scroll the buffer by N lines
@spec scroll(buffer :: t(), lines :: integer) :: t()

# Set the scroll region
@spec set_scroll_region(buffer :: t(), top :: integer, bottom :: integer) :: t()

# Get the current scroll position
@spec get_scroll_position(buffer :: t()) :: integer
```

### Selection

```elixir
# Start selection
@spec start_selection(buffer :: t(), x :: integer, y :: integer) :: t()

# End selection
@spec end_selection(buffer :: t(), x :: integer, y :: integer) :: t()

# Get selected content
@spec get_selection(buffer :: t()) :: String.t()
```

### State Management

```elixir
# Save buffer state
@spec save_state(buffer :: t()) :: t()

# Restore buffer state
@spec restore_state(buffer :: t()) :: t()

# Reset buffer to initial state
@spec reset(buffer :: t()) :: t()
```

## Events

The screen buffer component emits the following events:

- `:buffer_updated` - When the buffer content changes
- `:scroll_changed` - When the scroll position changes
- `:selection_changed` - When the selection changes
- `:viewport_changed` - When the viewport changes

## Example

```elixir
defmodule MyTerminal do
  alias Raxol.Terminal.ScreenBuffer

  def example do
    # Create a new buffer
    buffer = ScreenBuffer.new(80, 24)

    # Write some content
    buffer = buffer
      |> ScreenBuffer.write_string("Hello, ")
      |> ScreenBuffer.write_string("World!")

    # Scroll down one line
    buffer = ScreenBuffer.scroll(buffer, 1)

    # Get the buffer content
    content = ScreenBuffer.get_content(buffer)

    # Print the content
    IO.puts(content)
  end
end
```

## Testing

The screen buffer component includes comprehensive tests:

```elixir
defmodule Raxol.Terminal.ScreenBufferTest do
  use ExUnit.Case
  alias Raxol.Terminal.ScreenBuffer

  test "initializes correctly" do
    buffer = ScreenBuffer.new(80, 24)
    assert buffer.width == 80
    assert buffer.height == 24
  end

  test "writes characters correctly" do
    buffer = ScreenBuffer.new(80, 24)
    buffer = ScreenBuffer.write_char(buffer, "A")
    assert ScreenBuffer.get_char(buffer, 0, 0) == "A"
  end
end
```
