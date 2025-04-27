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
