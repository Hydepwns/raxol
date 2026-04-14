# `Raxol.Terminal.CharacterHandling`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/character_handling.ex#L1)

Handles wide character and bidirectional text support for the terminal emulator.

This module provides functions for:
- Determining character width (single, double, or variable width)
- Handling bidirectional text rendering
- Managing character combining
- Supporting Unicode character properties

# `combining_char?`

```elixir
@spec combining_char?(char()) :: boolean()
```

Determines if a character is a combining character.

# `get_bidi_type`

Determines the bidirectional character type.
Returns :LTR, :RTL, :NEUTRAL, or :COMBINING.

# `get_char_width`

```elixir
@spec get_char_width(codepoint :: integer() | String.t()) :: 1 | 2
```

Determine the display width of a given character code point or string.

# `get_string_width`

```elixir
@spec get_string_width(String.t()) :: non_neg_integer()
```

Gets the effective width of a string, taking into account wide characters
and ignoring combining characters.

# `process_bidi_text`

```elixir
@spec process_bidi_text(String.t()) :: [{:LTR | :RTL | :NEUTRAL, String.t()}]
```

Processes a string for bidirectional text rendering.
Returns a list of segments with their rendering order.

# `split_at_width`

```elixir
@spec split_at_width(String.t(), non_neg_integer()) :: {String.t(), String.t()}
```

Splits a string at a given width, respecting wide characters.

# `wide_char?`

```elixir
@spec wide_char?(char()) :: boolean()
```

Determines if a character is a wide character (takes up two cells).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
