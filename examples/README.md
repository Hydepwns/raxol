# Raxol Examples

Comprehensive collection of examples demonstrating Raxol's features and capabilities.

## Quick Start

```bash
# Run basic examples
mix run examples/snippets/basic/counter.exs

# Run Svelte examples
mix run examples/svelte/svelte_counter.ex

# Run component showcases
mix run examples/components/component_showcase.ex
```

## Directory Structure

```
examples/
├── README.md           # This file
├── snippets/           # Small, focused examples organized by category
├── basic/              # Simple examples for getting started
├── advanced/           # Complex examples with multiple features
├── components/         # Component library showcases
├── svelte/             # Svelte-style reactive examples
├── showcases/          # Full-featured demonstration apps
└── demos/              # Interactive demonstration scripts
```

## Categories

### Snippets (`snippets/`)
Small, focused code examples organized by category. These are perfect for learning specific concepts.

**Available categories:**
- Basic patterns and state management
- Advanced integrations and complex features
- Interactive showcases and demonstrations
- Without-runtime examples for low-level usage

[→ Browse all snippets](snippets/README.md)

### Svelte Examples (`svelte/`)
Reactive programming examples using Raxol's Svelte-style component system.

**Examples:**
- `svelte_counter.ex` - Simple reactive counter
- `svelte_demo.ex` - Basic Svelte patterns
- `svelte_advanced_demo.ex` - Advanced reactive features
- `svelte_todo_app.ex` - Complete todo application
- `run_svelte_demos.ex` - Demo runner script

**Run:**
```bash
mix run examples/svelte/svelte_counter.ex
```

### Component Showcases (`components/`)
Demonstrations of Raxol's built-in component library and patterns.

**Examples:**
- `component_showcase.ex` - Overview of all available components
- `focus_ring_showcase.ex` - Focus management and accessibility
- `select_list_showcase.ex` - Selection and list components
- `form.ex` - Form handling patterns

**Run:**
```bash
mix run examples/components/component_showcase.ex
```

### Advanced Examples (`advanced/`)
Complex examples showing integration patterns and advanced features.

**Examples:**
- `multi_framework_demo.ex` - Using multiple UI frameworks together
- `todo_app.ex` - Full-featured todo application

**Run:**
```bash
mix run examples/advanced/multi_framework_demo.ex
```

### Interactive Demos (`demos/`)
Live demonstrations of specific Raxol features and systems.

**Examples:**
- `accessibility_demo.ex` - Accessibility features demonstration
- `color_system_demo.ex` - Color and theming system
- `ux_refinement_demo.ex` - UX enhancement features
- `integrated_accessibility_demo.ex` - Complete accessibility showcase
- `form.ex` - Interactive form handling

**Run:**
```bash
mix run examples/demos/accessibility_demo.ex
```

### Showcases (`showcases/`)
Complete applications demonstrating real-world usage patterns.

**Examples:**
- `showcase.ex` - Comprehensive feature showcase
- `showcase_app.ex` - Application-style demonstration

**Run:**
```bash
mix run examples/showcases/showcase.ex
```

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