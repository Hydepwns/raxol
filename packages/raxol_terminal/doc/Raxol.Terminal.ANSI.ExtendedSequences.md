# `Raxol.Terminal.ANSI.ExtendedSequences`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/extended_sequences.ex#L1)

Handles extended ANSI sequences and provides improved integration with the screen buffer.
Functional Programming Version - All try/catch blocks replaced with with statements.

This module adds support for:
- Extended SGR attributes (90-97, 100-107)
- True color support (24-bit RGB)
- Unicode handling
- Terminal state management
- Improved cursor control

# `attribute`

```elixir
@type attribute() ::
  :bold
  | :faint
  | :italic
  | :underline
  | :blink
  | :rapid_blink
  | :inverse
  | :conceal
  | :strikethrough
  | :normal_intensity
  | :no_italic
  | :no_underline
  | :no_blink
  | :no_inverse
  | :no_conceal
  | :no_strikethrough
  | :foreground
  | :background
  | :foreground_basic
  | :background_basic
```

# `color`

```elixir
@type color() :: {0..255, 0..255, 0..255} | 0..255
```

# `process_extended_cursor`

```elixir
@spec process_extended_cursor(
  String.t(),
  [String.t()],
  Raxol.Terminal.ScreenBuffer.t()
) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Processes extended cursor control sequences.

# `process_extended_sgr`

```elixir
@spec process_extended_sgr([String.t()], Raxol.Terminal.ScreenBuffer.t()) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Processes extended SGR (Select Graphic Rendition) parameters.
Supports:
- Extended colors (90-97, 100-107)
- True color (24-bit RGB)
- Additional attributes

# `process_terminal_state`

```elixir
@spec process_terminal_state(String.t(), Raxol.Terminal.ScreenBuffer.t()) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Processes terminal state escape sequences.
Handles cursor visibility (?25h/l), alternate screen (?47h/l, ?1049h/l).

# `process_true_color`

```elixir
@spec process_true_color(String.t(), String.t(), Raxol.Terminal.ScreenBuffer.t()) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Processes true color sequences (24-bit RGB).

# `process_unicode`

```elixir
@spec process_unicode(String.t(), Raxol.Terminal.ScreenBuffer.t()) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Handles Unicode character sequences.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
