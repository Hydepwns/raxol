# `Raxol.Terminal.Charset.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/charset/charset_manager.ex#L1)

Manages terminal character sets and encoding operations.

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

# `apply_single_shift`

# `designate_charset`

# `get_charset`

Gets the current character set for the specified G-set.

# `get_current_g_set`

# `get_designated_charset`

# `get_single_shift`

# `get_state`

Gets the current state of the charset manager.

# `handle_set_charset`

# `invoke_g_set`

# `map_character`

Maps a character using the current character set.

# `new`

Creates a new charset manager instance.

# `reset_state`

Resets the charset state to defaults.

# `update_state`

Updates the state of the charset manager.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
