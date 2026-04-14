# `Raxol.Core.Accessibility.Preferences`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/accessibility/preferences.ex#L1)

Manages accessibility preferences and settings.

# `default_prefs_name`

Get the default preferences name.

## Examples

    iex> Preferences.default_prefs_name()
    Raxol.Core.UserPreferences

# `get_option`

Get an accessibility option value.

## Parameters

* `option_name` - The atom representing the accessibility option (e.g., `:high_contrast`).
* `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).
* `default` - The default value to return if the option is not set (optional).

## Examples

    iex> Preferences.get_option(:high_contrast)
    false

# `get_text_scale`

Get the current text scale factor based on the large text setting.

## Parameters

* `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

## Examples

    iex> Preferences.get_text_scale()
    1.0 # or 1.5 if large_text is enabled

# `handle_preference_changed`

# `set_high_contrast`

Enable or disable high contrast mode.

## Parameters

* `enabled` - `true` to enable high contrast, `false` to disable.
* `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

## Examples

    iex> Preferences.set_high_contrast(true)
    :ok

# `set_large_text`

Enable or disable large text mode.

## Parameters

* `enabled` - `true` to enable large text, `false` to disable.
* `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

## Examples

    iex> Preferences.set_large_text(true)
    :ok

# `set_option`

Set an accessibility option value.

## Parameters

* `key` - The option key to set
* `value` - The value to set
* `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

## Examples

    iex> Preferences.set_option(:high_contrast, true)
    :ok

# `set_reduced_motion`

Enable or disable reduced motion.

## Parameters

* `enabled` - `true` to enable reduced motion, `false` to disable.
* `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

## Examples

    iex> Preferences.set_reduced_motion(true)
    :ok

---

*Consult [api-reference.md](api-reference.md) for complete listing*
