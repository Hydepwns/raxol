# `Raxol.Core.UserPreferences`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/user_preferences.ex#L1)

Manages user preferences for the terminal emulator.

Acts as a GenServer holding the preferences state and handles persistence.

Uses `Raxol.Core.Utils.Debounce` for debounced save operations, avoiding
redundant disk writes when multiple preference changes occur in quick succession.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `default_preferences`

Returns the default preferences map.
This includes default values for theme, terminal configuration, accessibility settings,
and keybindings.

# `get`

# `get_all`

# `get_theme_id`

Returns the current theme id as an atom, defaulting to :default if not set or invalid.

# `handle_manager_cast`

# `reset_to_defaults_for_test!`

# `save!`

# `set`

# `set_preferences`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
