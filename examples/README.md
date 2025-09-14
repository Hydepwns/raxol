# Raxol Examples

Comprehensive collection of examples demonstrating Raxol's features and capabilities, organized by complexity and purpose.

## Quick Start

```bash
# Start with basics
elixir examples/getting_started/hello_world.exs

# Try a simple app
mix run examples/apps/todo_app.ex

# Explore components
mix run examples/components/component_showcase.ex

# Run framework examples  
mix run examples/frameworks/svelte/svelte_counter.ex
```

## Directory Structure

The examples are organized by learning progression and purpose:

```
examples/
├── README.md              # This guide
├── getting_started/       # Beginner-friendly examples  
├── scripts/              # Quick script examples (.exs files)
├── components/           # Component showcases and demos
├── apps/                 # Complete application examples
├── frameworks/           # Framework integration examples  
└── advanced/             # Complex patterns and optimizations
```

## Learning Path

### 🚀 Getting Started (`getting_started/`)
Perfect for beginners - start here to learn Raxol basics.
- `hello_world.exs` - Your first Raxol application
- `counter.exs` - Basic state management and events  
- `form.ex` - Simple input handling

[→ Getting Started Guide](getting_started/README.md)

### ⚡ Scripts (`scripts/`)
Quick script examples for specific features (run with `elixir`).
- `rendering.exs` - Basic rendering patterns
- `event_handling.exs` - Interactive event examples
- `clock.exs` - Live updates with subscriptions

[→ Script Examples](scripts/README.md)

### 🧩 Components (`components/`)
Learn Raxol's component system with focused examples.
- **Forms:** Input handling, validation, data binding
- **Displays:** Progress bars, tables, data visualization  
- **Navigation:** Menus, lists, selection components
- **Accessibility:** Focus management, screen readers

[→ Component Guide](components/README.md)

### 🏗️ Complete Apps (`apps/`)
Real-world applications showing architectural patterns.
- `file_browser/` - Multi-module file manager with preview
- `terminal_editor/` - Full-featured text editor
- `system_monitor.ex` - Live system monitoring dashboard
- `todo_app.ex` - Feature-rich task management

[→ Application Examples](apps/README.md)

### 🔧 Frameworks (`frameworks/`)
Integration examples for different UI frameworks.
- **Svelte:** Reactive components and state management
- **TypeScript:** Type-safe Raxol development

[→ Framework Integration](frameworks/README.md)

### ⚡ Advanced (`advanced/`)
Complex patterns for experienced developers.
- **Performance:** Optimization techniques and monitoring
- **Architecture:** Large-scale application design patterns
- **Integrations:** Cloud services, external APIs

[→ Advanced Patterns](advanced/README.md)

## Creating Your Own Example

```elixir
defmodule MyExample do
  use Raxol.Component
  alias Raxol.View.Elements

  @impl Raxol.Component
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :message, "Hello from Raxol!")}
  end

  @impl Raxol.Component
  def handle_event("update", _payload, socket) do
    {:noreply, assign(socket, :message, "Updated!")}
  end

  @impl Raxol.Component
  def render(assigns) do
    ~V"""
    <.panel title="My Example">
      <.text>{assigns.message}</.text>
      <.button rax-click="update">Update</.button>
    </.panel>
    """
  end
end
```

## Best Practices

1. **Organization**: Place examples in appropriate subdirectories
2. **Documentation**: Include clear comments and purpose
3. **Dependencies**: Document any special requirements
4. **Naming**: Use descriptive filenames with `.ex` extension

## Running Examples

Most examples can be run directly with Mix:

```bash
# Run any example file
mix run examples/path/to/example.ex

# Pipe output to see terminal formatting
mix run examples/path/to/example.ex | cat
```

## Related Documentation

- [Component Documentation](../docs/guides/components.md)
- [Framework Guide](../docs/guides/multi-framework.md)
- [API Reference](https://hexdocs.pm/raxol)
- [Getting Started](../README.md#quick-start)