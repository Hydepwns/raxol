# `Raxol.Terminal.Color.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/color/color_manager.ex#L1)

Manages terminal colors and color operations.

# `color`

```elixir
@type color() :: :default | {0..255, 0..255, 0..255} | atom()
```

# `color_map`

```elixir
@type color_map() :: %{required(atom()) =&gt; color()}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Color.Manager{
  colors: %{foreground: color(), background: color(), palette: color_map()},
  default_palette: color_map()
}
```

# `color_to_rgb`

Converts a color to RGB format.

# `get_color`

Gets a specific color by name.

# `get_colors`

Gets all current colors.

# `get_default_palette`

Gets the default color palette.

# `merge_palette`

Merges a new palette with the existing one.

# `new`

Creates a new color manager instance.

# `reset_colors`

Resets all colors to their default values.

# `set_color`

Sets a specific color by name.

# `set_colors`

Sets multiple colors at once.

# `set_palette`

Sets a custom color palette.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
