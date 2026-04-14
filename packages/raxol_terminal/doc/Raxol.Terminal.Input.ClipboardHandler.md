# `Raxol.Terminal.Input.ClipboardHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/clipboard_handler.ex#L1)

Handles clipboard operations for the terminal emulator.

Supports both local system clipboard operations and OSC 52 escape sequences
for remote clipboard access over SSH and other terminal connections.

## OSC 52 Support

OSC 52 allows applications to read from and write to the system clipboard
even when running over SSH or in remote terminal sessions. This module
can generate OSC 52 sequences to communicate clipboard operations to
compatible terminal emulators.

## Features

- Local system clipboard integration (pbcopy/pbpaste, xclip, etc.)
- OSC 52 escape sequences for remote clipboard access
- Base64 encoding/decoding for OSC 52 payloads
- Bracketed paste mode support
- Security controls and size limits

# `detect_osc52_support`

Detects if a terminal supports OSC 52 based on environment variables.

## Returns

- `:supported` - Terminal likely supports OSC 52
- `:unsupported` - Terminal likely does not support OSC 52
- `:unknown` - Cannot determine terminal capabilities

# `disable_bracketed_paste`

Disables bracketed paste mode.

## Returns

- `binary()` - Escape sequence to disable bracketed paste mode

# `enable_bracketed_paste`

Enables bracketed paste mode by generating the appropriate escape sequence.

Bracketed paste mode allows terminals to distinguish between typed text
and pasted text, preventing issues with automatic indentation and other
editor features.

## Returns

- `binary()` - Escape sequence to enable bracketed paste mode

# `generate_osc52_copy`

Generates an OSC 52 escape sequence to copy text to the system clipboard.

This is useful for remote terminal sessions where direct clipboard access
is not available (such as over SSH).

## Parameters

- `text` - Text to copy to clipboard
- `options` - Options map with optional keys:
  - `:target` - Clipboard target (default: :clipboard)
  - `:max_length` - Maximum length to copy (default: @max_osc_52_length)

## Returns

- `{:ok, osc_sequence}` - OSC 52 escape sequence to send to terminal
- `{:error, reason}` - Error if text is too long or other issues

## Examples

    iex> ClipboardHandler.generate_osc52_copy("Hello, World!")
    {:ok, "]52;c;SGVsbG8sIFdvcmxkIQ==\"}

    iex> ClipboardHandler.generate_osc52_copy("test", target: :primary)
    {:ok, "]52;p;dGVzdA==\"}

# `generate_osc52_query`

Generates an OSC 52 escape sequence to query the system clipboard.

## Parameters

- `target` - Clipboard target to query (default: :clipboard)

## Returns

- `{:ok, osc_sequence}` - OSC 52 query sequence to send to terminal
- `{:error, reason}` - Error for invalid target

## Examples

    iex> ClipboardHandler.generate_osc52_query()
    {:ok, "]52;c;?\"}

    iex> ClipboardHandler.generate_osc52_query(:primary)
    {:ok, "]52;p;?\"}

# `handle_clipboard_with_fallback`

Handles clipboard operations with automatic fallback between local and OSC 52.

Attempts local clipboard access first, falls back to OSC 52 if running
in a remote session or if local access fails.

## Parameters

- `operation` - `:copy` or `:paste`
- `text` - Text to copy (required for :copy, ignored for :paste)
- `options` - Options including `:force_osc52` to skip local clipboard

## Returns

- For copy: `{:ok, output}` where output is either `:ok` or an OSC 52 sequence
- For paste: `{:ok, text}` or `{:error, :paste_not_supported_osc52}`

# `handle_copy`

Handles clipboard copy operation.
(Currently copies the entire buffer)

# `handle_cut`

Handles clipboard cut operation.
(Currently cuts the entire buffer)

# `handle_paste`

Handles clipboard paste operation.

# `parse_osc52_response`

Parses an OSC 52 response from the terminal.

When a terminal responds to an OSC 52 query, it sends back the clipboard
contents as a base64-encoded string. This function decodes the response.

## Parameters

- `osc_response` - Raw OSC 52 response from terminal

## Returns

- `{:ok, {target, text}}` - Decoded clipboard target and text
- `{:error, reason}` - Error if response is malformed

## Examples

    iex> ClipboardHandler.parse_osc52_response("]52;c;SGVsbG8=\")
    {:ok, {:clipboard, "Hello"}}

---

*Consult [api-reference.md](api-reference.md) for complete listing*
