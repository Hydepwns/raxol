# `Raxol.Core.Events.Subscription`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/events/subscription.ex#L1)

Provides helpers for managing event subscriptions.

This module makes it easy to:
* Subscribe to specific event types
* Filter events based on criteria
* Handle event cleanup
* Manage multiple subscriptions

# `subscription_opts`

```elixir
@type subscription_opts() :: keyword()
```

# `subscription_ref`

```elixir
@type subscription_ref() :: reference()
```

# `events`

Subscribes to a list of event types.

## Parameters

- `event_types` - A list of event type atoms (e.g., `[:key, :mouse, :window]`).
                   Can also include tuples like `{:key, opts}` or `{:mouse, opts}`
                   to pass specific options to the individual subscription functions.

## Returns

- `{:ok, list(subscription_ref())}` on success, containing a list of references for each subscription.
- `{:error, reason}` if any subscription fails. Successfully created subscriptions before the failure will be automatically unsubscribed.

# `subscribe_custom`

Subscribes to custom events with data matching.

## Options
* `:match` - Pattern to match against custom event data

## Example
    subscribe_custom(match: {:user_action, _})

# `subscribe_keyboard`

Subscribes to keyboard events with optional key filters.

## Options
* `:keys` - List of specific keys to match
* `:exclude_keys` - List of keys to ignore

## Example
    subscribe_keyboard(keys: [:enter, :esc])
    subscribe_keyboard(exclude_keys: [:tab])

# `subscribe_mouse`

Subscribes to mouse events with optional button and position filters.

## Options
* `:buttons` - List of mouse buttons to match
* `:drag_only` - Only match drag events
* `:click_only` - Only match click events
* `:area` - Tuple of {x, y, width, height} to match position

## Example
    subscribe_mouse(buttons: [:left, :right])
    subscribe_mouse(area: {0, 0, 10, 10})

# `subscribe_timer`

Subscribes to timer events with optional data matching.

## Options
* `:match` - Pattern to match against timer data

## Example
    subscribe_timer(match: :tick)

# `subscribe_window`

Subscribes to window events with optional action filters.

## Options
* `:actions` - List of window actions to match (:resize, :focus, :blur)

## Example
    subscribe_window(actions: [:resize])

# `unsubscribe`

Unsubscribes from events using the subscription reference.

# `unsubscribe_all`

Unsubscribes from multiple subscriptions.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
