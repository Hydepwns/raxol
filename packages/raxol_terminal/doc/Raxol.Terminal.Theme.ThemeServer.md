# `Raxol.Terminal.Theme.ThemeServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/theme/theme_server.ex#L1)

Unified theme system for the Raxol terminal emulator.
Handles theme management, preview, switching, and customization.

# `theme_id`

```elixir
@type theme_id() :: String.t()
```

# `theme_state`

```elixir
@type theme_state() :: %{
  id: theme_id(),
  name: String.t(),
  version: String.t(),
  description: String.t(),
  author: String.t(),
  colors: map(),
  font: map(),
  cursor: map(),
  padding: map(),
  status: :active | :inactive | :error,
  error: String.t() | nil
}
```

# `apply_theme`

Applies a theme to the terminal.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `export_theme`

Exports a theme to a file.

# `get_theme_state`

Gets the state of a theme.

# `get_themes`

Gets all loaded themes.

# `handle_manager_cast`

# `handle_manager_info`

# `import_theme`

Imports a theme from a file.

# `load_theme`

Loads a theme from a file or directory.

# `preview_theme`

Previews a theme without applying it.

# `start_link`

# `unload_theme`

Unloads a theme by ID.

# `update_theme_config`

Updates a theme's configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
