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

### Core Options

- `:title`

  - **Optional**
  - Sets the title displayed in the terminal window border (if the terminal emulator supports it).
  - Defaults to `"Raxol Application"`.

- `:quit_keys`

  - **Optional**
  - A list of keys or event patterns that will cause the application to exit gracefully.
  - Events are matched against the `Raxol.Core.Events.Event` struct.
  - Defaults to `[{:ctrl, ?c}]`.
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

### Accessibility Options

The `:accessibility` option takes a keyword list with the following options:

```elixir
[
  screen_reader: true,      # Enable screen reader support
  high_contrast: false,     # Enable high contrast mode
  large_text: false,        # Enable large text mode
  reduced_motion: false,    # Reduce or disable animations
  key_repeat_delay: 500,    # Delay before key repeat in ms
  key_repeat_rate: 50,      # Key repeat rate in ms
  focus_highlight: true     # Highlight focused element
]
```

### Terminal Options

- `:terminal_type`

  - **Optional**
  - Default: `:auto`
  - The terminal type (`:ansi`, `:ascii`, `:auto`).

- `:enable_colors`

  - **Optional**
  - Default: `true`
  - Enable color output.

- `:color_depth`

  - **Optional**
  - Default: `:auto`
  - Color depth (`:ansi_8`, `:ansi_16`, `:ansi_256`, `:true_color`, `:auto`).

- `:enable_utf8`

  - **Optional**
  - Default: `true`
  - Enable UTF-8 support.

- `:output_mode`

  - **Optional**
  - Default: `:buffer`
  - Output mode (`:direct`, `:buffer`).

- `:use_alternate_screen`

  - **Optional**
  - Default: `true`
  - Use alternate screen buffer.

- `:respect_term_size`

  - **Optional**
  - Default: `true`
  - Respect terminal size constraints.

- `:sixel_support`
  - **Optional**
  - Default: `:auto`
  - Enable Sixel graphics if supported.

### Plugin Options

- `:plugins`

  - **Optional**
  - Default: `[]`
  - List of plugin modules to load at startup.

- `:plugin_manager_opts`
  - **Optional**
  - Default: `[]`
  - Options to pass to the PluginManager's start_link function.

### Debug Options

- `:log_level`

  - **Optional**
  - Default: `:info`
  - Log level (`:debug`, `:info`, `:warn`, `:error`).

- `:debug_rendering`

  - **Optional**
  - Default: `false`
  - Show rendering debug information.

- `:performance_metrics`

  - **Optional**
  - Default: `false`
  - Collect performance metrics.

- `:profile`
  - **Optional**
  - Default: `false`
  - Enable profiling.

## Environment Variables

Raxol also respects these environment variables:

- `RAXOL_THEME`: Set the default theme
- `RAXOL_NO_COLOR`: Disable colors if set to `1` or `true`
- `RAXOL_DEBUG`: Enable debug mode if set to `1` or `true`
- `RAXOL_LOG_LEVEL`: Set the log level

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
