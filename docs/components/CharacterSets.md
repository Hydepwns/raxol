---
title: Character Sets Component
description: Documentation for the character sets component in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [character sets, terminal, documentation]
---

# Character Sets Component

The character sets component manages character set switching and translation in the terminal emulator.

## Features

- Character set switching (G0, G1, G2, G3)
- Multiple character sets support
- Character translation
- Font selection
- Character width handling
- Unicode support
- Special character handling
- Custom character sets

## Usage

```elixir
# Create a new character sets manager
charset = Raxol.Terminal.CharacterSets.new()

# Switch character set
charset = Raxol.Terminal.CharacterSets.switch_set(charset, :g0, :ascii)

# Translate character
{:ok, char} = Raxol.Terminal.CharacterSets.translate(charset, ?A)

# Get character width
width = Raxol.Terminal.CharacterSets.get_width(charset, ?あ)
```

## Configuration

The character sets manager can be configured with the following options:

```elixir
config = %{
  default_set: :ascii,
  g0_set: :ascii,
  g1_set: :special,
  g2_set: :graphics,
  g3_set: :supplemental,
  font_family: "monospace"
}

charset = Raxol.Terminal.CharacterSets.new(config)
```

## Implementation Details

### Character Sets

1. **ASCII Set**
   - Standard ASCII characters
   - Control characters
   - Extended ASCII

2. **Special Characters**
   - Box drawing
   - Block elements
   - Geometric shapes

3. **Graphics Characters**
   - Line drawing
   - Shading characters
   - Terminal graphics

4. **Supplemental Sets**
   - Unicode blocks
   - Regional characters
   - Symbol sets

### Character Translation

1. **Translation Tables**
   - Character mappings
   - Fallback characters
   - Combining characters

2. **Width Handling**
   - Single-width
   - Double-width
   - Zero-width
   - Full-width

## API Reference

### Character Set Management

```elixir
# Initialize character sets
@spec new() :: t()

# Switch character set
@spec switch_set(charset :: t(), slot :: :g0 | :g1 | :g2 | :g3, set :: atom()) :: t()

# Get current character set
@spec get_current_set(charset :: t()) :: atom()
```

### Character Translation

```elixir
# Translate character
@spec translate(charset :: t(), char :: char()) :: {:ok, char()} | {:error, String.t()}

# Get character width
@spec get_width(charset :: t(), char :: char()) :: integer()

# Check if character is special
@spec is_special?(charset :: t(), char :: char()) :: boolean()
```

### Font Management

```elixir
# Set font family
@spec set_font(charset :: t(), font :: String.t()) :: t()

# Get current font
@spec get_font(charset :: t()) :: String.t()
```

## Events

The character sets component emits the following events:

- `:set_switched` - When character set is switched
- `:font_changed` - When font is changed
- `:translation_failed` - When character translation fails
- `:width_changed` - When character width changes

## Example

```elixir
defmodule MyTerminal do
  alias Raxol.Terminal.CharacterSets

  def example do
    # Create a new character sets manager
    charset = CharacterSets.new()

    # Configure character sets
    charset = charset
      |> CharacterSets.switch_set(:g0, :ascii)
      |> CharacterSets.switch_set(:g1, :special)
      |> CharacterSets.set_font("monospace")

    # Translate some characters
    {:ok, char1} = CharacterSets.translate(charset, ?A)
    {:ok, char2} = CharacterSets.translate(charset, ?あ)

    # Get character widths
    width1 = CharacterSets.get_width(charset, ?A)  # => 1
    width2 = CharacterSets.get_width(charset, ?あ) # => 2

    # Check for special characters
    is_special = CharacterSets.is_special?(charset, ?█)
  end
end
```

## Testing

The character sets component includes comprehensive tests:

```elixir
defmodule Raxol.Terminal.CharacterSetsTest do
  use ExUnit.Case
  alias Raxol.Terminal.CharacterSets

  test "switches character sets correctly" do
    charset = CharacterSets.new()
    charset = CharacterSets.switch_set(charset, :g0, :ascii)
    assert CharacterSets.get_current_set(charset) == :ascii
  end

  test "translates characters correctly" do
    charset = CharacterSets.new()
    {:ok, char} = CharacterSets.translate(charset, ?A)
    assert char == ?A
  end

  test "handles character widths correctly" do
    charset = CharacterSets.new()
    assert CharacterSets.get_width(charset, ?A) == 1
    assert CharacterSets.get_width(charset, ?あ) == 2
  end
end
``` 