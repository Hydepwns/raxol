# `Raxol.Terminal.Theme.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/theme/theme_manager.ex#L1)

Manages terminal themes with advanced features:
- Theme loading from files and presets
- Theme customization and modification
- Dynamic theme switching
- Theme persistence and state management

## Unified Theme System

Themes are sourced from `Raxol.Core.Theming.ThemeRegistry`, which
provides a single source of truth for all Raxol themes. Use
`load_from_registry/2` to load any registered theme.

## Usage

    manager = Raxol.Terminal.Theme.Manager.new()

    # Load a theme from the unified registry
    {:ok, manager} = Raxol.Terminal.Theme.Manager.load_from_registry(manager, :dracula)

    # Get a style
    {:ok, style, manager} = Raxol.Terminal.Theme.Manager.get_style(manager, :normal)

# `color`

```elixir
@type color() :: %{r: integer(), g: integer(), b: integer(), a: float()}
```

# `style`

```elixir
@type style() :: %{
  foreground: color(),
  background: color(),
  bold: boolean(),
  italic: boolean(),
  underline: boolean()
}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Theme.Manager{
  current_theme: theme(),
  custom_styles: %{required(String.t()) =&gt; style()},
  metrics: %{
    theme_switches: integer(),
    style_applications: integer(),
    customizations: integer(),
    load_operations: integer()
  },
  themes: %{required(String.t()) =&gt; theme()}
}
```

# `theme`

```elixir
@type theme() :: %{
  name: String.t(),
  description: String.t(),
  author: String.t(),
  version: String.t(),
  colors: %{
    background: color(),
    foreground: color(),
    cursor: color(),
    selection: color(),
    black: color(),
    red: color(),
    green: color(),
    yellow: color(),
    blue: color(),
    magenta: color(),
    cyan: color(),
    white: color(),
    bright_black: color(),
    bright_red: color(),
    bright_green: color(),
    bright_yellow: color(),
    bright_blue: color(),
    bright_magenta: color(),
    bright_cyan: color(),
    bright_white: color()
  },
  styles: %{
    normal: style(),
    bold: style(),
    italic: style(),
    underline: style(),
    cursor: style(),
    selection: style()
  }
}
```

# `add_custom_style`

```elixir
@spec add_custom_style(t(), String.t(), style()) :: {:ok, t()} | {:error, term()}
```

Adds a custom style to the current theme.

# `get_metrics`

```elixir
@spec get_metrics(t()) :: map()
```

Gets the current theme metrics.

# `get_style`

```elixir
@spec get_style(t(), String.t() | atom()) :: {:ok, style(), t()} | {:error, term()}
```

Gets a style from the current theme or custom styles.

# `list_registry_themes`

```elixir
@spec list_registry_themes() :: [atom()]
```

Lists all themes available in the unified registry.

# `load_from_registry`

```elixir
@spec load_from_registry(t(), atom()) :: {:ok, t()} | {:error, :theme_not_found}
```

Loads a theme from the unified theme registry.

This is the preferred way to load themes as it uses the single
source of truth for all Raxol theme definitions.

## Examples

    {:ok, manager} = Manager.load_from_registry(manager, :dracula)
    {:ok, manager} = Manager.load_from_registry(manager, :synthwave84)

# `load_theme`

```elixir
@spec load_theme(t(), String.t()) :: {:ok, t()} | {:error, term()}
```

Loads a theme from a file or preset.

# `new`

```elixir
@spec new(keyword()) :: t()
```

Creates a new theme manager with the given options.

# `restore_theme_state`

```elixir
@spec restore_theme_state(t(), map()) :: {:ok, t()} | {:error, term()}
```

Restores a theme state from saved data.

# `save_theme_state`

```elixir
@spec save_theme_state(t()) :: {:ok, map()}
```

Saves the current theme state for persistence.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
