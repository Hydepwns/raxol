---
title: Keyboard Mapping Component
description: Documentation for the keyboard mapping component in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [keyboard, terminal, documentation]
---

# Keyboard Mapping Component

The keyboard mapping component handles keyboard input mapping, key bindings, and keyboard layouts.

## Features

- Custom key bindings
- Multiple keyboard layouts
- Modifier key support
- Function key mapping
- Key sequence handling
- Macro recording
- Key event filtering
- Key code translation
- Input mode switching
- Hotkey configuration

## Usage

```elixir
# Create a new keyboard mapper
keyboard = Raxol.Terminal.Keyboard.new()

# Add key binding
keyboard = Raxol.Terminal.Keyboard.bind_key(keyboard, "ctrl+c", :copy)

# Handle key event
{:ok, action} = Raxol.Terminal.Keyboard.handle_key(keyboard, "ctrl+v")

# Record macro
:ok = Raxol.Terminal.Keyboard.start_macro(keyboard, "macro1")
```

## Configuration

The keyboard mapper can be configured with the following options:

```elixir
config = %{
  layout: :us_qwerty,
  repeat_delay: 500,
  repeat_rate: 30,
  enable_numlock: true,
  enable_capslock: true,
  enable_scrolllock: true,
  macro_timeout: 5000
}

keyboard = Raxol.Terminal.Keyboard.new(config)
```

## Implementation Details

### Key Mapping Types

1. **Basic Mappings**

   - Single key mappings
   - Modifier combinations
   - Function keys
   - Special keys

2. **Complex Mappings**

   - Key sequences
   - Chord combinations
   - Mode-specific bindings
   - Context-sensitive mappings

3. **Special Handlers**
   - System shortcuts
   - Application hotkeys
   - Terminal control
   - Input method handling

### Keyboard Management

1. **Layout Management**

   - Physical layouts
   - Logical layouts
   - Layout switching
   - Custom layouts

2. **Input Processing**
   - Key event filtering
   - Key code translation
   - Modifier tracking
   - Repeat handling

### Keyboard State

1. **Global State**

   - Current layout
   - Lock keys state
   - Modifier state
   - Macro state

2. **Mode State**
   - Input mode
   - Key map mode
   - Recording state
   - Repeat state

## API Reference

### Key Binding Management

```elixir
# Initialize keyboard mapper
@spec new() :: t()

# Bind key to action
@spec bind_key(keyboard :: t(), key :: String.t(), action :: atom() | function()) :: t()

# Unbind key
@spec unbind_key(keyboard :: t(), key :: String.t()) :: t()

# Get key binding
@spec get_binding(keyboard :: t(), key :: String.t()) :: {:ok, atom() | function()} | :error
```

### Input Handling

```elixir
# Handle key event
@spec handle_key(keyboard :: t(), key :: String.t()) :: {:ok, atom()} | :error

# Handle key sequence
@spec handle_sequence(keyboard :: t(), keys :: [String.t()]) :: {:ok, atom()} | :error

# Set input mode
@spec set_mode(keyboard :: t(), mode :: atom()) :: t()
```

### Macro Management

```elixir
# Start macro recording
@spec start_macro(keyboard :: t(), name :: String.t()) :: :ok | {:error, String.t()}

# Stop macro recording
@spec stop_macro(keyboard :: t()) :: {:ok, String.t()} | {:error, String.t()}

# Play macro
@spec play_macro(keyboard :: t(), name :: String.t()) :: :ok | {:error, String.t()}
```

## Events

The keyboard mapping component emits the following events:

- `:key_pressed` - When a key is pressed
- `:key_released` - When a key is released
- `:binding_triggered` - When a key binding is activated
- `:mode_changed` - When input mode changes
- `:macro_started` - When macro recording starts
- `:macro_stopped` - When macro recording stops
- `:layout_changed` - When keyboard layout changes

## Example

```elixir
defmodule MyTerminal do
  alias Raxol.Terminal.Keyboard

  def example do
    # Create a new keyboard mapper
    keyboard = Keyboard.new()

    # Configure key bindings
    keyboard = keyboard
      |> Keyboard.bind_key("ctrl+c", :copy)
      |> Keyboard.bind_key("ctrl+v", :paste)
      |> Keyboard.bind_key("ctrl+z", :undo)

    # Create a custom macro
    :ok = Keyboard.start_macro(keyboard, "format")
    Keyboard.handle_key(keyboard, "ctrl+a")
    Keyboard.handle_key(keyboard, "ctrl+i")
    {:ok, macro} = Keyboard.stop_macro(keyboard)

    # Handle input in different modes
    keyboard = Keyboard.set_mode(keyboard, :insert)
    {:ok, action} = Keyboard.handle_key(keyboard, "ctrl+v")

    # Work with key sequences
    {:ok, action} = Keyboard.handle_sequence(keyboard, ["escape", ":", "w", "q"])
  end
end
```

## Testing

The keyboard mapping component includes comprehensive tests:

```elixir
defmodule Raxol.Terminal.KeyboardTest do
  use ExUnit.Case
  alias Raxol.Terminal.Keyboard

  test "binds keys correctly" do
    keyboard = Keyboard.new()
    keyboard = Keyboard.bind_key(keyboard, "ctrl+c", :copy)
    assert {:ok, :copy} = Keyboard.get_binding(keyboard, "ctrl+c")
  end

  test "handles key events correctly" do
    keyboard = Keyboard.new()
    keyboard = Keyboard.bind_key(keyboard, "ctrl+x", :cut)
    assert {:ok, :cut} = Keyboard.handle_key(keyboard, "ctrl+x")
  end

  test "manages macros correctly" do
    keyboard = Keyboard.new()
    :ok = Keyboard.start_macro(keyboard, "test")
    Keyboard.handle_key(keyboard, "a")
    {:ok, macro} = Keyboard.stop_macro(keyboard)
    assert macro != nil
  end

  test "handles input modes correctly" do
    keyboard = Keyboard.new()
    keyboard = Keyboard.set_mode(keyboard, :normal)
    assert Keyboard.get_mode(keyboard) == :normal
  end

  test "processes key sequences correctly" do
    keyboard = Keyboard.new()
    keyboard = Keyboard.bind_key(keyboard, "ctrl+k j", :jump)
    assert {:ok, :jump} = Keyboard.handle_sequence(keyboard, ["ctrl+k", "j"])
  end
end
```
