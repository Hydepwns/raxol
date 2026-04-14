# `Raxol.Core.Accessibility`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/accessibility.ex#L1)

Refactored Accessibility module that delegates to the unified GenAccessibilityServer.

This module provides the same API as the original Accessibility module but uses
a supervised GenServer instead of the Process dictionary for state management.

## Migration Notice
This module is a drop-in replacement for `Raxol.Core.Accessibility`.
All functions maintain backward compatibility while providing improved
fault tolerance and functional programming patterns.

## Benefits over Process Dictionary
- Unified state management across all accessibility features
- Supervised state with fault tolerance
- Pure functional transformations
- Announcement queuing with priority
- Better debugging and testing capabilities
- No global state pollution

## Consolidated Modules
This refactored version consolidates functionality from:
- `Raxol.Core.Accessibility`
- `Raxol.Core.Accessibility.Announcements`
- `Raxol.Core.Accessibility.Metadata`

# `announce`

Make an announcement for screen readers.

## Options
- `:priority` - Priority level (:high, :medium, :low) default: :medium
- `:interrupt` - Whether to interrupt current announcement default: false
- `:language` - Language for the announcement

# `announce`

Make an announcement with user preferences (behaviour callback).

# `announce_activation`

```elixir
@spec announce_activation(term()) :: :ok
```

Announce component activation.

# `announce_sync`

```elixir
@spec announce_sync(
  String.t(),
  keyword()
) :: :ok
```

Announce with synchronous confirmation.

# `announce_value_change`

```elixir
@spec announce_value_change(term(), term(), term()) :: :ok
```

Announce value change.

# `any_feature_active?`

```elixir
@spec any_feature_active?() :: boolean()
```

Check if any accessibility feature is active.

# `clear_announcement_history`

```elixir
@spec clear_announcement_history() :: :ok
```

Clear announcement history.

# `clear_announcements`

Clear all announcements (behaviour callback).

# `disable`

Disable accessibility features.

# `enable`

Enable accessibility features with the given options.

## Options
- `:high_contrast` - Enable high contrast mode (default: `false`)
- `:reduced_motion` - Enable reduced motion (default: `false`)
- `:large_text` - Enable large text (default: `false`)
- `:screen_reader` - Enable screen reader support (default: `true`)
- `:keyboard_focus` - Enable keyboard focus indicators (default: `true`)
- `:silence_announcements` - Silence screen reader announcements (default: `false`)

# `enabled?`

Check if accessibility features are enabled.

# `enabled?`

# `ensure_started`

```elixir
@spec ensure_started() :: :ok
```

Ensures the Accessibility server is started.

# `get_announcement_history`

```elixir
@spec get_announcement_history(non_neg_integer() | nil) :: [map()]
```

Get announcement history.

# `get_metadata`

```elixir
@spec get_metadata(term()) :: map() | nil
```

Get accessibility metadata for a component.

# `get_option`

# `get_preferences`

```elixir
@spec get_preferences() :: map()
```

Get all accessibility preferences.

# `get_text_scale`

```elixir
@spec get_text_scale(atom() | pid() | nil) :: float()
```

# `handle_focus_change_event`

```elixir
@spec handle_focus_change_event({:focus_change, term(), term()}) :: :ok
```

Handle focus change event.

# `handle_locale_changed_event`

# `handle_preference_changed_event`

# `handle_theme_changed_event`

# `high_contrast?`

```elixir
@spec high_contrast?() :: boolean()
```

Check if high contrast mode is enabled.

# `high_contrast_enabled?`

```elixir
@spec high_contrast_enabled?(atom() | pid()) :: boolean()
```

# `init`

```elixir
@spec init(keyword()) :: :ok
```

Initialize accessibility with the given options.

# `large_text?`

```elixir
@spec large_text?() :: boolean()
```

Check if large text mode is enabled.

# `large_text_enabled?`

```elixir
@spec large_text_enabled?(atom() | pid()) :: boolean()
```

# `reduced_motion?`

```elixir
@spec reduced_motion?() :: boolean()
```

Check if reduced motion mode is enabled.

# `reduced_motion_enabled?`

```elixir
@spec reduced_motion_enabled?(atom() | pid()) :: boolean()
```

# `remove_metadata`

```elixir
@spec remove_metadata(term()) :: :ok
```

Remove metadata for a component.

# `reset`

```elixir
@spec reset() :: :ok
```

Reset all accessibility settings to defaults.

# `screen_reader?`

```elixir
@spec screen_reader?() :: boolean()
```

Check if screen reader support is enabled.

# `set_announcement_callback`

```elixir
@spec set_announcement_callback((String.t() -&gt; any())) :: :ok
```

Set announcement callback function.

# `set_enabled`

```elixir
@spec set_enabled(boolean()) :: :ok
```

# `set_high_contrast`

```elixir
@spec set_high_contrast(boolean()) :: :ok
```

Set high contrast mode.

# `set_high_contrast`

```elixir
@spec set_high_contrast(boolean(), atom() | pid()) :: :ok
```

# `set_keyboard_focus`

```elixir
@spec set_keyboard_focus(boolean()) :: :ok
```

Set keyboard focus indicators.

# `set_large_text`

```elixir
@spec set_large_text(boolean()) :: :ok
```

Set large text mode.

# `set_large_text`

Set large text mode with user preferences (behaviour callback).

# `set_metadata`

```elixir
@spec set_metadata(term(), map()) :: :ok
```

Set accessibility metadata for a component.

## Metadata fields
- `:label` - Accessible label for the component
- `:role` - ARIA role (button, navigation, etc.)
- `:description` - Extended description
- `:hint` - Usage hint for screen readers
- `:state` - Current state (expanded, selected, etc.)

# `set_reduced_motion`

```elixir
@spec set_reduced_motion(boolean()) :: :ok
```

Set reduced motion mode.

# `set_reduced_motion`

```elixir
@spec set_reduced_motion(boolean(), atom() | pid()) :: :ok
```

# `set_screen_reader`

```elixir
@spec set_screen_reader(boolean()) :: :ok
```

Set screen reader support.

# `subscribe_to_announcements`

```elixir
@spec subscribe_to_announcements(reference()) :: :ok
```

Subscribe to announcement events. Returns :ok.
The subscriber will receive `{:announcement_added, ref, message}` messages.

# `unsubscribe_from_announcements`

```elixir
@spec unsubscribe_from_announcements(reference()) :: :ok
```

Unsubscribe from announcement events.

# `update_metadata`

```elixir
@spec update_metadata(term(), atom(), term()) :: :ok
```

Update a specific metadata field for a component.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
