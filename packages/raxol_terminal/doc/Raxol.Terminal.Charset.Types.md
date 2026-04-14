# `Raxol.Terminal.Charset.Types`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/charset/charset_types.ex#L1)

Defines types used across the charset modules.

# `char_map`

```elixir
@type char_map() :: %{required(non_neg_integer()) =&gt; String.t()}
```

# `charset`

```elixir
@type charset() :: :us_ascii | :dec_supplementary | :dec_special | :dec_technical
```

# `g_set`

```elixir
@type g_set() :: :g0 | :g1 | :g2 | :g3
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Charset.Manager{
  charsets: %{required(charset()) =&gt; (-&gt; char_map())},
  current_g_set: g_set(),
  g_sets: %{required(g_set()) =&gt; charset()},
  single_shift: g_set() | nil
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
