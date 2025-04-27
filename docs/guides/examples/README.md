# Raxol Examples

This directory contains examples showcasing Raxol's features.

## Directory Structure

- **`/examples/basic/`** - Core concepts (`Counter`, `HelloWorld`).
- **`/examples/advanced/`** - Async operations, custom components.
- **`/examples/interactive/`** - User interaction, events.
- **`/examples/layout/`** - Layout strategies (`panel`, `row`, `column`).
- **`/examples/showcase/`** - More complete applications (`component_showcase.exs`).
- **`/examples/plugin_demo.exs`** - Standalone plugin usage example.

_(Note: Some directories might exist from previous structures but check the list above for current relevant examples)_

## Getting Started

If you're new to Raxol, start with the basic examples:

```bash
mix run examples/basic/counter.exs
```

## Running Examples

Run any example using `mix run`:

```bash
mix run examples/showcase/component_showcase.exs | cat
# Add " | cat " to prevent interference with your current terminal
```

## Creating Your Own

Use these examples as a starting point. A simple application using the `Raxol.Core.Runtime.Application` behaviour looks like this:

```elixir
defmodule MyApp do
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  @impl true
  def init(_context), do: {:ok, %{}} # Initial state

  @impl true
  def update(_message, state), do: {:ok, state, []} # Event handling

  @impl true
  def view(_state) do
    # Render UI using View.Elements macros
    view do
      panel title: "My App" do
        text(content: "Hello from Raxol!")
      end
    end
  end
end

# Start the application
Raxol.Core.Runtime.Lifecycle.start_application(MyApp)
```

Refer to the [Getting Started Tutorial](../quick_start.md) and the [Components Guide](../components.md) for more details.
