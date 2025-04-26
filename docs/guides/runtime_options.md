# Raxol Runtime Options

When starting your Raxol application using the `Raxol.Core.Runtime.Lifecycle.start_application/2` function, or by adding `Raxol.Core.Runtime.Application` to your supervision tree, you can pass various options to configure the runtime behavior and initial setup.

These options are typically provided as a keyword list.

## Starting Raxol

When starting your Raxol application using the `Raxol.Core.Runtime.Lifecycle.start_application/2` function, or by adding `Raxol.Core.Runtime.Application` to your supervision tree, you can pass various options to configure the runtime behavior and initial setup.

### Using `start_application/2`

This is common for starting directly from `iex` or scripts.

```elixir
defmodule MyApp do
  use Raxol.App
  # ... implement callbacks ...
end

# Example using Raxol.run/2
Raxol.run(MyApp, title: "My Awesome App", quit_keys: ["q", :ctrl_c])

# Example using Raxol.Core.Runtime.Lifecycle.start_application/2
opts = [
  app: MyApp,
  title: "My Custom App",
  fps: 30,
  quit_keys: [{:ctrl, ?q}],
  debug: true
]
{:ok, pid} = Raxol.Core.Runtime.Lifecycle.start_application(MyApp, opts)
```

### Using a Supervisor

This is the standard approach for long-running applications.

```elixir
# In your Application module's start/2
children = [
  {Raxol.Core.Runtime.Application, [app: MyApp, title: "Supervised App"]}
]
Supervisor.start_link(children, strategy: :one_for_one)
```

## Available Options

- `:app`
  - **Required** (when using `Raxol.Core.Runtime.Application` in a supervisor)
  - The module implementing the `Raxol.App` behaviour.

## `title:`

- **Optional**
- Sets the title displayed in the terminal window border (if the terminal emulator supports it).
- Defaults to `nil` (no title).

## `quit_keys:`

- **Optional**
- A list of keys that will cause the application to exit gracefully.
- Keys can be strings (e.g., `"q"`) or atoms representing special keys (e.g., `:ctrl_c`).
- Defaults to `[:ctrl_c]`. You can add more keys like `"q"` or `"esc"`.

## `interval:`

- **Optional**
- Specifies the target frame rate or render interval in milliseconds.
- The runtime will attempt to call your `render/1` function approximately this often.
- Lower values mean potentially smoother animations but higher CPU usage.
- Defaults to `100` (milliseconds), aiming for roughly 10 frames per second.

* `:fps`

  - **Optional**
  - Specifies the target frame rate in frames per second.
  - Default: `30`

* `:debug`
  - Default: `false`
  - Enables runtime debugging features.

There might be other options available. Refer to the `Raxol.Core.Runtime.Lifecycle` and `Raxol.Core.Runtime.Application` module documentation for a complete list.
