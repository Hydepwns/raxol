---
title: Clipboard Management Component
description: Documentation for the clipboard management component in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [clipboard, terminal, documentation]
---

# Clipboard Management Component

The clipboard management component handles clipboard operations, data formats, and system clipboard integration.

## Features

- Multiple clipboard buffers
- System clipboard integration
- Rich text support
- Image data support
- Clipboard history
- Format conversion
- Auto-formatting
- Persistent storage
- Selection sync
- Clipboard events

## Usage

```elixir
# Create a new clipboard manager
clipboard = Raxol.Terminal.Clipboard.new()

# Copy text to clipboard
:ok = Raxol.Terminal.Clipboard.copy(clipboard, "Hello, World!")

# Paste from clipboard
{:ok, text} = Raxol.Terminal.Clipboard.paste(clipboard)

# Clear clipboard
:ok = Raxol.Terminal.Clipboard.clear(clipboard)
```

## Configuration

The clipboard manager can be configured with the following options:

```elixir
config = %{
  max_history: 50,
  sync_with_system: true,
  auto_format: true,
  preserve_style: true,
  default_format: :text,
  history_persistence: true,
  buffer_size: 1024 * 1024,
  trim_whitespace: true
}

clipboard = Raxol.Terminal.Clipboard.new(config)
```

## Implementation Details

### Clipboard Types

1. **Text Clipboard**
   - Plain text
   - Rich text
   - Formatted text
   - Code snippets

2. **Binary Clipboard**
   - Image data
   - File data
   - Binary streams
   - Raw bytes

3. **Special Formats**
   - HTML content
   - Terminal sequences
   - Structured data
   - Custom formats

### Clipboard Management

1. **Buffer Management**
   - Multiple buffers
   - Buffer rotation
   - Buffer limits
   - Buffer cleanup

2. **Format Handling**
   - Format detection
   - Format conversion
   - Format validation
   - Format preservation

### Clipboard State

1. **Content State**
   - Current content
   - Content type
   - Content size
   - Content metadata

2. **History State**
   - History entries
   - Entry timestamps
   - Entry metadata
   - History limits

## API Reference

### Clipboard Management

```elixir
# Initialize clipboard manager
@spec new() :: t()

# Copy to clipboard
@spec copy(clipboard :: t(), content :: any(), format :: atom()) :: :ok | {:error, String.t()}

# Paste from clipboard
@spec paste(clipboard :: t(), format :: atom()) :: {:ok, any()} | {:error, String.t()}

# Clear clipboard
@spec clear(clipboard :: t()) :: :ok
```

### Buffer Management

```elixir
# Select buffer
@spec select_buffer(clipboard :: t(), buffer :: atom()) :: t()

# List buffers
@spec list_buffers(clipboard :: t()) :: [atom()]

# Clear buffer
@spec clear_buffer(clipboard :: t(), buffer :: atom()) :: :ok
```

### History Management

```elixir
# Get history
@spec get_history(clipboard :: t()) :: [map()]

# Clear history
@spec clear_history(clipboard :: t()) :: :ok

# Restore from history
@spec restore_from_history(clipboard :: t(), index :: integer()) :: :ok | {:error, String.t()}
```

## Events

The clipboard management component emits the following events:

- `:content_copied` - When content is copied to clipboard
- `:content_pasted` - When content is pasted from clipboard
- `:clipboard_cleared` - When clipboard is cleared
- `:buffer_changed` - When active buffer changes
- `:history_updated` - When clipboard history changes
- `:format_converted` - When content format is converted
- `:sync_completed` - When system clipboard sync completes

## Example

```elixir
defmodule MyTerminal do
  alias Raxol.Terminal.Clipboard

  def example do
    # Create a new clipboard manager
    clipboard = Clipboard.new()

    # Work with text content
    :ok = Clipboard.copy(clipboard, "Hello, World!")
    {:ok, text} = Clipboard.paste(clipboard)

    # Work with multiple buffers
    clipboard = clipboard
      |> Clipboard.select_buffer(:buffer1)
      |> Clipboard.copy("Buffer 1 content")
      |> Clipboard.select_buffer(:buffer2)
      |> Clipboard.copy("Buffer 2 content")

    # Work with clipboard history
    history = Clipboard.get_history(clipboard)
    :ok = Clipboard.restore_from_history(clipboard, 0)

    # Handle different formats
    :ok = Clipboard.copy(clipboard, "<b>Bold text</b>", :html)
    {:ok, html} = Clipboard.paste(clipboard, :html)
  end
end
```

## Testing

The clipboard management component includes comprehensive tests:

```elixir
defmodule Raxol.Terminal.ClipboardTest do
  use ExUnit.Case
  alias Raxol.Terminal.Clipboard

  test "copies and pastes text correctly" do
    clipboard = Clipboard.new()
    :ok = Clipboard.copy(clipboard, "test")
    assert {:ok, "test"} = Clipboard.paste(clipboard)
  end

  test "manages multiple buffers" do
    clipboard = Clipboard.new()
    clipboard = Clipboard.select_buffer(clipboard, :test)
    :ok = Clipboard.copy(clipboard, "buffer test")
    assert {:ok, "buffer test"} = Clipboard.paste(clipboard)
  end

  test "maintains clipboard history" do
    clipboard = Clipboard.new()
    :ok = Clipboard.copy(clipboard, "first")
    :ok = Clipboard.copy(clipboard, "second")
    history = Clipboard.get_history(clipboard)
    assert length(history) == 2
  end

  test "handles different formats" do
    clipboard = Clipboard.new()
    :ok = Clipboard.copy(clipboard, "<p>test</p>", :html)
    assert {:ok, "<p>test</p>"} = Clipboard.paste(clipboard, :html)
  end

  test "syncs with system clipboard" do
    clipboard = Clipboard.new(%{sync_with_system: true})
    :ok = Clipboard.copy(clipboard, "sync test")
    assert {:ok, "sync test"} = Clipboard.get_system_clipboard()
  end
end
``` 