# `Raxol.Core.KeyboardNavigator.NavigatorServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/keyboard_navigator/navigator_server.ex#L1)

BaseManager implementation for keyboard navigation in Raxol terminal UI applications.

This server provides a pure functional approach to keyboard navigation,
eliminating Process dictionary usage and implementing proper OTP patterns.

## Features
- Tab-based keyboard navigation between focusable elements
- Arrow key navigation for spatial layouts
- Vim-style navigation support (h,j,k,l)
- Custom navigation paths between components
- Group-based navigation
- Spatial navigation for grid layouts
- Configurable key bindings
- Supervised state management with fault tolerance

## State Structure
The server maintains state with the following structure:
```elixir
%{
  config: %{
    next_key: :tab,
    previous_key: :tab,  # with shift modifier
    activate_keys: [:enter, :space],
    dismiss_key: :escape,
    arrow_navigation: true,
    vim_keys: false,
    group_navigation: true,
    spatial_navigation: false,
    tab_navigation: true
  },
  spatial_map: %{component_id => position_data},
  navigation_paths: %{from_id => %{direction => to_id}},
  focus_stack: [],  # Navigation history for back navigation
  groups: %{group_name => [component_ids]}
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `configure`

Configures keyboard navigation behavior.

# `define_navigation_path`

Defines an explicit navigation path between components.

# `get_config`

Gets the current configuration.

# `get_navigation_paths`

Gets navigation paths.

# `get_spatial_map`

Gets the spatial map.

# `get_state`

Gets the current state (for debugging/testing).

# `handle_keyboard_event`

Handles keyboard events for navigation.
This is typically called by the EventManager.

# `handle_manager_info`

# `init_navigator`

Initializes the keyboard navigator.
Registers event handlers for keyboard navigation.

# `pop_focus`

Pops and returns to the previous focus.

# `push_focus`

Pushes current focus to the stack (for back navigation).

# `register_component_position`

Registers a component's position for spatial navigation.

# `register_to_group`

Registers a component to a navigation group.

# `reset`

Resets to initial state.

# `start_link`

# `unregister_from_group`

Unregisters a component from a navigation group.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
