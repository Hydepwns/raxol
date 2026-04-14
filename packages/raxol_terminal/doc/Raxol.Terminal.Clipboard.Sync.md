# `Raxol.Terminal.Clipboard.Sync`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/clipboard/sync.ex#L1)

Handles clipboard synchronization between different terminal instances.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Clipboard.Sync{subscribers: [pid()]}
```

# `add_subscriber`

Adds a subscriber to receive clipboard updates.

# `broadcast`

Broadcasts clipboard content to all subscribers.

# `new`

Creates a new clipboard sync instance.

# `remove_subscriber`

Removes a subscriber from receiving clipboard updates.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
