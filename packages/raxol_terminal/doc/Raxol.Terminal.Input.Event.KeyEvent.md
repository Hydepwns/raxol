# `Raxol.Terminal.Input.Event.KeyEvent`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/event.ex#L38)

Represents a keyboard input event.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Input.Event.KeyEvent{
  key: String.t(),
  modifiers: [Raxol.Terminal.Input.Event.modifier()],
  timestamp: Raxol.Terminal.Input.Event.timestamp()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
