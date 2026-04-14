# `Raxol.Core.KeyboardNavigator`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/keyboard_navigator.ex#L1)

Refactored KeyboardNavigator that delegates to GenServer implementation.

This module provides the same API as the original KeyboardNavigator but uses
a supervised GenServer instead of the Process dictionary for state management.

## Migration Notice
This module is a drop-in replacement for `Raxol.Core.KeyboardNavigator`.
All functions maintain backward compatibility while providing improved
fault tolerance and functional programming patterns.

## Benefits over Process Dictionary
- Supervised state management with fault tolerance
- Pure functional navigation logic
- Spatial navigation with efficient neighbor calculation
- Navigation history stack for back navigation
- Group-based navigation support
- Better debugging and testing capabilities
- No global state pollution

## New Features
- Focus stack for back navigation
- Component grouping for logical navigation
- Enhanced spatial navigation algorithms
- Configurable navigation strategies

# `clear_navigation_paths`

Clear all navigation paths.

# `clear_spatial_map`

Clear all spatial mappings.

# `configure`

Configure keyboard navigation behavior.

## Options
- `:next_key` - Key to move to next element (default: `:tab`)
- `:previous_key` - Key to move to previous element (default: `:tab` with shift)
- `:activate_keys` - Keys to activate elements (default: `[:enter, :space]`)
- `:dismiss_key` - Key to dismiss or go back (default: `:escape`)
- `:arrow_navigation` - Enable arrow key navigation (default: `true`)
- `:vim_keys` - Enable vim-style navigation with h,j,k,l (default: `false`)
- `:group_navigation` - Enable group-based navigation (default: `true`)
- `:spatial_navigation` - Enable spatial navigation for grid layouts (default: `false`)
- `:tab_navigation` - Enable tab-based navigation (default: `true`)

# `define_navigation_path`

Define explicit navigation paths between components.

This allows customizing navigation beyond spatial or tab order.

## Parameters
- `from_id` - Component ID to navigate from
- `direction` - Navigation direction (`:up`, `:down`, `:left`, `:right`)
- `to_id` - Component ID to navigate to

# `ensure_started`

Ensures the Keyboard Navigator server is started.

# `get_config`

Gets the current configuration.

For backward compatibility with Process dictionary version.

# `get_navigation_paths`

Gets navigation paths.

For backward compatibility with Process dictionary version.

# `get_spatial_map`

Gets the spatial map.

For backward compatibility with Process dictionary version.

# `handle_keyboard_event`

Handle keyboard events for navigation.

This function is called by the EventManager when keyboard events occur.
The actual processing is delegated to the server.

# `init`

Initialize the keyboard navigator.

This registers event handlers for keyboard navigation.

# `pop_focus`

Pop and return to the previous focus.

Returns the component ID that was restored, or nil if stack was empty.

# `push_focus`

Push current focus to the navigation stack.

Useful for modal dialogs or nested navigation contexts.

# `register_component_position`

Register component positions for spatial navigation.

This allows arrow keys to navigate components based on their physical layout.

# `register_to_group`

Register a component to a navigation group.

Groups allow logical navigation between related components.

# `reset`

Reset the navigator to initial state.

# `unregister_from_group`

Unregister a component from a navigation group.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
