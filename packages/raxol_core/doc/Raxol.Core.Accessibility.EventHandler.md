# `Raxol.Core.Accessibility.EventHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/accessibility/event_handler.ex#L1)

Handles accessibility-related events and notifications.

# `handle_focus_change`

# `handle_focus_change`

Handle focus change events for accessibility announcements.

## Examples

    iex> EventHandler.handle_focus_change({:focus_change, nil, "search_button"})
    :ok

# `handle_locale_changed`

Handle locale changes.

## Examples

    iex> EventHandler.handle_locale_changed({:locale_changed, %{locale: "en"}})
    :ok

# `handle_preference_changed`

Handle preference changes triggered internally or via EventManager.

## Examples

    iex> EventHandler.handle_preference_changed({:preference_changed, [:accessibility, :high_contrast], true})
    :ok

# `handle_theme_changed`

Handle theme changes.

## Examples

    iex> EventHandler.handle_theme_changed({:theme_changed, %{theme: "dark"}})
    :ok

---

*Consult [api-reference.md](api-reference.md) for complete listing*
