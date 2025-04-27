---
title: Window Management Component
description: Documentation for the window management component in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [window, terminal, documentation]
---

# Window Management Component

The window management component handles terminal window creation, manipulation, and state management.

## Features

- Multiple window support
- Window splitting (horizontal/vertical)
- Window resizing
- Window focus management
- Window state persistence
- Window decorations
- Window events
- Window titles
- Window borders
- Window scrolling

## Usage

```elixir
# Create a new window manager
windows = Raxol.Terminal.Windows.new()

# Create a new window
{:ok, window_id} = Raxol.Terminal.Windows.create(windows, %{title: "Main"})

# Split window horizontally
{:ok, new_id} = Raxol.Terminal.Windows.split(windows, window_id, :horizontal)

# Resize window
windows = Raxol.Terminal.Windows.resize(windows, window_id, {80, 24})
```

## Configuration

The window manager can be configured with the following options:

```elixir
config = %{
  default_size: {80, 24},
  min_size: {10, 1},
  max_size: {200, 50},
  border_style: :single,
  title_style: :center,
  scroll_history: 1000,
  focus_follows_mouse: true
}

windows = Raxol.Terminal.Windows.new(config)
```

## Implementation Details

### Window Types

1. **Standard Windows**
   - Basic terminal window
   - Configurable size
   - Title bar
   - Scrollback buffer

2. **Split Windows**
   - Horizontal splits
   - Vertical splits
   - Nested splits
   - Proportional sizing

3. **Special Windows**
   - Modal dialogs
   - Floating windows
   - Status windows
   - Overlay windows

### Window Management

1. **Layout Management**
   - Tree-based layout
   - Dynamic resizing
   - Window constraints
   - Layout persistence

2. **Focus Management**
   - Focus tracking
   - Focus history
   - Focus events
   - Focus policies

### Window State

1. **Persistent State**
   - Window positions
   - Window sizes
   - Scroll positions
   - Window titles

2. **Visual State**
   - Border styles
   - Title styles
   - Active/inactive states
   - Minimized/maximized states

## API Reference

### Window Management

```elixir
# Initialize window manager
@spec new() :: t()

# Create window
@spec create(windows :: t(), options :: map()) :: {:ok, window_id()} | {:error, String.t()}

# Split window
@spec split(windows :: t(), window_id :: window_id(), direction :: :horizontal | :vertical) :: {:ok, window_id()} | {:error, String.t()}

# Close window
@spec close(windows :: t(), window_id :: window_id()) :: t()
```

### Window Operations

```elixir
# Resize window
@spec resize(windows :: t(), window_id :: window_id(), size :: {integer(), integer()}) :: t()

# Focus window
@spec focus(windows :: t(), window_id :: window_id()) :: t()

# Set window title
@spec set_title(windows :: t(), window_id :: window_id(), title :: String.t()) :: t()
```

### Window State

```elixir
# Get window state
@spec get_state(windows :: t(), window_id :: window_id()) :: map()

# Save window state
@spec save_state(windows :: t()) :: {:ok, String.t()} | {:error, String.t()}

# Load window state
@spec load_state(windows :: t(), state :: String.t()) :: {:ok, t()} | {:error, String.t()}
```

## Events

The window management component emits the following events:

- `:window_created` - When a new window is created
- `:window_closed` - When a window is closed
- `:window_resized` - When a window is resized
- `:window_focused` - When window focus changes
- `:window_title_changed` - When window title changes
- `:layout_changed` - When window layout changes

## Example

```elixir
defmodule MyTerminal do
  alias Raxol.Terminal.Windows

  def example do
    # Create a new window manager
    windows = Windows.new()

    # Create main window
    {:ok, main_id} = Windows.create(windows, %{
      title: "Main Terminal",
      size: {80, 24}
    })

    # Split main window horizontally
    {:ok, top_id} = Windows.split(windows, main_id, :horizontal)

    # Configure windows
    windows = windows
      |> Windows.resize(main_id, {80, 40})
      |> Windows.set_title(top_id, "Top Window")
      |> Windows.focus(top_id)

    # Save window state
    {:ok, state} = Windows.save_state(windows)

    # Later, restore state
    {:ok, windows} = Windows.load_state(Windows.new(), state)
  end
end
```

## Testing

The window management component includes comprehensive tests:

```elixir
defmodule Raxol.Terminal.WindowsTest do
  use ExUnit.Case
  alias Raxol.Terminal.Windows

  test "creates windows correctly" do
    windows = Windows.new()
    {:ok, window_id} = Windows.create(windows, %{title: "Test"})
    assert Windows.get_state(windows, window_id).title == "Test"
  end

  test "splits windows correctly" do
    windows = Windows.new()
    {:ok, main_id} = Windows.create(windows, %{})
    {:ok, split_id} = Windows.split(windows, main_id, :horizontal)
    assert Windows.get_state(windows, split_id) != nil
  end

  test "manages focus correctly" do
    windows = Windows.new()
    {:ok, id1} = Windows.create(windows, %{})
    {:ok, id2} = Windows.create(windows, %{})
    windows = Windows.focus(windows, id2)
    assert Windows.get_focused_window(windows) == id2
  end

  test "persists window state" do
    windows = Windows.new()
    {:ok, id} = Windows.create(windows, %{title: "Test"})
    {:ok, state} = Windows.save_state(windows)
    {:ok, loaded} = Windows.load_state(Windows.new(), state)
    assert Windows.get_state(loaded, id).title == "Test"
  end
end
``` 