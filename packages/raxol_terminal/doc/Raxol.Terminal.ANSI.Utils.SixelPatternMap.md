# `Raxol.Terminal.ANSI.Utils.SixelPatternMap`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/utils.ex#L7)

Provides a mapping from Sixel characters to their 6-bit pixel patterns.

# `get_pattern`

```elixir
@spec get_pattern(integer()) :: non_neg_integer() | nil
```

Gets the 6-bit integer pattern for a given Sixel character code.

# `pattern_to_pixels`

```elixir
@spec pattern_to_pixels(non_neg_integer()) :: [0 | 1]
```

Converts a 6-bit integer pattern into a list of 6 pixel values (0 or 1).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
