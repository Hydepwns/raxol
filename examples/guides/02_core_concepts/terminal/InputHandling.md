---
title: Input Handling Component
description: Documentation for the input handling component in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [input, terminal, documentation]
---

# Input Handling Component

The input handling component manages keyboard and mouse input in the terminal emulator.

## Features

- Keyboard input processing
- Special key support
- Mouse event handling
- Input buffering
- Input history management
- Multiple input modes
- Input validation
- Input composition (IME support)
- Custom key bindings

## Usage

```elixir
# Create a new input handler
input = Raxol.Terminal.Input.new()

# Process keyboard input
{:ok, input, actions} = Raxol.Terminal.Input.process_key(input, "A")

# Handle mouse event
{:ok, input, actions} = Raxol.Terminal.Input.process_mouse(input, {:click, 10, 5})

# Get input history
history = Raxol.Terminal.Input.get_history(input)
```

## Configuration

The input handler can be configured with the following options:

```elixir
config = %{
  buffer_size: 1000,
  history_size: 100,
  input_mode: :normal,
  mouse_enabled: true,
  key_repeat_delay: 500,
  key_repeat_rate: 30
}

input = Raxol.Terminal.Input.new(config)
```

## Implementation Details

### Input Modes

1. **Normal Mode**

   - Character-by-character input
   - Special key handling
   - Command history

2. **Insert Mode**

   - Text insertion
   - Character overwriting
   - Auto-indent

3. **Command Mode**
   - Command parsing
   - Command history
   - Command completion

### Mouse Support

1. **Event Types**

   - Click
   - Double click
   - Triple click
   - Drag
   - Scroll
   - Hover

2. **Button Support**
   - Left button
   - Middle button
   - Right button
   - Scroll wheel
   - Extended buttons

### Input Buffering

1. **Buffer Types**

   - Character buffer
   - Key buffer
   - Command buffer
   - Mouse event buffer

2. **Buffer Management**
   - Overflow handling
   - Buffer synchronization
   - Buffer persistence

## API Reference

### Keyboard Input

```elixir
# Process key input
@spec process_key(input :: t(), key :: String.t()) :: {:ok, t(), [action()]} | {:error, String.t()}

# Process special key
@spec process_special_key(input :: t(), key :: atom()) :: {:ok, t(), [action()]} | {:error, String.t()}

# Get input buffer
@spec get_buffer(input :: t()) :: String.t()
```

### Mouse Input

```elixir
# Process mouse event
@spec process_mouse(input :: t(), event :: mouse_event()) :: {:ok, t(), [action()]} | {:error, String.t()}

# Enable/disable mouse support
@spec set_mouse_enabled(input :: t(), enabled :: boolean) :: t()

# Get mouse position
@spec get_mouse_position(input :: t()) :: {integer, integer}
```

### History Management

```elixir
# Add to history
@spec add_to_history(input :: t(), entry :: String.t()) :: t()

# Get history entries
@spec get_history(input :: t()) :: [String.t()]

# Clear history
@spec clear_history(input :: t()) :: t()
```

## Events

The input handler emits the following events:

- `:key_pressed` - When a key is pressed
- `:mouse_event` - When a mouse event occurs
- `:input_mode_changed` - When input mode changes
- `:history_updated` - When history is updated
- `:buffer_overflow` - When input buffer overflows

## Example

```elixir
defmodule MyTerminal do
  alias Raxol.Terminal.Input

  def example do
    # Create a new input handler
    input = Input.new()

    # Configure input handling
    input = input
      |> Input.set_input_mode(:normal)
      |> Input.set_mouse_enabled(true)
      |> Input.set_buffer_size(1000)

    # Process some input
    {:ok, input, actions} = input
      |> Input.process_key("H")
      |> Input.process_key("e")
      |> Input.process_key("l")
      |> Input.process_key("l")
      |> Input.process_key("o")

    # Handle mouse click
    {:ok, input, actions} = Input.process_mouse(input, {:click, 10, 5})

    # Get input history
    history = Input.get_history(input)
  end
end
```

## Testing

The input handler includes comprehensive tests:

```elixir
defmodule Raxol.Terminal.InputTest do
  use ExUnit.Case
  alias Raxol.Terminal.Input

  test "processes key input correctly" do
    input = Input.new()
    {:ok, input, actions} = Input.process_key(input, "A")
    assert Enum.member?(actions, {:insert_char, "A"})
  end

  test "processes mouse event correctly" do
    input = Input.new()
    {:ok, input, actions} = Input.process_mouse(input, {:click, 10, 5})
    assert Enum.member?(actions, {:mouse_click, 10, 5})
  end

  test "manages history correctly" do
    input = Input.new()
    input = Input.add_to_history(input, "command1")
    history = Input.get_history(input)
    assert Enum.member?(history, "command1")
  end
end
```

## Component Input APIs and Harmonization

Modern Raxol input components, such as `MultiLineInput`, now follow a harmonized API and set of conventions for props, theming, and event handling. This harmonization ensures a consistent developer experience and predictable behavior across all major input components.

### Key Features of the Harmonized API

- **Unified Props:** Standardized support for `value`, `placeholder`, `width`, `height`, `wrap`, `style`, `theme`, `aria_label`, `tooltip`, and `on_change` props.
- **Consistent Theming:** All input components now accept a `theme` prop and support the latest theming system, making it easy to apply custom or application-wide themes.
- **Event Handling:** The `on_change` prop and related event handlers follow a consistent signature and behavior across components.
- **Accessibility:** Props like `aria_label` and `tooltip` are supported for improved accessibility and user guidance.
- **Extensibility:** The harmonized API makes it easier to extend or compose input components in custom UIs.

For detailed information about MultiLineInput and other input components, see [Input Components Reference](../../03_component_reference/inputs/README.md#text-inputs).

> **Note:** Legacy input components may not support all harmonized props or conventions. It is recommended to use the modern, harmonized components for new development.
