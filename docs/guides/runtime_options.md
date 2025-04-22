# Raxol Runtime Options

When starting your Raxol application using `Raxol.Runtime.start_link/1` or the simpler `Raxol.run/2` function, you can pass various options to configure the runtime behavior and initial setup.

These options are typically provided as a keyword list.

```elixir
defmodule MyApp do
  use Raxol.App
  # ... implement callbacks ...
end

# Example using Raxol.run/2
Raxol.run(MyApp, title: "My Awesome App", quit_keys: ["q", :ctrl_c])

# Example using Raxol.Runtime.start_link/1 (more common in supervision trees)
opts = [
  app: MyApp,
  title: "My Supervised App",
  quit_keys: [:ctrl_c],
  interval: 50 # Set render interval to 50ms
]
{:ok, pid} = Raxol.Runtime.start_link(opts)
```

Here are some of the commonly used options:

## `app:`

- **Required** (when using `Raxol.Runtime.start_link/1`)
- Specifies the `Raxol.App` module that defines your application's logic (`init/1`, `update/2`, `render/1`, etc.).
- When using `Raxol.run/2`, the app module is the first argument, so this option is not needed.

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

There might be other options available. Refer to the `Raxol.Runtime` module documentation or source code for a complete list.
