# `Raxol.Terminal.ANSI.CharacterSets.CharsetData`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/character_sets/charset_data.ex#L1)

Translation maps for all supported character sets.

Each map entry is {codepoint -> translated_codepoint}. Codepoints not
present in the map pass through unchanged.

# `translate`

```elixir
@spec translate(non_neg_integer(), atom()) :: non_neg_integer()
```

Translates a codepoint using the named charset map.

Returns the translated codepoint, or the original if no mapping exists.
Charsets `:us_ascii` and `:us` are identity mappings (no translation).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
