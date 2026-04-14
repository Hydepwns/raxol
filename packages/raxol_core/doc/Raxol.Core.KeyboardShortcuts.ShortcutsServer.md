# `Raxol.Core.KeyboardShortcuts.ShortcutsServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/keyboard_shortcuts/shortcuts_server.ex#L1)

GenServer implementation for keyboard shortcuts management.

Provides state management for keyboard shortcuts with context awareness,
priority handling, and functional pattern resolution.

# `t`

```elixir
@type t() :: %Raxol.Core.KeyboardShortcuts.ShortcutsServer{
  active_context: atom(),
  enabled: boolean(),
  priority_maps: map(),
  shortcuts: map()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear_all`

Clear all shortcuts.

# `clear_context`

Clear context shortcuts.

# `enabled?`

Check if shortcuts are enabled.

# `generate_shortcuts_help`

Generate shortcuts help.

# `generate_shortcuts_help`

# `get_active_context`

Get active context.

# `get_available_shortcuts`

Get available shortcuts.

# `get_shortcuts_for_context`

Get shortcuts for context.

# `handle_keyboard_event`

Handle keyboard event.

# `handle_manager_cast`

# `handle_manager_info`

# `init_shortcuts`

Initialize shortcuts configuration.

# `register_shortcut`

Register a keyboard shortcut.

# `set_active_context`

Set active context.

# `set_conflict_resolution`

Set conflict resolution strategy.

# `set_enabled`

Set enabled state.

# `start_link`

# `unregister_shortcut`

Unregister a shortcut.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
