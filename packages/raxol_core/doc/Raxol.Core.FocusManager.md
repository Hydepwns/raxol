# `Raxol.Core.FocusManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/focus_manager.ex#L1)

Refactored FocusManager that delegates to GenServer implementation.

This module provides the same API as the original FocusManager but uses
a supervised GenServer instead of the Process dictionary for state management.

## Migration Notice
This module is a drop-in replacement for `Raxol.Core.FocusManager`.
All functions maintain backward compatibility while providing improved
fault tolerance and functional programming patterns.

## Benefits over Process Dictionary
- Supervised state management with fault tolerance
- Pure functional transformations
- Better debugging and testing capabilities
- Clear separation of concerns
- No global state pollution

# `disable_component`

Disable a focusable component, preventing it from receiving focus.

# `enable_component`

Enable a previously disabled focusable component.

# `ensure_started`

Ensures the FocusManager server is started.
Called automatically when using any function.

# `focus_next`

Move focus to the next focusable element.

# `focus_previous`

Move focus to the previous focusable element.

# `get_current_focus`

Alias for get_focused_element/0.

# `get_focus_history`

Gets the focus history.

# `get_focused_element`

Get the ID of the currently focused element.

# `get_next_focusable`

Get the next focusable element after the given one.

# `get_previous_focusable`

Get the previous focusable element before the given one.

# `has_focus?`

Check if a component has focus.

# `register_focus_change_handler`

Register a handler function to be called when focus changes.

# `register_focusable`

Register a focusable component with the focus manager.

# `return_to_previous`

Return to the previously focused element.

# `set_focus`

Set focus to a specific component.

# `set_initial_focus`

Set the initial focus to a specific component.

# `unregister_focus_change_handler`

Unregister a focus change handler function.

# `unregister_focusable`

Unregister a focusable component.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
