# Raxol Examples

This directory contains examples to help you learn and explore Raxol's capabilities. The examples are organized into categories based on complexity and purpose.

## Directory Structure

- **[basic](./basic/)** - Simple examples demonstrating core concepts like `Hello, World!` and basic components.
- **[advanced](./advanced/)** - More complex examples showing advanced features like async operations or custom components.
- **[interactive](./interactive/)** - Examples focusing on user interaction and events.
- **[layout](./layout/)** - Examples demonstrating different layout strategies and containers.
- **[showcase](./showcase/)** - Complete applications highlighting real-world use cases.
- **[without-runtime](./without-runtime/)** - Examples showing how to use Raxol's lower-level APIs directly.
- **[typescript](./typescript/)** - Examples related to the TypeScript integration (if applicable).
- **[plugin_demo.exs](./plugin_demo.exs)** - A standalone example demonstrating plugin usage.

## Getting Started

If you're new to Raxol, start with the basic examples:

```bash
mix run examples/basic/counter.exs
```

## Running Examples

All examples can be run using Mix:

```bash
mix run examples/path/to/example.exs
```

## Creating Your Own

Use these examples as a starting point for your own applications. A simple structure for a Raxol application is:

```elixir
defmodule MyApp do
  use Raxol.App

  @impl true
  def render(assigns) do
    # Render the UI based on assigns
    ~H"""
    <box border="single">
      <text>My Raxol App</text>
    </box>
    """
  end
end

# Start the application using the Lifecycle module
Raxol.Core.Runtime.Lifecycle.start_application(MyApp)

For stateful applications or components, you'll typically use `Raxol.View` and implement `init/1`, `handle_event/3`, and `update/2` callbacks as needed.
```
