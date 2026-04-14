# `Raxol.Core.Events.EventManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/events/event_manager.ex#L1)

Event management system that wraps :telemetry for backward compatibility.

This module provides a compatibility layer while migrating from a custom event
system to the standard :telemetry library. New code should use :telemetry directly.

## Migration Status
This module now delegates to :telemetry internally. The GenServer functionality
is maintained for backward compatibility but will be deprecated in a future version.

# `event_data`

```elixir
@type event_data() :: map()
```

# `event_type`

```elixir
@type event_type() :: atom()
```

# `filter_opts`

```elixir
@type filter_opts() :: keyword()
```

# `handler_fun`

```elixir
@type handler_fun() :: atom() | {module(), atom()} | function()
```

# `subscription_ref`

```elixir
@type subscription_ref() :: reference()
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `cleanup`

```elixir
@spec cleanup() :: :ok
```

Cleans up the event manager and all resources.

# `clear_handlers`

```elixir
@spec clear_handlers() :: :ok
```

Clears all registered handlers.

# `dispatch`

```elixir
@spec dispatch(
  {event_type(), event_data()}
  | {event_type(), term(), term()}
  | event_type()
) :: :ok
```

# `dispatch`

Dispatches an event using :telemetry.

This method now delegates to telemetry for event dispatching while maintaining
backward compatibility with the old API.

# `get_handlers`

```elixir
@spec get_handlers() :: list()
```

Gets all registered handlers.
Returns a list of handler entries.

# `init`

```elixir
@spec init() :: :ok
```

Initializes the event manager state.

# `notify`

```elixir
@spec notify(GenServer.server(), event_type(), event_data()) :: :ok
```

Notifies all registered handlers of an event.

# `register_handler`

```elixir
@spec register_handler(
  event_type() | [event_type()],
  pid() | module(),
  handler_fun()
) :: :ok
```

Registers a handler for specific event types.

## Examples

    register_handler(:keyboard, MyModule, :handle_keyboard)
    register_handler([:mouse, :touch], self(), :handle_input)

# `start_link`

# `subscribe`

```elixir
@spec subscribe([event_type()], filter_opts()) ::
  {:ok, subscription_ref()} | {:error, term()}
```

Subscribes to event streams with optional filtering.

## Examples

    {:ok, ref} = subscribe([:keyboard, :mouse])
    {:ok, ref} = subscribe([:focus], filter: [component_id: "main"])

# `unregister_handler`

```elixir
@spec unregister_handler(
  event_type() | [event_type()],
  pid() | module(),
  handler_fun()
) :: :ok
```

Unregisters a handler for specific event types.

# `unsubscribe`

```elixir
@spec unsubscribe(subscription_ref()) :: :ok
```

Unsubscribes from event streams.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
