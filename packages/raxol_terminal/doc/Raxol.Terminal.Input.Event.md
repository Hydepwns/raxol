# `Raxol.Terminal.Input.Event`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/event.ex#L1)

Defines the base event struct and common types for input events.

# `modifier`

```elixir
@type modifier() :: :shift | :ctrl | :alt | :meta
```

# `t`

```elixir
@type t() ::
  Raxol.Terminal.Input.Event.MouseEvent.t()
  | Raxol.Terminal.Input.Event.KeyEvent.t()
```

# `timestamp`

```elixir
@type timestamp() :: integer()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
