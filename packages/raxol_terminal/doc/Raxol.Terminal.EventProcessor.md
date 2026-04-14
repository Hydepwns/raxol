# `Raxol.Terminal.EventProcessor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/event_processor.ex#L1)

Optimized event processing pipeline for terminal events.

This module provides high-performance event processing with:
- Batch event processing for improved throughput
- Event priority handling
- Optimized memory usage with pre-compiled handlers
- Event filtering and debouncing
- Performance monitoring integration

# `filter_redundant_events`

```elixir
@spec filter_redundant_events([Raxol.Core.Events.Event.t()]) :: [
  Raxol.Core.Events.Event.t()
]
```

Optimized event filtering to reduce processing overhead.

# `process_event`

```elixir
@spec process_event(Raxol.Core.Events.Event.t(), Raxol.Terminal.Emulator.t()) ::
  {Raxol.Terminal.Emulator.t(), any()}
```

Processes a single terminal event with optimized performance.

## Parameters
  * `event` - The event to process
  * `emulator` - The current terminal emulator state

## Returns
  * `{updated_emulator, output}` - The updated emulator state and any output

# `process_event_with_priority`

```elixir
@spec process_event_with_priority(
  Raxol.Core.Events.Event.t(),
  Raxol.Terminal.Emulator.t(),
  keyword()
) ::
  {:immediate, Raxol.Terminal.Emulator.t(), any()}
  | {:queued, Raxol.Terminal.Emulator.t()}
```

Processes high-priority events immediately, queues others.

## Parameters
  * `event` - The event to process
  * `emulator` - The current terminal emulator state
  * `options` - Processing options

## Returns
  * `{:immediate, updated_emulator, output}` - Processed immediately
  * `{:queued, emulator}` - Queued for later processing

# `process_events_batch`

```elixir
@spec process_events_batch([Raxol.Core.Events.Event.t()], Raxol.Terminal.Emulator.t()) ::
  {Raxol.Terminal.Emulator.t(), [any()]}
```

Processes multiple events in batch for improved performance.

## Parameters
  * `events` - List of events to process
  * `emulator` - The current terminal emulator state

## Returns
  * `{updated_emulator, outputs}` - The updated emulator state and list of outputs

---

*Consult [api-reference.md](api-reference.md) for complete listing*
