# `Raxol.Core.Events.EventManager.EventManagerServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/events/manager/event_manager_server.ex#L1)

GenServer implementation for event management in Raxol applications.

This server provides a pure functional approach to event management using
a PubSub pattern, eliminating Process dictionary usage and implementing
proper OTP supervision patterns.

## Features
- Event handler registration with module/function callbacks
- PubSub-style subscriptions with filters
- Broadcast and targeted event dispatching
- Supervised state management with fault tolerance
- Support for priority handlers
- Event history tracking (optional)

## State Structure
The server maintains state with the following structure:
```elixir
%{
  handlers: %{event_type => [{module, function, priority}]},
  subscriptions: %{ref => %{pid: pid, event_types: [], filters: [], monitor_ref: ref}},
  monitors: %{monitor_ref => subscription_ref},
  event_history: [], # Optional, configurable
  config: %{
    history_limit: 100,
    enable_history: false
  }
}
```

## Event Dispatching
Events are dispatched in priority order (lower numbers = higher priority).
Handlers with the same priority are executed in registration order.

# `broadcast`

Broadcasts an event to all subscribers regardless of filters.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear_handlers`

Clears all event handlers.

# `clear_history`

Clears event history.

# `clear_subscriptions`

Clears all subscriptions.

# `dispatch`

Dispatches an event to all registered handlers and subscribers.

This is an asynchronous operation - use dispatch_sync for synchronous dispatch.

# `dispatch_sync`

Dispatches an event synchronously, waiting for all handlers to complete.

# `get_event_history`

Gets event history (if enabled).

# `get_handlers`

Gets all registered event handlers.

# `get_state`

Gets the current state (for debugging/testing).

# `get_subscriptions`

Gets all active subscriptions.

# `register_handler`

Registers an event handler with optional priority.

## Parameters
- `event_type` - The type of event to handle
- `module` - The module containing the handler function
- `function` - The function to call when the event occurs
- `opts` - Options including:
  - `:priority` - Handler priority (default: 50, lower = higher priority)

# `reset_manager`

Initializes the event manager (for backward compatibility).

# `start_link`

# `subscribe`

Subscribes to events with optional filters.

## Parameters
- `event_types` - List of event types to subscribe to
- `opts` - Optional filters and options

## Returns
- `{:ok, ref}` - Subscription reference for later unsubscribe

# `subscribe_pid`

Subscribes a specific process to events.

# `trigger`

Triggers an event with type and payload (compatibility alias).

# `unregister_handler`

Unregisters an event handler.

# `unsubscribe`

Unsubscribes from events using the subscription reference.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
