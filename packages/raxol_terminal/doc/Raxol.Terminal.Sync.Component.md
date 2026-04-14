# `Raxol.Terminal.Sync.Component`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/sync/component.ex#L1)

Defines the structure for synchronized components.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Sync.Component{
  conflict_count: non_neg_integer(),
  id: String.t(),
  metadata: map(),
  state: term(),
  sync_count: non_neg_integer(),
  timestamp: integer(),
  type: String.t(),
  version: integer()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
