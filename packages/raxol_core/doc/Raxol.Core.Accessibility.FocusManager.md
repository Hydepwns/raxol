# `Raxol.Core.Accessibility.FocusManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/accessibility/focus_manager.ex#L1)

Pure-functional helpers for focus tracking, announcements, and
event handler registration within the AccessibilityServer state.

# `create_focus_announcement`

Creates a focus announcement string from element metadata, or nil.

# `get_focus_history`

Returns the focus history stored in metadata.

# `handle_focus_announcement`

Handles a focus change by looking up the new focus element's metadata
and potentially enqueuing a focus announcement.

Returns `{:noreply, new_state}`.

# `register_event_handlers`

Registers accessibility event handlers with EventManager for the given server module.

# `unregister_event_handlers`

Unregisters accessibility event handlers from EventManager for the given server module.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
