# `Raxol.Terminal.ANSI.CharacterTranslations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/character_translations.ex#L1)

Provides character translation tables for different character sets.
Maps characters between different character sets according to ANSI standards.

# `dec_special`

Returns the DEC Special Graphics character set translation table.

## Returns

  * Map containing DEC Special Graphics character translations

## Examples

    iex> Raxol.Terminal.ANSI.CharacterTranslations.dec_special()
    %{...}

# `dec_supplementary`

Returns the DEC Supplementary character set translation table.

## Returns

  * Map containing DEC Supplementary character translations

## Examples

    iex> Raxol.Terminal.ANSI.CharacterTranslations.dec_supplementary()
    %{...}

# `dec_supplementary_graphics`

Returns the DEC Supplementary Graphics character set translation table.

## Returns

  * Map containing DEC Supplementary Graphics character translations

## Examples

    iex> Raxol.Terminal.ANSI.CharacterTranslations.dec_supplementary_graphics()
    %{...}

# `dec_technical`

Returns the DEC Technical character set translation table.

## Returns

  * Map containing DEC Technical character translations

## Examples

    iex> Raxol.Terminal.ANSI.CharacterTranslations.dec_technical()
    %{...}

# `french`

Returns the French character set translation table.

## Returns

  * Map containing French character translations

## Examples

    iex> Raxol.Terminal.ANSI.CharacterTranslations.french()
    %{...}

# `german`

Returns the German character set translation table.

## Returns

  * Map containing German character translations

## Examples

    iex> Raxol.Terminal.ANSI.CharacterTranslations.german()
    %{...}

# `latin1`

Returns the Latin-1 character set translation table.

## Returns

  * Map containing Latin-1 character translations

## Examples

    iex> Raxol.Terminal.ANSI.CharacterTranslations.latin1()
    %{...}

# `translate_char`

```elixir
@spec translate_char(char_codepoint :: integer(), charset :: atom()) :: binary()
```

Translates a character from the source character set to the target character set.

## Parameters

  * `char_codepoint` - The Unicode codepoint of the character to translate
  * `charset` - The target character set to translate to (e.g., `:us_ascii`, `:uk`, `:french`)

## Returns

  * Binary containing the translated character in UTF-8 encoding
  * The original character if no translation exists

## Examples

    iex> Raxol.Terminal.ANSI.CharacterTranslations.translate_char(?é, :us_ascii)
    "e"

    iex> Raxol.Terminal.ANSI.CharacterTranslations.translate_char(?a, :us_ascii)
    "a"

# `translate_string`

```elixir
@spec translate_string(string :: String.t(), charset :: atom()) :: String.t()
```

Translates a string from the source character set to the target character set.
Handles invalid bytes gracefully by passing them through as-is.

# `uk`

Returns the UK character set translation table.

## Returns

  * Map containing UK character translations

## Examples

    iex> Raxol.Terminal.ANSI.CharacterTranslations.uk()
    %{...}

# `unicode_to_ansi`

Map of Unicode codepoints to their ANSI terminal equivalents.

# `us_ascii`

Returns the US ASCII character set translation table.

## Returns

  * Map containing US ASCII character translations

## Examples

    iex> Raxol.Terminal.ANSI.CharacterTranslations.us_ascii()
    %{...}

---

*Consult [api-reference.md](api-reference.md) for complete listing*
