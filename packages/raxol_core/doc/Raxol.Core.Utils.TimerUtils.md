# `Raxol.Core.Utils.TimerUtils`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/utils/timer_utils.ex#L1)

Consolidated timer utilities for standardized timer management across Raxol.

Provides a unified interface for common timer patterns:
- Periodic timers (cleanup, health checks, optimization)
- Delayed execution timers
- Debounced timers
- Timer cancellation and management

This consolidates the 84+ timer patterns found across the codebase.

# `timer_opts`

```elixir
@type timer_opts() :: [interval: pos_integer(), message: term(), debounce_key: term()]
```

# `timer_ref`

```elixir
@type timer_ref() :: reference() | nil
```

# `timer_type`

```elixir
@type timer_type() :: :periodic | :delayed | :debounced
```

# `cancel_all_timers`

Cancels all timers in a state's timers map.

## Examples

    # In terminate/2 callback
    TimerUtils.cancel_all_timers(state)

# `cancel_timer`

Cancels a timer if it exists and is valid.

## Examples

    timer_ref = TimerUtils.start_delayed(self(), :cleanup, 5000)
    :ok = TimerUtils.cancel_timer(timer_ref)

# `debounce_timer`

Creates a debounced timer that cancels the previous timer of the same key.
Useful for file watching, input handling, etc.

State should have a timers map: %{timers: %{}}

## Examples

    # In GenServer state
    new_state = TimerUtils.debounce_timer(
      state,
      :file_reload,
      self(),
      {:reload_file, path},
      1000
    )

# `get_interval`

Gets a standard interval by name.

## Examples

    interval = TimerUtils.get_interval(:health_check)  # 30_000
    timer_ref = TimerUtils.start_periodic(self(), :health_check, interval)

# `intervals`

Standard timer intervals used across the application.

# `restart_timer`

Cancels an existing timer and starts a new one (common pattern for debouncing).

## Examples

    # Debounced file reload - cancel previous and start new
    timer_ref = TimerUtils.restart_timer(old_timer, self(), {:reload_file, path}, 1000)

# `start_delayed`

Starts a delayed timer that sends a message after a specified delay.

## Examples

    # Cleanup after 60 seconds
    timer_ref = TimerUtils.start_delayed(self(), :cleanup_timer, 60_000)

    # Flush data after 1 second
    timer_ref = TimerUtils.start_delayed(self(), :flush, 1_000)

# `start_periodic`

Starts a periodic timer that sends messages at regular intervals.

## Examples

    # Health check every 30 seconds
    timer_ref = TimerUtils.start_periodic(self(), :perform_health_check, 30_000)

    # Performance monitoring every 5 seconds
    timer_ref = TimerUtils.start_periodic(self(), :monitor_performance, 5_000)

# `start_periodic_with_state`

Helper for common periodic timer patterns with state management.

## Examples

    # Start health check timer and update state
    new_state = TimerUtils.start_periodic_with_state(
      state,
      :health_timer,
      self(),
      :perform_health_check,
      :health_check
    )

---

*Consult [api-reference.md](api-reference.md) for complete listing*
