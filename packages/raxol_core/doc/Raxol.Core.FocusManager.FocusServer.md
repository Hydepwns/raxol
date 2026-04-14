# `Raxol.Core.FocusManager.FocusServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/focus_manager/focus_server.ex#L1)

GenServer implementation for focus management.

Provides accessibility focus management with tab ordering,
focus history, and component registration.

# `t`

```elixir
@type t() :: %Raxol.Core.FocusManager.FocusServer{
  current_focus: binary() | nil,
  enabled_components: MapSet.t(),
  focus_handlers: list(),
  focus_history: list(),
  focusable_components: map(),
  tab_order: list()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `disable_component`

Disable a component from focus.

# `enable_component`

Enable a component for focus.

# `focus_next`

Focus next component in tab order.

# `focus_previous`

Focus previous component in tab order.

# `get_focus_history`

Get focus history.

# `get_focused_element`

Get currently focused element.

# `get_next_focusable`

Get next focusable component.

# `get_previous_focusable`

Get previous focusable component.

# `handle_manager_cast`

# `handle_manager_info`

# `has_focus?`

Check if component has focus.

# `register_focus_change_handler`

Register focus change handler.

# `register_focusable`

Register a focusable component.

# `return_to_previous`

Return to previous focus.

# `set_focus`

Set focus to a component.

# `set_initial_focus`

Set initial focus.

# `start_link`

# `unregister_focus_change_handler`

Unregister focus change handler.

# `unregister_focusable`

Unregister a focusable component.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
