# `Raxol.Core.Runtime.Plugins.TimerManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/timer_manager.ex#L1)

Handles timer management for plugin operations including periodic ticks and file event timers.

This module has been enhanced to use the centralized TimerManager for consistent
timer handling across the plugin system.

# `cancel_existing_timer`

```elixir
@spec cancel_existing_timer(map()) :: map()
```

Cancels an existing timer using the centralized TimerManager.

# `cancel_periodic_tick`

```elixir
@spec cancel_periodic_tick(map()) :: {:ok, map()}
```

Cancels a periodic tick timer using the centralized TimerManager.

# `schedule_file_event_timer`

```elixir
@spec schedule_file_event_timer(map(), atom(), String.t(), pos_integer()) :: map()
```

Schedules a file event timer using the centralized TimerManager.

# `start_periodic_tick`

```elixir
@spec start_periodic_tick(map(), pos_integer()) :: map()
```

Starts a periodic tick timer using the centralized TimerManager.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
