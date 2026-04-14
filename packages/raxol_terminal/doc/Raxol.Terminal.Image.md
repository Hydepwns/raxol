# `Raxol.Terminal.Image`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/image.ex#L2)

Unified facade for terminal inline image display.

Auto-detects the best available graphics protocol (Kitty, iTerm2, Sixel)
and encodes image data as a terminal escape sequence.

## Usage

    # Display from file path
    {:ok, escape_seq} = Image.display("logo.png", width: 20, height: 10)
    IO.write(escape_seq)

    # Display raw PNG bytes
    {:ok, escape_seq} = Image.display(png_binary, format: :png)

    # Force a specific protocol
    {:ok, escape_seq} = Image.display("photo.jpg", protocol: :iterm2)

    # Check support
    Image.supported?()        #=> true
    Image.detect_protocol()   #=> :kitty

# `display_opts`

```elixir
@type display_opts() :: [
  width: pos_integer(),
  height: pos_integer(),
  protocol: protocol(),
  format: :png | :jpeg | :gif,
  preserve_aspect: boolean(),
  z_index: integer()
]
```

# `protocol`

```elixir
@type protocol() :: :kitty | :iterm2 | :sixel | :unsupported
```

# `detect_protocol`

```elixir
@spec detect_protocol() :: protocol()
```

Detects the best available image protocol for the current terminal.

Priority: Kitty > iTerm2 > Sixel > :unsupported.

# `display`

```elixir
@spec display(binary(), display_opts()) :: {:ok, binary()} | {:error, term()}
```

Encodes an image for display in the terminal.

The source can be a file path (string) or raw image bytes (binary).
Returns the escape sequence to write to the terminal.

## Options

  * `:width` - Width in terminal cells
  * `:height` - Height in terminal cells
  * `:protocol` - Override auto-detected protocol
  * `:format` - Image format hint (:png, :jpeg, :gif)
  * `:preserve_aspect` - Preserve aspect ratio (default: true)
  * `:z_index` - Z-index layer for Kitty protocol (default: 0)

# `supported?`

```elixir
@spec supported?() :: boolean()
```

Returns true if any image protocol is supported.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
