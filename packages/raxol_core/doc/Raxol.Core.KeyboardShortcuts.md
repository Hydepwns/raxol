# `Raxol.Core.KeyboardShortcuts`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/keyboard_shortcuts.ex#L1)

Refactored KeyboardShortcuts that delegates to GenServer implementation.

This module provides the same API as the original KeyboardShortcuts but uses
a supervised GenServer instead of the Process dictionary for state management.

## Migration Notice
This module is a drop-in replacement for `Raxol.Core.KeyboardShortcuts`.
All functions maintain backward compatibility while providing improved
fault tolerance and functional programming patterns.

## Benefits over Process Dictionary
- Supervised state management with fault tolerance
- Pure functional shortcut resolution
- Priority-based conflict resolution
- Context-aware shortcut activation
- Better debugging and testing capabilities
- No global state pollution

# `cleanup`

Clean up the keyboard shortcuts manager.

This function cleans up any resources used by the keyboard shortcuts manager
and unregisters event handlers.

# `clear_all`

Clear all shortcuts.

# `clear_context`

Clear shortcuts for a specific context.

# `enabled?`

Check if shortcuts are enabled.

# `ensure_started`

Ensures the Keyboard Shortcuts server is started.

# `get_active_context`

Get the currently active context.

# `get_available_shortcuts`

Get all available shortcuts (global + active context).

# `get_shortcuts_for_context`

Get all shortcuts for a specific context.

Returns a map of shortcut definitions for the given context.

# `get_shortcuts_help`

Get formatted help text for shortcuts.

# `handle_keyboard_event`

Handle keyboard events.

This function is called by the EventManager when keyboard events occur.

# `init`

Initialize the keyboard shortcuts manager.

This function sets up the necessary state for managing keyboard shortcuts
and registers event handlers for keyboard events.

# `register_batch`

Register a batch of shortcuts at once.

## Example
```elixir
register_batch([
  {"Ctrl+S", :save, &save_file/0, description: "Save file"},
  {"Ctrl+O", :open, &open_file/0, description: "Open file"},
  {"Ctrl+Q", :quit, &quit_app/0, description: "Quit application"}
])
```

# `register_shortcut`

Register a keyboard shortcut with a callback function.

## Parameters
- `shortcut` - The keyboard shortcut string (e.g., "Ctrl+S", "Alt+F4")
- `name` - A unique identifier for the shortcut (atom or string)
- `callback` - A function to be called when the shortcut is triggered
- `opts` - Options for the shortcut

## Options
- `:context` - The context in which this shortcut is active (default: `:global`)
- `:description` - A description of what the shortcut does
- `:priority` - Priority level (1-10, lower = higher priority)
- `:override` - Whether to override existing shortcut (default: false)

# `set_active_context`

Set the active context for shortcuts.

Context-specific shortcuts will only be active when their context is set.

# `set_conflict_resolution`

Set conflict resolution strategy.

## Strategies
- `:first` - Keep the first registered shortcut
- `:last` - Keep the last registered shortcut
- `:priority` - Use priority to resolve conflicts

# `set_enabled`

Enable or disable shortcut processing.

# `shortcut_registered?`

Check if a shortcut is registered.

# `show_shortcuts_help`

Show help text for available shortcuts.

Displays formatted help text for all available shortcuts in the current context.

# `unregister_shortcut`

Unregister a keyboard shortcut.

## Parameters
- `shortcut` - The keyboard shortcut string to unregister
- `context` - The context from which to unregister (default: `:global`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
