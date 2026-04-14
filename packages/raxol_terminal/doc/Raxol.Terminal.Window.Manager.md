# `Raxol.Terminal.Window.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/window/window_manager.ex#L1)

Refactored Window.Manager that delegates to GenServer implementation.

This module provides the same API as the original Terminal.Window.Manager but uses
a supervised GenServer instead of the Process dictionary for state management.

## Migration Notice
This module is a drop-in replacement for `Raxol.Terminal.Window.Manager`.
All functions maintain backward compatibility while providing improved
fault tolerance and functional programming patterns.

## Benefits over Process Dictionary
- Supervised state management with fault tolerance
- Pure functional window management
- Z-order window stacking support
- Spatial navigation mapping
- Better debugging and testing capabilities
- No global state pollution

## New Features
- Window Z-ordering for proper stacking
- Spatial position tracking for navigation
- Custom navigation paths between windows
- Hierarchical window relationships

# `t`

```elixir
@type t() :: %{tabs: map()}
```

# `window_id`

```elixir
@type window_id() :: String.t()
```

# `window_state`

```elixir
@type window_state() :: :active | :inactive | :minimized | :maximized
```

# `cleanup`

Cleanup the window manager. Alias for reset/0.

# `count_windows`

Counts the number of windows.

# `create_child_window`

Creates a child window.

# `create_window`

Creates a new window with the given configuration.

# `create_window`

Creates a new window with dimensions.

# `define_navigation_path`

Defines a navigation path between windows.

# `destroy_window`

Destroys a window by ID.

# `ensure_started`

Ensures the Window Manager server is started.

# `get_active_window`

Gets the active window.

# `get_child_windows`

Gets child windows of a parent.

# `get_parent_window`

Gets the parent window of a child.

# `get_state`

Gets the window manager state as a map.

# `get_window`

Gets a window by ID.

# `get_window_size`

Gets the window size.

# `get_window_state`

Gets the window state.

# `list_windows`

Lists all windows.

# `move`

Move a window to the specified position.

# `move_window_to_back`

Moves a window to the back (bottom of Z-order).

# `move_window_to_front`

Moves a window to the front (top of Z-order).

# `new`

Creates a new window manager instance.
For backward compatibility, returns {:ok, pid()} of the GenServer.

# `new_for_test`

Creates a new window manager instance for testing.
Returns a simple map structure instead of a process.

# `register_window_position`

Registers a window's spatial position for navigation.

# `reset`

Resets the window manager to initial state.

# `resize`

Resizes a window. Alias for set_window_size/3.

# `set_active_window`

Sets the active window.

# `set_icon_name`

Sets the icon name.

# `set_stacking_order`

Set the stacking order of a window.

# `set_title`

Set the title of a window.

# `set_window_position`

Sets the window position.

# `set_window_size`

Sets the window size.

# `set_window_state`

Sets the window state.

# `set_window_title`

Sets the window title.

# `split_window`

Split a window horizontally or vertically.

# `start_link`

Starts the window manager.

# `start_link`

# `update_config`

Updates the window manager configuration.

# `window_exists?`

Checks if a window exists.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
