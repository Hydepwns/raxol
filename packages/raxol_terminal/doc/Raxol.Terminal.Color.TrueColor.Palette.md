# `Raxol.Terminal.Color.TrueColor.Palette`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/color/true_color/palette.ex#L1)

Named color constants and lookup for TrueColor.

# `color_name`

```elixir
@type color_name() ::
  :black
  | :white
  | :red
  | :green
  | :blue
  | :yellow
  | :magenta
  | :cyan
  | :orange
  | :purple
  | :pink
  | :brown
  | :gray
  | :lime
  | :navy
  | :olive
  | :silver
  | :teal
```

# `all`

```elixir
@spec all() :: %{required(color_name()) =&gt; {0..255, 0..255, 0..255}}
```

Returns the full map of named colors.

# `lookup`

```elixir
@spec lookup(atom() | binary()) ::
  {:ok, {0..255, 0..255, 0..255}} | {:error, :unknown_color_name}
```

Looks up a named color and returns `{:ok, {r, g, b}}` or `{:error, :unknown_color_name}`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
