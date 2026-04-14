# `Raxol.Core.Runtime.Plugins.EventFilter`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/event_filter.ex#L1)

Handles event filtering for plugins.
This module is responsible for:
- Filtering events through registered plugin filters
- Managing event modifications
- Handling event halting

# `filter_event`

```elixir
@spec filter_event(map(), map()) :: map() | :halt
```

Filters an event through registered plugin filters.
Returns the filtered event or :halt if the event should be stopped.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
