# `Raxol.Core.Preferences.Store`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/preferences/store.ex#L1)

Handles storage and retrieval of user preferences.

# `get_all_preferences`

Retrieves all user preferences as a map.

# `get_preference`

Retrieves a user preference by key or key path.
Example: get_preference(:theme) or get_preference([:accessibility, :high_contrast])

# `reset_preferences`

Resets all preferences to defaults (by clearing and saving defaults).

# `save_to_preferences`

```elixir
@spec save_to_preferences(map() | struct()) :: :ok
```

# `set_preference`

Sets a user preference by key or key path.
Example: set_preference(:theme, "dark") or set_preference([:accessibility, :high_contrast], true)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
