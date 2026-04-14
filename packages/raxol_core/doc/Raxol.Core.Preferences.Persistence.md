# `Raxol.Core.Preferences.Persistence`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/preferences/persistence.ex#L1)

Handles persistence (loading/saving) of user preferences to a file.

# `load`

Loads user preferences from the designated file.

Returns:
  - `{:ok, preferences_map}` if successful.
  - `{:error, :file_not_found}` if the file doesn't exist.
  - `{:error, reason}` for other file or decoding errors.

# `preferences_path`

Returns the full path to the user preferences file.
Uses an application-specific directory.

# `save`

Saves the given preferences map to the designated file.

Serializes the map using `:erlang.term_to_binary`.

Returns:
  - `:ok` on success.
  - `{:error, reason}` on failure.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
