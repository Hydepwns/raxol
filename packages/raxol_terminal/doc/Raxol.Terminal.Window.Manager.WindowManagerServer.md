# `Raxol.Terminal.Window.Manager.WindowManagerServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/window/manager/window_manager_server.ex#L1)

GenServer implementation for terminal window management in Raxol.

This server provides a pure functional approach to window management,
eliminating Process dictionary usage and implementing proper OTP patterns.

## Features
- Window creation, destruction, and lifecycle management
- Hierarchical window relationships (parent/child)
- Window state tracking (active, inactive, minimized, maximized)
- Window properties management (title, size, position)
- Icon management for windows
- Supervised state management with fault tolerance

## State Structure
The server maintains state with the following structure:
```elixir
%{
  windows: %{window_id => Window.t()},
  active_window: window_id | nil,
  window_order: [window_id],  # Z-order for stacking
  window_state: :normal | :minimized | :maximized | :fullscreen,
  window_size: {width, height},
  window_title: String.t(),
  icon_name: String.t(),
  icon_title: String.t(),
  spatial_map: %{},  # For spatial navigation
  navigation_paths: %{},  # Custom navigation paths
  next_window_id: integer()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `create_child_window`

Creates a child window.

# `create_window`

Creates a new window with the given configuration.

# `define_navigation_path`

Defines a navigation path between windows.

# `destroy_window`

Destroys a window by ID.

# `get_active_window`

Gets the active window.

# `get_child_windows`

Gets child windows.

# `get_parent_window`

Gets parent window.

# `get_state`

Gets the complete state (for debugging/migration).

# `get_window`

Gets a window by ID.

# `get_window_size`

Gets the window size.

# `get_window_state`

Gets the window manager state.

# `handle_manager_cast`

# `handle_manager_info`

# `list_windows`

Lists all windows.

# `move_window_to_back`

Moves a window to the back in Z-order.

# `move_window_to_front`

Moves a window in the Z-order.

# `register_window_position`

Registers a window's spatial position for navigation.

# `reset`

Resets to initial state.

# `set_active_window`

Sets the active window.

# `set_icon_name`

Sets the icon name.

# `set_icon_title`

Sets the icon title.

# `set_window_position`

Sets window position.

# `set_window_size`

Sets the window size.

# `set_window_size`

# `set_window_size`

Sets a specific window's size.

# `set_window_state`

Sets the window state (normal, minimized, maximized, fullscreen).

# `set_window_state`

# `set_window_state`

Sets a specific window's state.

# `set_window_title`

Sets the window title.

# `set_window_title`

# `set_window_title`

Sets a specific window's title.

# `split_window`

Split a window horizontally or vertically.

# `split_window`

# `start_link`

# `update_config`

Updates the window manager configuration.

# `update_config`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
