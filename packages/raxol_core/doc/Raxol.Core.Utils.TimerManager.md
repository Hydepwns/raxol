# `Raxol.Core.Utils.TimerManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/utils/timer_manager.ex#L1)

Centralized timer management utilities for consistent timer handling across the codebase.

This module provides a unified interface for working with timers, including:
- Periodic timers (intervals)
- One-time delayed timers
- Timer cancellation
- Timer reference tracking

All timer intervals are in milliseconds.

# `timer_msg`

```elixir
@type timer_msg() :: atom() | tuple()
```

# `timer_ref`

```elixir
@type timer_ref() :: reference() | {atom(), reference()} | nil
```

# `timer_type`

```elixir
@type timer_type() :: :interval | :once
```

# `add_jitter`

Adds jitter to a timer interval to prevent thundering herd.

## Examples

    # Add +/- 10% jitter to 5 second interval
    interval = TimerManager.add_jitter(5000, 0.1)

# `add_timer`

Manages multiple timers in a map, useful for GenServer state.

## Examples

    # Start a new timer in the timers map
    timers = TimerManager.add_timer(state.timers, :heartbeat, :interval, 5000)

    # Cancel and remove a timer
    timers = TimerManager.remove_timer(state.timers, :heartbeat)

# `cancel_all_timers`

Cancels all timers in a map, useful for GenServer terminate.

## Examples

    TimerManager.cancel_all_timers(state.timers)

# `cancel_timer`

Cancels a timer and returns whether it was successfully cancelled.

## Examples

    {:ok, cancelled} = TimerManager.cancel_timer(timer_ref)

# `exponential_backoff`

Calculates next timer interval for exponential backoff.

## Examples

    # First retry after 1 second, then 2, 4, 8, up to max 30 seconds
    delay = TimerManager.exponential_backoff(attempt, 1000, 30_000)

# `intervals`

Common timer intervals as constants for consistency.

# `remove_timer`

# `safe_cancel`

Safely cancels a timer if it exists, ignoring errors.

## Examples

    TimerManager.safe_cancel(timer_ref)

# `send_after`

Starts a one-time delayed timer that sends a message after a delay.

## Examples

    # Send :timeout message after 30 seconds
    ref = TimerManager.send_after(:timeout, 30_000)

    # Send {:retry, attempt_num} after 1 second
    ref = TimerManager.send_after({:retry, 1}, 1000)

# `start_interval`

Starts a periodic timer that sends a message at regular intervals.

## Examples

    # Send :cleanup message every hour
    {:ok, ref} = TimerManager.start_interval(:cleanup, 3_600_000)

    # Send {:check_status, :database} every 5 seconds
    {:ok, ref} = TimerManager.start_interval({:check_status, :database}, 5000)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
