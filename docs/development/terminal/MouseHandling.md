---
title: Mouse Handling Component
description: Documentation for the mouse handling component in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [mouse, terminal, documentation]
---

# Mouse Handling Component

The mouse handling component manages mouse input, events, and interactions in the terminal emulator.

## Features

- Mouse event handling
- Mouse tracking modes
- Button state tracking
- Scroll wheel support
- Mouse motion events
- Selection handling
- Drag and drop
- Mouse reporting
- Click handling
- Coordinate translation

## Usage

```elixir
# Create a new mouse handler
mouse = Raxol.Terminal.Mouse.new()

# Enable mouse tracking
mouse = Raxol.Terminal.Mouse.enable_tracking(mouse)

# Handle mouse event
{:ok, action} = Raxol.Terminal.Mouse.handle_event(mouse, {:click, 10, 20, :left})

# Get selection
{:ok, text} = Raxol.Terminal.Mouse.get_selection(mouse)
```

## Configuration

The mouse handler can be configured with the following options:

```elixir
config = %{
  tracking_mode: :normal,
  click_interval: 250,
  drag_threshold: 5,
  scroll_lines: 3,
  focus_follows_mouse: false,
  enable_selection: true,
  selection_mode: :cell,
  report_motion: true
}

mouse = Raxol.Terminal.Mouse.new(config)
```

## Implementation Details

### Mouse Event Types

1. **Button Events**

   - Left click
   - Right click
   - Middle click
   - Double click
   - Triple click

2. **Motion Events**

   - Mouse movement
   - Drag operations
   - Hover events
   - Motion tracking

3. **Wheel Events**
   - Vertical scroll
   - Horizontal scroll
   - Smooth scrolling
   - Scroll acceleration

### Mouse Management

1. **Event Processing**

   - Event filtering
   - Coordinate mapping
   - Button state tracking
   - Event queueing

2. **Selection Management**
   - Text selection
   - Block selection
   - Selection modes
   - Copy operations

### Mouse State

1. **Button State**

   - Button pressed
   - Button released
   - Modifier keys
   - Click count

2. **Position State**
   - Current position
   - Previous position
   - Start position
   - End position

## API Reference

### Mouse Management

```elixir
# Initialize mouse handler
@spec new() :: t()

# Enable mouse tracking
@spec enable_tracking(mouse :: t()) :: t()

# Disable mouse tracking
@spec disable_tracking(mouse :: t()) :: t()

# Set tracking mode
@spec set_mode(mouse :: t(), mode :: atom()) :: t()
```

### Event Handling

```elixir
# Handle mouse event
@spec handle_event(mouse :: t(), event :: mouse_event()) :: {:ok, action()} | :error

# Handle mouse motion
@spec handle_motion(mouse :: t(), x :: integer(), y :: integer()) :: t()

# Handle mouse wheel
@spec handle_wheel(mouse :: t(), delta :: integer(), direction :: :vertical | :horizontal) :: t()
```

### Selection Management

```elixir
# Start selection
@spec start_selection(mouse :: t(), x :: integer(), y :: integer()) :: t()

# Update selection
@spec update_selection(mouse :: t(), x :: integer(), y :: integer()) :: t()

# Get selection
@spec get_selection(mouse :: t()) :: {:ok, String.t()} | :error
```

## Events

The mouse handling component emits the following events:

- `:mouse_down` - When a mouse button is pressed
- `:mouse_up` - When a mouse button is released
- `:mouse_move` - When the mouse moves
- `:mouse_wheel` - When the mouse wheel is used
- `:selection_started` - When text selection begins
- `:selection_updated` - When text selection changes
- `:selection_completed` - When text selection ends

## Example

```elixir
defmodule MyTerminal do
  alias Raxol.Terminal.Mouse

  def example do
    # Create a new mouse handler
    mouse = Mouse.new()

    # Configure mouse handling
    mouse = mouse
      |> Mouse.enable_tracking()
      |> Mouse.set_mode(:normal)

    # Handle mouse events
    {:ok, action} = Mouse.handle_event(mouse, {:click, 10, 20, :left})
    mouse = Mouse.handle_motion(mouse, 15, 25)

    # Work with selections
    mouse = mouse
      |> Mouse.start_selection(10, 10)
      |> Mouse.update_selection(20, 10)

    # Get selected text
    {:ok, selected_text} = Mouse.get_selection(mouse)

    # Handle scroll events
    mouse = Mouse.handle_wheel(mouse, 1, :vertical)
  end
end
```

## Testing

The mouse handling component includes comprehensive tests:

```elixir
defmodule Raxol.Terminal.MouseTest do
  use ExUnit.Case
  alias Raxol.Terminal.Mouse

  test "handles mouse events correctly" do
    mouse = Mouse.new()
    mouse = Mouse.enable_tracking(mouse)
    {:ok, action} = Mouse.handle_event(mouse, {:click, 10, 20, :left})
    assert action == :select
  end

  test "manages selections correctly" do
    mouse = Mouse.new()
    mouse = Mouse.start_selection(mouse, 0, 0)
    mouse = Mouse.update_selection(mouse, 10, 0)
    {:ok, text} = Mouse.get_selection(mouse)
    assert text != nil
  end

  test "tracks mouse motion" do
    mouse = Mouse.new()
    mouse = Mouse.handle_motion(mouse, 5, 5)
    assert Mouse.get_position(mouse) == {5, 5}
  end

  test "handles wheel events" do
    mouse = Mouse.new()
    mouse = Mouse.handle_wheel(mouse, 1, :vertical)
    assert Mouse.get_scroll_position(mouse) == 1
  end

  test "manages tracking modes" do
    mouse = Mouse.new()
    mouse = Mouse.set_mode(mouse, :normal)
    assert Mouse.get_mode(mouse) == :normal
  end
end
```
