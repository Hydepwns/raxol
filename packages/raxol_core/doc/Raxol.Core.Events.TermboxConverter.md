# `Raxol.Core.Events.TermboxConverter`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/events/termbox_converter.ex#L1)

Converts rrex_termbox v2.0.1 NIF events to Raxol.Core.Events.Event structs.

This module handles the translation from the low-level rrex_termbox event format
to the Raxol event system format.

# `convert`

```elixir
@spec convert(map()) ::
  {:ok, Raxol.Core.Events.Event.t()} | :ignore | {:error, term()}
```

Converts a rrex_termbox v2.0.1 event map to a Raxol Event struct.

## Parameters

- event_map: The event map from rrex_termbox

## Returns

- `{:ok, %Event{}}` if the conversion was successful
- `:ignore` if the event should be ignored
- `{:error, reason}` if the conversion failed

---

*Consult [api-reference.md](api-reference.md) for complete listing*
