---
title: ANSI Processing Component
description: Documentation for the ANSI processing component in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [ansi, terminal, documentation]
---

# ANSI Processing Component

The ANSI processing component handles ANSI escape sequences for terminal control and formatting.

## Features

- Standard 16 colors
- 256-color mode
- 24-bit true color
- Text attributes (bold, italic, underline, etc.)
- Cursor movement
- Screen manipulation
- Character set switching (G0, G1, G2, G3)
- Screen modes (alternate screen buffer)
- Terminal state management
- Advanced text formatting (double-width/double-height characters)
- Device status reports
- Terminal identification responses
- Screen mode transitions
- Character set handling
- Extended mouse reporting modes
- Window manipulation sequences
- Sixel graphics support
- Column width changes (80/132-column modes)
- Auto-repeat mode
- Interlacing mode

## Usage

```elixir
# Create a new ANSI processor
ansi = Raxol.Terminal.ANSI.new()

# Process ANSI sequence
{:ok, ansi, actions} = Raxol.Terminal.ANSI.process_sequence(ansi, "\e[1;31m")

# Apply text attributes
ansi = Raxol.Terminal.ANSI.set_attributes(ansi, [:bold, :red])

# Handle cursor movement
ansi = Raxol.Terminal.ANSI.move_cursor(ansi, :up, 1)
```

## Configuration

The ANSI processor can be configured with the following options:

```elixir
config = %{
  color_mode: :true_color,
  mouse_mode: :extended,
  screen_mode: :normal,
  character_set: :ascii,
  auto_repeat: true
}

ansi = Raxol.Terminal.ANSI.new(config)
```

## Implementation Details

### Color Support

1. **Standard Colors**
   - 8 basic colors
   - 8 bright colors
   - Foreground and background

2. **256-Color Mode**
   - 16 system colors
   - 216 color cube
   - 24 grayscale levels

3. **True Color**
   - 24-bit RGB colors
   - Full color spectrum
   - Alpha channel support

### Text Formatting

1. **Basic Attributes**
   - Bold
   - Italic
   - Underline
   - Reverse video
   - Concealed
   - Strike-through

2. **Advanced Formatting**
   - Double-width characters
   - Double-height characters
   - Proportional spacing
   - Character combining

### Screen Modes

1. **Buffer Management**
   - Normal buffer
   - Alternate buffer
   - History buffer

2. **Mode Settings**
   - Line wrapping
   - Origin mode
   - Insert/Replace mode
   - Auto-repeat mode

## API Reference

### Sequence Processing

```elixir
# Process ANSI sequence
@spec process_sequence(ansi :: t(), sequence :: String.t()) :: {:ok, t(), [action()]} | {:error, String.t()}

# Process raw input
@spec process_input(ansi :: t(), input :: String.t()) :: {:ok, t(), [action()]} | {:error, String.t()}
```

### Color Management

```elixir
# Set foreground color
@spec set_foreground(ansi :: t(), color :: color()) :: t()

# Set background color
@spec set_background(ansi :: t(), color :: color()) :: t()

# Reset colors
@spec reset_colors(ansi :: t()) :: t()
```

### Text Attributes

```elixir
# Set text attributes
@spec set_attributes(ansi :: t(), attributes :: [attribute()]) :: t()

# Reset attributes
@spec reset_attributes(ansi :: t()) :: t()
```

### Screen Control

```elixir
# Switch to alternate buffer
@spec enter_alternate_buffer(ansi :: t()) :: t()

# Return to normal buffer
@spec exit_alternate_buffer(ansi :: t()) :: t()

# Clear screen
@spec clear_screen(ansi :: t()) :: t()
```

## Events

The ANSI processor emits the following events:

- `:sequence_processed` - When an ANSI sequence is processed
- `:color_changed` - When colors are changed
- `:attributes_changed` - When text attributes are changed
- `:mode_changed` - When screen mode changes
- `:character_set_changed` - When character set changes

## Example

```elixir
defmodule MyTerminal do
  alias Raxol.Terminal.ANSI

  def example do
    # Create a new ANSI processor
    ansi = ANSI.new()

    # Process some ANSI sequences
    {:ok, ansi, actions} = ansi
      |> ANSI.process_sequence("\e[1;31m")  # Bold red text
      |> ANSI.process_sequence("\e[H")      # Move to home position
      |> ANSI.process_sequence("\e[2J")     # Clear screen

    # Apply some formatting
    ansi = ansi
      |> ANSI.set_attributes([:bold, :underline])
      |> ANSI.set_foreground(:blue)
      |> ANSI.set_background(:white)

    # Handle the resulting actions
    Enum.each(actions, &handle_action/1)
  end

  defp handle_action(action) do
    case action do
      {:set_color, fg, bg} -> # Handle color change
      {:move_cursor, x, y} -> # Handle cursor movement
      {:clear_screen} -> # Handle screen clear
      _ -> :ok
    end
  end
end
```

## Testing

The ANSI processor includes comprehensive tests:

```elixir
defmodule Raxol.Terminal.ANSITest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI

  test "processes color sequence correctly" do
    ansi = ANSI.new()
    {:ok, ansi, actions} = ANSI.process_sequence(ansi, "\e[31m")
    assert Enum.member?(actions, {:set_color, :red, nil})
  end

  test "processes cursor movement correctly" do
    ansi = ANSI.new()
    {:ok, ansi, actions} = ANSI.process_sequence(ansi, "\e[H")
    assert Enum.member?(actions, {:move_cursor, 0, 0})
  end

  test "handles invalid sequences" do
    ansi = ANSI.new()
    {:error, _} = ANSI.process_sequence(ansi, "\e[invalid")
  end
end
``` 