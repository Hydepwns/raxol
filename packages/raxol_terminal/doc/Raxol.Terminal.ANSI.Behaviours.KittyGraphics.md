# `Raxol.Terminal.ANSI.Behaviours.KittyGraphics`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/behaviours.ex#L57)

Behaviour for Kitty graphics protocol support.

The Kitty Graphics Protocol enables pixel-level graphics rendering
with superior features to Sixel including native animation support,
better compression, and more flexible placement.

# `action`

```elixir
@type action() :: :transmit | :display | :delete | :query
```

# `compression`

```elixir
@type compression() :: :none | :zlib
```

# `format`

```elixir
@type format() :: :rgb | :rgba | :png
```

# `t`

```elixir
@type t() :: map()
```

# `add_animation_frame`
*optional* 

```elixir
@callback add_animation_frame(t(), binary()) :: t()
```

# `decode`

```elixir
@callback decode(binary()) :: t()
```

# `delete_image`
*optional* 

```elixir
@callback delete_image(t(), non_neg_integer()) :: t()
```

# `encode`

```elixir
@callback encode(t()) :: binary()
```

# `get_data`

```elixir
@callback get_data(t()) :: binary()
```

# `new`

```elixir
@callback new() :: t()
```

# `new`

```elixir
@callback new(pos_integer(), pos_integer()) :: t()
```

# `place_image`
*optional* 

```elixir
@callback place_image(t(), map()) :: t()
```

# `process_sequence`

```elixir
@callback process_sequence(t(), binary()) :: {t(), :ok | {:error, term()}}
```

# `query_image`
*optional* 

```elixir
@callback query_image(t(), non_neg_integer()) :: {:ok, map()} | {:error, term()}
```

# `set_data`

```elixir
@callback set_data(t(), binary()) :: t()
```

# `supported?`

```elixir
@callback supported?() :: boolean()
```

# `transmit_image`
*optional* 

```elixir
@callback transmit_image(t(), map()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
