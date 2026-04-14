# `Raxol.Terminal.Config.Profiles`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/config/profiles.ex#L1)

Terminal configuration profile management.

Allows users to define, save, load, and switch between different
terminal configuration profiles.

# `animation_type`

```elixir
@type animation_type() :: :gif | :video | :shader | :particle
```

# `background_type`

```elixir
@type background_type() :: :solid | :transparent | :image | :animated
```

# `color_mode`

```elixir
@type color_mode() :: :basic | :true_color | :palette
```

# `config`

```elixir
@type config() :: map()
```

# `terminal_type`

```elixir
@type terminal_type() ::
  :iterm2
  | :windows_terminal
  | :xterm
  | :screen
  | :kitty
  | :alacritty
  | :konsole
  | :gnome_terminal
  | :vscode
  | :unknown
```

# `theme_map`

```elixir
@type theme_map() :: %{required(atom()) =&gt; String.t()}
```

# `create_default_profile`

Creates a new profile with default settings.

## Parameters

* `name` - The name of the new profile

## Returns

`{:ok, config}` or `{:error, reason}`

# `delete_profile`

Deletes a terminal configuration profile.

## Parameters

* `name` - The name of the profile to delete

## Returns

`:ok` or `{:error, reason}`

# `duplicate_profile`

Duplicates an existing profile with a new name.

## Parameters

* `source_name` - The name of the profile to duplicate
* `target_name` - The name for the new profile

## Returns

`{:ok, config}` or `{:error, reason}`

# `list_profiles`

Lists all available terminal configuration profiles.

## Returns

A list of profile names.

# `load_profile`

Loads a specific terminal configuration profile.

## Parameters

* `name` - The name of the profile to load

## Returns

`{:ok, config}` or `{:error, reason}`

# `save_profile`

Saves the current configuration as a profile.

## Parameters

* `name` - The name of the profile to save
* `config` - The configuration to save

## Returns

`:ok` or `{:error, reason}`

# `update_profile`

Updates an existing profile with new settings.

## Parameters

* `name` - The name of the profile to update
* `config` - The new configuration

## Returns

`:ok` or `{:error, reason}`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
