---
title: Scroll Management
description: Documentation for scroll management in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [components, scroll, management]
---

# Scroll Management Component

The scroll management component handles scrolling behavior, scroll history, and viewport management in the terminal emulator.

## Features

- Smooth scrolling
- Scroll history
- Line-based scrolling
- Page-based scrolling
- Scroll markers
- Scroll position tracking
- Viewport management
- Scroll synchronization
- Scroll acceleration
- Scroll events

## Usage

```elixir
# Create a new scroll manager
scroll = Raxol.Terminal.Scroll.new()

# Scroll by lines
:ok = Raxol.Terminal.Scroll.scroll_lines(scroll, 5)

# Scroll to position
:ok = Raxol.Terminal.Scroll.scroll_to(scroll, 100)

# Get scroll position
{:ok, position} = Raxol.Terminal.Scroll.get_position(scroll)
```

## Configuration

The scroll manager can be configured with the following options:

```elixir
config = %{
  history_size: 10000,
  smooth_scroll: true,
  scroll_speed: 1.0,
  acceleration: true,
  page_size: 24,
  scroll_step: 3,
  margin_top: 2,
  margin_bottom: 2,
  sync_cursors: true,
  preserve_view: true
}

scroll = Raxol.Terminal.Scroll.new(config)
```

## Implementation Details

### Scroll Types

1. **Basic Scrolling**
   - Line scrolling
   - Page scrolling
   - Smooth scrolling
   - Jump scrolling

2. **Special Scrolling**
   - Selection scrolling
   - Search result scrolling
   - Mark-based scrolling
   - Synchronized scrolling

3. **Viewport Management**
   - View positioning
   - View boundaries
   - View constraints
   - View updates

### Scroll Management

1. **History Management**
   - History buffer
   - History limits
   - History markers
   - History cleanup

2. **Position Management**
   - Position tracking
   - Position limits
   - Position markers
   - Position events

### Scroll State

1. **Viewport State**
   - View position
   - View size
   - View bounds
   - View content

2. **History State**
   - Buffer content
   - Buffer size
   - Buffer markers
   - Buffer limits

## API Reference

### Scroll Management

```elixir
# Initialize scroll manager
@spec new() :: t()

# Scroll by lines
@spec scroll_lines(scroll :: t(), lines :: integer()) :: :ok | {:error, String.t()}

# Scroll by pages
@spec scroll_pages(scroll :: t(), pages :: integer()) :: :ok | {:error, String.t()}

# Scroll to position
@spec scroll_to(scroll :: t(), position :: integer()) :: :ok | {:error, String.t()}
```

### Position Management

```elixir
# Get current position
@spec get_position(scroll :: t()) :: {:ok, integer()} | :error

# Set position
@spec set_position(scroll :: t(), position :: integer()) :: t()

# Reset position
@spec reset_position(scroll :: t()) :: t()
```

### History Management

```elixir
# Get history size
@spec get_history_size(scroll :: t()) :: integer()

# Clear history
@spec clear_history(scroll :: t()) :: :ok

# Add marker
@spec add_marker(scroll :: t(), position :: integer(), label :: String.t()) :: t()
```

## Events

The scroll management component emits the following events:

- `:scroll_started` - When scrolling begins
- `:scroll_updated` - When scroll position changes
- `:scroll_ended` - When scrolling ends
- `:position_changed` - When view position changes
- `:history_updated` - When scroll history changes
- `:marker_added` - When scroll marker is added
- `:viewport_changed` - When viewport changes

## Example

```elixir
defmodule MyTerminal do
  alias Raxol.Terminal.Scroll

  def example do
    # Create a new scroll manager
    scroll = Scroll.new()

    # Configure scrolling
    scroll = scroll
      |> Scroll.set_history_size(10000)
      |> Scroll.set_scroll_speed(1.5)
      |> Scroll.enable_smooth_scroll()

    # Perform scrolling operations
    :ok = Scroll.scroll_lines(scroll, 10)
    :ok = Scroll.scroll_pages(scroll, -1)
    :ok = Scroll.scroll_to(scroll, 500)

    # Work with position
    {:ok, pos} = Scroll.get_position(scroll)
    scroll = Scroll.set_position(scroll, pos + 100)

    # Manage markers
    scroll = scroll
      |> Scroll.add_marker(100, "Start")
      |> Scroll.add_marker(500, "Middle")
      |> Scroll.add_marker(900, "End")

    # Navigate using markers
    {:ok, marker} = Scroll.find_marker(scroll, "Middle")
    :ok = Scroll.scroll_to_marker(scroll, marker)

    # Handle viewport
    viewport = Scroll.get_viewport(scroll)
    scroll = Scroll.update_viewport(scroll, %{
      top: viewport.top + 10,
      height: viewport.height
    })
  end
end
```

## Testing

The scroll management component includes comprehensive tests:

```elixir
defmodule Raxol.Terminal.ScrollTest do
  use ExUnit.Case
  alias Raxol.Terminal.Scroll

  test "scrolls by lines correctly" do
    scroll = Scroll.new()
    :ok = Scroll.scroll_lines(scroll, 5)
    {:ok, pos} = Scroll.get_position(scroll)
    assert pos == 5
  end

  test "scrolls by pages correctly" do
    scroll = Scroll.new()
    :ok = Scroll.scroll_pages(scroll, 1)
    {:ok, pos} = Scroll.get_position(scroll)
    assert pos == 24  # default page size
  end

  test "manages scroll position" do
    scroll = Scroll.new()
    scroll = Scroll.set_position(scroll, 100)
    {:ok, pos} = Scroll.get_position(scroll)
    assert pos == 100
  end

  test "handles markers correctly" do
    scroll = Scroll.new()
    scroll = Scroll.add_marker(scroll, 50, "test")
    {:ok, marker} = Scroll.find_marker(scroll, "test")
    assert marker.position == 50
  end

  test "manages viewport correctly" do
    scroll = Scroll.new()
    viewport = Scroll.get_viewport(scroll)
    scroll = Scroll.update_viewport(scroll, %{top: 10})
    new_viewport = Scroll.get_viewport(scroll)
    assert new_viewport.top == 10
  end
end
``` 