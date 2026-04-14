# `Raxol.Terminal.Clipboard`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/clipboard.ex#L1)

Provides a high-level interface for clipboard operations.

This module offers a unified API for clipboard operations across different
terminal environments. It supports:
* Copying content to clipboard
* Pasting content from clipboard
* Clearing clipboard contents
* Multiple clipboard formats

## Clipboard Formats

The module supports different clipboard formats:
* `"text"` - Plain text (default)
* `"html"` - HTML content
* `"rtf"` - Rich Text Format
* Custom formats as needed

## Usage

```elixir
# Copy text to clipboard
Clipboard.copy("Hello, World!")

# Copy HTML content
Clipboard.copy("<b>Hello</b>", "html")

# Paste from clipboard
{:ok, content} = Clipboard.paste()

# Clear clipboard
Clipboard.clear()
```

# `clear`

```elixir
@spec clear() :: :ok
```

Clears the clipboard contents.

## Returns

  * `:ok` - Clipboard cleared successfully

## Examples

    iex> Clipboard.copy("Hello, World!")
    iex> Clipboard.clear()
    iex> Clipboard.paste()
    {:error, :empty_clipboard}

# `copy`

```elixir
@spec copy(String.t(), String.t()) :: :ok
```

Copies content to the clipboard.

## Parameters

  * `content` - The content to copy
  * `format` - The clipboard format (default: "text")

## Returns

  * `:ok` - Content copied successfully

## Examples

    iex> Clipboard.copy("Hello, World!")
    :ok

    iex> Clipboard.copy("<b>Hello</b>", "html")
    :ok

# `get_content`

```elixir
@spec get_content(Raxol.Terminal.Clipboard.Manager.t()) :: String.t()
```

Gets the content from a clipboard instance.

## Parameters

  * `clipboard` - The clipboard instance

## Returns

  * `String.t()` - The clipboard content

## Examples

    iex> clipboard = Manager.new()
    iex> clipboard = Manager.set_content(clipboard, "Hello, World!")
    iex> Clipboard.get_content(clipboard)
    "Hello, World!"

# `get_selection`

```elixir
@spec get_selection(Raxol.Terminal.Clipboard.Manager.t()) :: {:ok, String.t()}
```

Gets the selection content from a clipboard instance.

## Parameters

  * `clipboard` - The clipboard instance

## Returns

  * `{:ok, String.t()}` - Selection content retrieved successfully
  * `{:error, reason}` - Failed to get selection content

## Examples

    iex> clipboard = Manager.new()
    iex> {:ok, content} = Clipboard.get_selection(clipboard)
    iex> content
    ""

# `paste`

```elixir
@spec paste(String.t()) :: String.t()
```

Pastes content from the clipboard.

## Parameters

  * `format` - The clipboard format to paste (default: "text")

## Returns

  * `{:ok, content}` - Content pasted successfully
  * `{:error, :empty_clipboard}` - Clipboard is empty

## Examples

    iex> Clipboard.copy("Hello, World!")
    iex> Clipboard.paste()
    {:ok, "Hello, World!"}

    iex> Clipboard.clear()
    iex> Clipboard.paste()
    {:error, :empty_clipboard}

# `set_content`

```elixir
@spec set_content(Raxol.Terminal.Clipboard.Manager.t(), String.t()) ::
  {:ok, Raxol.Terminal.Clipboard.Manager.t()}
```

Sets the content of a clipboard instance.

## Parameters

  * `clipboard` - The clipboard instance
  * `content` - The content to set

## Returns

  * `{:ok, Manager.t()}` - Content set successfully
  * `{:error, reason}` - Failed to set content

## Examples

    iex> clipboard = Manager.new()
    iex> {:ok, clipboard} = Clipboard.set_content(clipboard, "Hello, World!")
    iex> Clipboard.get_content(clipboard)
    "Hello, World!"

# `set_selection`

```elixir
@spec set_selection(Raxol.Terminal.Clipboard.Manager.t(), String.t()) ::
  {:ok, Raxol.Terminal.Clipboard.Manager.t()}
```

Sets the selection content of a clipboard instance.

## Parameters

  * `clipboard` - The clipboard instance
  * `content` - The selection content to set

## Returns

  * `{:ok, Manager.t()}` - Selection content set successfully
  * `{:error, reason}` - Failed to set selection content

## Examples

    iex> clipboard = Manager.new()
    iex> {:ok, clipboard} = Clipboard.set_selection(clipboard, "Selected text")
    iex> {:ok, content} = Clipboard.get_selection(clipboard)
    iex> content
    "Selected text"

---

*Consult [api-reference.md](api-reference.md) for complete listing*
