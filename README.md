# Raxol

A modern, feature-rich toolkit for building sophisticated terminal user interfaces (TUIs) in Elixir. Raxol provides a comprehensive set of components, styling options, and event handling capabilities to create interactive terminal applications with rich text formatting and dynamic UI updates.

## Features

### Core Features

- **Component-Based Architecture**: Build UIs using reusable components with their own state management
- **Flexible View Definition**: Choose between HEEx-like syntax or programmatic component functions
- **Rich Text Formatting**: Support for colors, styles, and dynamic content updates
- **Layout System**: Flexbox-inspired layout engine for responsive terminal UIs
- **Event Handling**: Comprehensive event system for keyboard and mouse interactions
- **Theme Support**: Customizable styling and theming capabilities
- **Accessibility**: Built-in support for screen readers and keyboard navigation

### Advanced Features

- **Data Visualization**: Charts, graphs, and TreeMaps for data representation
- **Animation System**: Smooth transitions and dynamic UI updates
- **Plugin System**: Extensible architecture for custom functionality
- **Cloud Integration**: Monitoring, configuration, and service discovery
- **Performance Optimization**: Advanced caching and rendering optimizations
- **Metrics System**: Comprehensive performance monitoring and visualization
- **Progress Indicators**: Multiple progress visualization options including bars, spinners, and circular indicators

## Installation

Add Raxol to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:raxol, "~> 0.5.0"}
  ]
end
```

Then fetch the dependencies:

```bash
mix deps.get
git submodule update --init --recursive  # Required for termbox2 dependency
```

## Quick Start

Create a new application module:

```elixir
defmodule MyApp.Application do
  use Raxol.Core.Runtime.Application

  @impl true
  def render(assigns) do
    ~H"""
    <box border="single" padding="1">
      <text color="cyan" bold="true">Hello from Raxol!</text>
      <progress type="bar" value="0.75" width="20" />
    </box>
    """
  end
end
```

Or using the programmatic approach:

```elixir
defmodule MyApp.Application do
  use Raxol.Core.Runtime.Application
  use Raxol.View
  import Raxol.View.Elements

  @impl true
  def render(assigns) do
    view do
      box border: :single, padding: 1 do
        text content: "Hello from Raxol!", color: :cyan, attributes: [:bold]
        Progress.bar(0.75, width: 20)
      end
    end
  end
end
```

## Documentation

### Core Concepts

- [Quick Start Guide](examples/guides/01_getting_started/quick_start.md)
- [Terminal Emulator](examples/guides/02_core_concepts/terminal_emulator.md)
- [API Reference](examples/guides/02_core_concepts/api/README.md)

### Components & Layout

- [Components Overview](examples/guides/03_components_and_layout/components/README.md)
- [Visualization Components](examples/guides/03_components_and_layout/components/visualization/README.md)
- [Database Components](examples/guides/03_components_and_layout/components/database/README.md)
- [Progress Components](examples/guides/03_components_and_layout/components/README.md)

## Performance

Raxol is built for speed and reliability. Automated tests enforce strict performance standards:

- **Event processing**: < 1ms average, < 2ms (95th percentile)
- **Screen updates**: < 2ms average, < 5ms (95th percentile)
- **Concurrent operations**: < 5ms average, < 10ms (95th percentile)

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## Support

- [Documentation](docs/README.md)
- [Issue Tracker](https://github.com/Hydepwns/raxol/issues)
- [Discussions](https://github.com/Hydepwns/raxol/discussions)

---
