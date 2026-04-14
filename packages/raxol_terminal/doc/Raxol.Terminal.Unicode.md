# `Raxol.Terminal.Unicode`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/unicode.ex#L1)

Unicode handling utilities for terminal rendering.

Provides functions for determining character display widths,
handling combining characters, and normalizing Unicode text
for terminal display.

## Display Widths

Unicode characters have varying display widths in terminals:
- Most ASCII and Latin characters are "narrow" (width 1)
- CJK ideographs are "wide" (width 2)
- Combining characters have width 0
- Some emoji are wide (width 2)

## Example

    iex> Raxol.Terminal.Unicode.display_width("Hello")
    5

    iex> Raxol.Terminal.Unicode.display_width("Hello")
    10

    iex> Raxol.Terminal.Unicode.char_width(?a)
    1

# `char_width`

```elixir
@spec char_width(char()) :: 0 | 1 | 2
```

Get the display width of a single character.

Returns:
- 0 for combining characters and zero-width characters
- 1 for narrow characters (ASCII, Latin, etc.)
- 2 for wide characters (CJK, some emoji)

## Example

    iex> Raxol.Terminal.Unicode.char_width(?A)
    1

# `combining_char?`

```elixir
@spec combining_char?(char()) :: boolean()
```

Check if a character is a combining character (zero display width).

## Example

    iex> Raxol.Terminal.Unicode.combining_char?(0x0301)  # Combining acute accent
    true

# `display_width`

```elixir
@spec display_width(String.t()) :: non_neg_integer()
```

Calculate the display width of a string in terminal columns.

## Example

    iex> Raxol.Terminal.Unicode.display_width("Hello")
    5

# `graphemes_with_widths`

```elixir
@spec graphemes_with_widths(String.t()) :: [{String.t(), non_neg_integer()}]
```

Split a string into grapheme clusters with their display widths.

Returns a list of {grapheme, width} tuples.

## Example

    iex> Raxol.Terminal.Unicode.graphemes_with_widths("Hi!")
    [{"H", 1}, {"i", 1}, {"!", 1}]

# `normalize`

```elixir
@spec normalize(String.t()) :: String.t()
```

Normalize a string for terminal display.

This applies NFC normalization and handles various Unicode edge cases.

## Example

    iex> Raxol.Terminal.Unicode.normalize("cafe\u0301")
    "cafe"

# `pad`

```elixir
@spec pad(String.t(), pos_integer(), keyword()) :: String.t()
```

Pad a string to a given display width.

## Options

  - `:direction` - :left, :right, or :center (default: :right)
  - `:pad_char` - Character to use for padding (default: " ")

## Example

    iex> Raxol.Terminal.Unicode.pad("Hi", 5)
    "Hi   "

    iex> Raxol.Terminal.Unicode.pad("Hi", 5, direction: :left)
    "   Hi"

# `truncate`

```elixir
@spec truncate(String.t(), pos_integer(), keyword()) ::
  {String.t(), non_neg_integer()}
```

Truncate a string to fit within a given display width.

Returns a tuple of {truncated_string, actual_width}.

## Options

  - `:ellipsis` - String to append if truncated (default: "...")
  - `:preserve_words` - Try to break on word boundaries (default: false)

## Example

    iex> Raxol.Terminal.Unicode.truncate("Hello World", 8)
    {"Hello...", 8}

# `wide_char?`

```elixir
@spec wide_char?(char()) :: boolean()
```

Check if a character is a wide character (display width 2).

## Example

    iex> Raxol.Terminal.Unicode.wide_char?(0x4E00)  # CJK Unified Ideograph
    true

# `zero_width_char?`

```elixir
@spec zero_width_char?(char()) :: boolean()
```

Check if a character is a zero-width character.

## Example

    iex> Raxol.Terminal.Unicode.zero_width_char?(0x200B)  # Zero-width space
    true

---

*Consult [api-reference.md](api-reference.md) for complete listing*
