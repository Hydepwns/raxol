# `Raxol.Terminal.ANSI.Behaviours.SixelGraphics`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/behaviours.ex#L7)

Behaviour for Sixel graphics support.

# `t`

```elixir
@type t() :: map()
```

# `decode`

```elixir
@callback decode(binary()) :: t()
```

# `encode`

```elixir
@callback encode(t()) :: binary()
```

# `get_data`

```elixir
@callback get_data(t()) :: binary()
```

# `get_palette`

```elixir
@callback get_palette(t()) :: map()
```

# `get_position`

```elixir
@callback get_position(t()) :: {non_neg_integer(), non_neg_integer()}
```

# `get_scale`

```elixir
@callback get_scale(t()) :: {non_neg_integer(), non_neg_integer()}
```

# `new`

```elixir
@callback new() :: t()
```

# `new`

```elixir
@callback new(pos_integer(), pos_integer()) :: t()
```

# `process_sequence`

```elixir
@callback process_sequence(t(), binary()) :: t() | {t(), :ok | {:error, term()}}
```

# `set_data`

```elixir
@callback set_data(t(), binary()) :: t()
```

# `set_palette`

```elixir
@callback set_palette(t(), map()) :: t()
```

# `set_position`

```elixir
@callback set_position(t(), non_neg_integer(), non_neg_integer()) :: t()
```

# `set_scale`

```elixir
@callback set_scale(t(), non_neg_integer(), non_neg_integer()) :: t()
```

# `supported?`

```elixir
@callback supported?() :: boolean()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
