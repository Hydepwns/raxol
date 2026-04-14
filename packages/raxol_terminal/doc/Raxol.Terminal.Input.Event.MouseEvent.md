# `Raxol.Terminal.Input.Event.MouseEvent`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/event.ex#L11)

Represents a mouse input event.

# `action`

```elixir
@type action() :: :press | :release | :drag | :move
```

# `button`

```elixir
@type button() :: :left | :middle | :right | :wheel_up | :wheel_down
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Input.Event.MouseEvent{
  action: action(),
  button: button(),
  modifiers: [Raxol.Terminal.Input.Event.modifier()],
  timestamp: Raxol.Terminal.Input.Event.timestamp(),
  x: non_neg_integer(),
  y: non_neg_integer()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
