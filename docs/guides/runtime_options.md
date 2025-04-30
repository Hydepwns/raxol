# Raxol Runtime Options

When starting your Raxol application using the `Raxol.Core.Runtime.Lifecycle.start_application/2` function, you can pass various options to configure the runtime behavior and initial setup.

These options are typically provided as a keyword list in the second argument.

## Starting Raxol

The recommended way to start a standalone Raxol application is using `Raxol.Core.Runtime.Lifecycle.start_application/2`. This function takes your application module as the first argument and an options keyword list as the second.

It handles setting up the necessary supervision tree and runtime processes.

```elixir
defmodule MyApp do
  use Raxol.Core.Runtime.Application
  # ... implement callbacks ...
end

# Example using Raxol.Core.Runtime.Lifecycle.start_application/2
opts = [
  title: "My Custom App",
  fps: 30,
  quit_keys: [:ctrl_c, "q"],
  debug: true
]
{:ok, pid} = Raxol.Core.Runtime.Lifecycle.start_application(MyApp, opts)
```

Starting the application directly under your own supervisor is more complex and typically not required, as `start_application/2` manages the core runtime supervisor.

## Available Options

These options are passed as a keyword list (the second argument) to `Raxol.Core.Runtime.Lifecycle.start_application/2`.

- `:title`

  - **Optional**
  - Sets the title displayed in the terminal window border (if the terminal emulator supports it).
  - Defaults to `"Raxol Application"` (based on `Lifecycle` docstring, though guide previously said `nil`).

- `:quit_keys`

  - **Optional**
  - A list of keys or event patterns that will cause the application to exit gracefully.
  - Events are matched against the `Raxol.Core.Events.Event` struct.
  - Defaults to `[:ctrl_c]` (which likely corresponds to an internal event pattern).
  - You can add more keys like `"q"` or event patterns.

- `:fps`

  - **Optional**
  - Specifies the target frame rate in frames per second for rendering.
  - The runtime's `Rendering.Scheduler` will attempt to trigger renders at this rate.
  - Higher values mean potentially smoother animations but higher CPU usage.
  - Defaults to `60` (frames per second).

- `:debug`

  - **Optional**
  - Default: `false`
  - Enables runtime debugging features (specific features depend on implementation).

- `:width`

  - **Optional**
  - Default: `80`
  - Sets the initial terminal width assumption.

- `:height`
  - **Optional**
  - Default: `24`
  - Sets the initial terminal height assumption.

Other options might be available for specific internal configuration. Refer to the `Raxol.Core.Runtime.Lifecycle` module documentation for the most current details.

# Runtime Options

This guide covers the runtime configuration options available when starting a Raxol application.

## Starting a Raxol Application

There are several ways to start a Raxol application:

```elixir
# Start with default options
Raxol.start_link(MyApp)

# Start with custom options
Raxol.start_link(MyApp, options)

# Start within a supervision tree (recommended for production)
children = [
  {Raxol, application: MyApp, options: [theme: :dark]}
]
Supervisor.start_link(children, strategy: :one_for_one)
```

## Core Runtime Options

| Option                | Type      | Default                            | Description                                                                                               |
| --------------------- | --------- | ---------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `theme`               | `atom`    | `:light`                           | The initial theme to use (`%Raxol.UI.Theming.Theme{}`). Core options: `:light`, `:dark`, `:high_contrast` |
| `render_interval`     | `integer` | `33`                               | The time in milliseconds between render cycles (lower = higher FPS, but more CPU usage)                   |
| `max_fps`             | `integer` | `30`                               | Maximum frames per second to render (alternative to `render_interval`)                                    |
| `plugins`             | `list`    | `[]`                               | List of plugin modules to load at startup                                                                 |
| `persist_preferences` | `boolean` | `true`                             | Whether to persist user preferences between sessions                                                      |
| `preferences_path`    | `string`  | `~/.config/raxol/preferences.json` | Path to store preferences                                                                                 |
| `input_timeout`       | `integer` | `100`                              | Timeout in milliseconds for input processing                                                              |
| `enable_mouse`        | `boolean` | `true`                             | Enable mouse support                                                                                      |
| `accessibility`       | `keyword` | See below                          | Accessibility options                                                                                     |

### Accessibility Options

The `accessibility` option takes a keyword list with the following options:

```elixir
[
  high_contrast: false,      # Enable high contrast mode
  reduced_motion: false,     # Reduce or disable animations
  screen_reader: :auto,      # :auto, :enabled, or :disabled
  key_repeat_delay: 500,     # Delay before key repeat in ms
  key_repeat_rate: 50,       # Key repeat rate in ms
  focus_highlight: true      # Highlight focused element
]
```

## Terminal Options

| Option                 | Type      | Default   | Description                                                              |
| ---------------------- | --------- | --------- | ------------------------------------------------------------------------ |
| `terminal_type`        | `atom`    | `:auto`   | The terminal type (`:ansi`, `:ascii`, `:auto`)                           |
| `enable_colors`        | `boolean` | `true`    | Enable color output                                                      |
| `color_depth`          | `atom`    | `:auto`   | Color depth (`:ansi_8`, `:ansi_16`, `:ansi_256`, `:true_color`, `:auto`) |
| `enable_utf8`          | `boolean` | `true`    | Enable UTF-8 support                                                     |
| `output_mode`          | `atom`    | `:buffer` | Output mode (`:direct`, `:buffer`)                                       |
| `use_alternate_screen` | `boolean` | `true`    | Use alternate screen buffer                                              |
| `respect_term_size`    | `boolean` | `true`    | Respect terminal size constraints                                        |
| `sixel_support`        | `boolean` | `:auto`   | Enable Sixel graphics if supported                                       |

## Debug Options

| Option                | Type      | Default | Description                                      |
| --------------------- | --------- | ------- | ------------------------------------------------ |
| `debug`               | `boolean` | `false` | Enable debug mode                                |
| `log_level`           | `atom`    | `:info` | Log level (`:debug`, `:info`, `:warn`, `:error`) |
| `debug_rendering`     | `boolean` | `false` | Show rendering debug information                 |
| `performance_metrics` | `boolean` | `false` | Collect performance metrics                      |
| `profile`             | `boolean` | `false` | Enable profiling                                 |

## Example Configuration

```elixir
Raxol.start_link(MyApp, [
  theme: :dark,
  render_interval: 16,                      # ~60 FPS
  plugins: [Raxol.Plugins.ClipboardPlugin, MyCustomPlugin],
  accessibility: [
    high_contrast: true,
    reduced_motion: true
  ],
  terminal_type: :ansi,
  color_depth: :ansi_256,
  debug: true,
  log_level: :debug
])
```

## Runtime Customization

You can also change certain options at runtime:

```elixir
# Change theme
Raxol.set_theme(:dark)

# Set accessibility options
Raxol.set_accessibility_option(:reduced_motion, true)

# Change log level
Raxol.set_log_level(:debug)
```

## Environment Variables

Raxol also respects these environment variables:

- `RAXOL_THEME`: Set the default theme
- `RAXOL_NO_COLOR`: Disable colors if set to `1` or `true`
- `RAXOL_DEBUG`: Enable debug mode if set to `1` or `true`
- `RAXOL_LOG_LEVEL`: Set the log level
