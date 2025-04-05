---
title: Cursor Component
description: Documentation for the cursor component in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [cursor, terminal, documentation]
---

# Cursor Component

The cursor component manages the terminal cursor's position, style, and behavior.

## Features

- Multiple cursor styles (block, underline, bar)
- Cursor state persistence
- Animation system for blinking
- Position bounds checking
- Style transitions
- Visibility control

## Usage

```elixir
# Create a new cursor
cursor = Raxol.Terminal.Cursor.new()

# Move the cursor
cursor = Raxol.Terminal.Cursor.move_to(cursor, 10, 5)

# Change cursor style
cursor = Raxol.Terminal.Cursor.set_style(cursor, :block)

# Toggle cursor visibility
cursor = Raxol.Terminal.Cursor.set_visible(cursor, false)
```

## Configuration

The cursor component can be configured with the following options:

```elixir
config = %{
  style: :block,
  blink_rate: 500,
  visible: true,
  color: :white,
  background_color: :black
}

cursor = Raxol.Terminal.Cursor.new(config)
```

## Implementation Details

### Cursor Styles

The cursor supports three main styles:

1. **Block**
   - Full character cell
   - Can be filled or outlined
   - Supports background color

2. **Underline**
   - Single line under character
   - Configurable thickness
   - Supports color

3. **Bar**
   - Vertical bar
   - Configurable width
   - Supports color

### Animation System

The cursor implements a flexible animation system:

1. **Blinking**
   - Configurable blink rate
   - Smooth transitions
   - State persistence

2. **Style Transitions**
   - Smooth transitions between styles
   - Configurable duration
   - Multiple transition types

## API Reference

### Basic Operations

```elixir
# Initialize a new cursor
@spec new() :: t()

# Move cursor to position
@spec move_to(cursor :: t(), x :: integer, y :: integer) :: t()

# Set cursor style
@spec set_style(cursor :: t(), style :: :block | :underline | :bar) :: t()

# Set cursor visibility
@spec set_visible(cursor :: t(), visible :: boolean) :: t()
```

### Animation

```elixir
# Start cursor blinking
@spec start_blink(cursor :: t()) :: t()

# Stop cursor blinking
@spec stop_blink(cursor :: t()) :: t()

# Set blink rate
@spec set_blink_rate(cursor :: t(), rate :: integer) :: t()
```

### State Management

```elixir
# Save cursor state
@spec save_state(cursor :: t()) :: t()

# Restore cursor state
@spec restore_state(cursor :: t()) :: t()

# Reset cursor to initial state
@spec reset(cursor :: t()) :: t()
```

## Events

The cursor component emits the following events:

- `:cursor_moved` - When the cursor position changes
- `:style_changed` - When the cursor style changes
- `:visibility_changed` - When the cursor visibility changes
- `:blink_state_changed` - When the cursor blink state changes

## Example

```elixir
defmodule MyTerminal do
  alias Raxol.Terminal.Cursor

  def example do
    # Create a new cursor
    cursor = Cursor.new()

    # Configure the cursor
    cursor = cursor
      |> Cursor.set_style(:block)
      |> Cursor.set_blink_rate(500)
      |> Cursor.start_blink()

    # Move the cursor
    cursor = cursor
      |> Cursor.move_to(10, 5)
      |> Cursor.set_visible(true)

    # Save the cursor state
    cursor = Cursor.save_state(cursor)
  end
end
```

## Testing

The cursor component includes comprehensive tests:

```elixir
defmodule Raxol.Terminal.CursorTest do
  use ExUnit.Case
  alias Raxol.Terminal.Cursor

  test "initializes correctly" do
    cursor = Cursor.new()
    assert cursor.x == 0
    assert cursor.y == 0
    assert cursor.style == :block
  end

  test "moves correctly" do
    cursor = Cursor.new()
    cursor = Cursor.move_to(cursor, 10, 5)
    assert cursor.x == 10
    assert cursor.y == 5
  end

  test "changes style correctly" do
    cursor = Cursor.new()
    cursor = Cursor.set_style(cursor, :underline)
    assert cursor.style == :underline
  end
end
``` 