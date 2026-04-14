# `Raxol.Terminal.Events`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/events.ex#L1)

Global event management for terminal interactions.

This module provides a centralized event system for handling global terminal
events such as clicks, keyboard input, and other user interactions that need
to be processed at the application level.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `handle_manager_info`

# `register_global_click`

Registers a global click handler that will be called whenever a click occurs.

## Parameters
  - `handler` - A function that takes a click position and handles the event

## Examples

    Raxol.Terminal.Events.register_global_click(fn {x, y} ->
      Log.info("Clicked at #{x}, #{y}")
    end)

# `start_link`

# `trigger_click`

Triggers a click event at the given position.

This will call all registered click handlers.

# `unregister_global_click`

Unregisters a previously registered click handler.

## Parameters
  - `ref` - The reference returned from register_global_click

---

*Consult [api-reference.md](api-reference.md) for complete listing*
