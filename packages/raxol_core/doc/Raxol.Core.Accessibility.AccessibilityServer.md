# `Raxol.Core.Accessibility.AccessibilityServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/accessibility/accessibility_server.ex#L1)

Unified GenServer implementation for accessibility features in Raxol.

This server consolidates all accessibility state management, eliminating
Process dictionary usage across Accessibility, Announcements, and Metadata modules.

## Features
- Screen reader announcements with queuing and priority
- High contrast mode management
- Reduced motion support
- Large text support
- Keyboard focus indicators
- Accessibility metadata tracking
- User preference integration
- Theme integration for accessibility
- Announcement history tracking

## Sub-modules
- `AnnouncementQueue`  -- queue, priority, history, delivery
- `PreferenceManager`  -- preference merge/sync/notify
- `MetadataRegistry`   -- element/component metadata and style registration
- `FocusManager`       -- focus tracking, history, and focus announcements

# `add_announcement`

Adds an announcement to the queue.

# `add_announcement`

# `announce`

```elixir
@spec announce(GenServer.server(), String.t(), keyword()) :: :ok
```

Makes an announcement for screen readers.

## Options
- `:priority` - Priority level (:high, :medium, :low) default: :medium
- `:interrupt` - Whether to interrupt current announcement default: false
- `:language` - Language for the announcement

# `announce_sync`

```elixir
@spec announce_sync(GenServer.server(), String.t(), keyword()) :: :ok
```

Announces with synchronous confirmation.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear_all_announcements`

Clears all announcements from the queue.

# `clear_all_announcements`

# `clear_announcement_history`

Clears announcement history.

# `clear_announcements`

Clears announcements for a specific user.

# `clear_announcements`

# `disable`

```elixir
@spec disable(GenServer.server()) :: :ok
```

Disables accessibility features.

# `enable`

```elixir
@spec enable(GenServer.server(), keyword(), atom() | pid() | nil) :: :ok
```

Enables accessibility features with the given options.

# `enabled?`

```elixir
@spec enabled?(GenServer.server()) :: boolean()
```

Checks if accessibility is enabled.

# `get_announcement_history`

Gets announcement history.

# `get_component_hint`

Gets a component hint.

# `get_component_hint`

# `get_component_style`

Gets component style.

# `get_component_style`

# `get_element_metadata`

Gets element metadata for a component.

# `get_focus_history`

Gets focus history.

# `get_focus_history`

# `get_metadata`

Gets accessibility metadata for a component.

# `get_next_announcement`

Gets the next announcement from the queue.

# `get_next_announcement`

# `get_option`

Gets an option value.

# `get_option`

# `get_preferences`

```elixir
@spec get_preferences(GenServer.server()) :: map()
```

Gets all current preferences.

# `get_state`

Gets the current state (for debugging/testing).

# `handle_focus_change`

Handles focus change events.

# `handle_focus_change_event`

# `handle_focus_change_event`

# `handle_focus_change_event`

# `handle_preference_changed_event`

# `handle_theme_changed_event`

# `high_contrast?`

```elixir
@spec high_contrast?(GenServer.server()) :: boolean()
```

Gets high contrast mode status.

# `large_text?`

```elixir
@spec large_text?(GenServer.server()) :: boolean()
```

Gets large text mode status.

# `reduced_motion?`

```elixir
@spec reduced_motion?(GenServer.server()) :: boolean()
```

Gets reduced motion mode status.

# `register_component_style`

Registers component style.

# `register_component_style`

# `register_element_metadata`

Registers element metadata for a component.

# `remove_metadata`

Removes metadata for a component.

# `reset`

```elixir
@spec reset(GenServer.server()) :: :ok
```

Resets the accessibility server to its default state (for test isolation).

# `screen_reader?`

```elixir
@spec screen_reader?(GenServer.server()) :: boolean()
```

Gets screen reader support status.

# `set_announcement_callback`

Sets the announcement callback function.

# `set_high_contrast`

```elixir
@spec set_high_contrast(GenServer.server(), boolean()) :: :ok
```

Sets high contrast mode.

# `set_keyboard_focus`

```elixir
@spec set_keyboard_focus(GenServer.server(), boolean()) :: :ok
```

Sets keyboard focus indicators.

# `set_large_text`

```elixir
@spec set_large_text(GenServer.server(), boolean()) :: :ok
```

Sets large text mode.

# `set_large_text_with_prefs`

# `set_metadata`

Sets accessibility metadata for a component.

# `set_option`

Sets an option value.

# `set_option`

# `set_reduced_motion`

```elixir
@spec set_reduced_motion(GenServer.server(), boolean()) :: :ok
```

Sets reduced motion mode.

# `set_screen_reader`

```elixir
@spec set_screen_reader(GenServer.server(), boolean()) :: :ok
```

Sets screen reader support.

# `should_announce?`

```elixir
@spec should_announce?(atom() | pid() | nil) :: boolean()
```

Checks if announcements should be made.

# `start_link`

# `unregister_component_style`

Unregisters component style.

# `unregister_component_style`

# `unregister_element_metadata`

Unregisters element metadata.

# `unregister_element_metadata`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
