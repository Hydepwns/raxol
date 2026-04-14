# `Raxol.Terminal.ANSI.CharacterSets.Translator`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/character_sets/translator.ex#L1)

Handles character set translations and mappings.
Delegates per-charset data lookups to CharsetData.

# `translate_char`

Translates a character using the active character set (2-parameter version).
Returns a tuple of {translated_char, new_charset_state}.

# `translate_char`

Translates a character using the named character set and optional single shift.

# `translate_string`

Translates a string using the specified character set and single shift.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
