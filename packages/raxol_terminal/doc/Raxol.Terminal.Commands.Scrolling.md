# `Raxol.Terminal.Commands.Scrolling`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/scrolling.ex#L1)

Handles scrolling operations for the terminal screen buffer.

# `insert_lines`

```elixir
@spec insert_lines(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.ScreenBuffer.t()
```

# `scroll_down`

```elixir
@spec scroll_down(
  map(),
  non_neg_integer(),
  {integer(), integer()} | nil,
  any()
) :: map()
```

# `scroll_up`

```elixir
@spec scroll_up(
  map(),
  non_neg_integer(),
  {integer(), integer()} | nil,
  any()
) :: map()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
