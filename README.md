# Raxol

A modern, feature-rich toolkit for building sophisticated terminal user interfaces (TUIs) in Elixir. Raxol provides a comprehensive set of components, styling options, and event handling capabilities to create interactive terminal applications with rich text formatting and dynamic UI updates.

## Features

### Core Features

- **Terminal Emulator**: Full-featured terminal emulator with ANSI escape sequence support, buffer management, and cursor handling
- **Component-Based Architecture**: Build UIs using reusable components with their own state management and lifecycle
- **Event System**: Comprehensive event handling for keyboard, mouse, window resize, and custom events
- **Buffer Management**: Advanced terminal buffer system with scrollback, selection, and history support
- **Input Processing**: Robust input handling with buffer management and event routing
- **Theme Support**: Customizable styling and theming capabilities with color system integration
- **Accessibility**: Built-in support for screen readers, keyboard navigation, and focus management

### Terminal Features

- **ANSI Support**: Complete ANSI escape sequence parsing and rendering (colors, styles, cursor movement)
- **Mouse Tracking**: Full mouse event support with click, drag, and scroll detection
- **Window Management**: Dynamic window resizing, focus handling, and tab support
- **Command Processing**: Terminal command execution with CSI, DCS, and escape sequence handling
- **Buffer Operations**: Text insertion, deletion, scrolling, and selection operations
- **History Management**: Command history with search and navigation capabilities
- **Plugin System**: Extensible architecture for custom terminal functionality

### UI Components

- **Basic Components**: Button, text input, table, modal, and tab bar components
- **Progress Indicators**: Multiple progress visualization options (bars, spinners, circular)
- **Layout System**: Flexbox-inspired layout engine for responsive terminal UIs
- **Rendering Engine**: High-performance rendering with tree diffing and optimization
- **Focus Management**: Comprehensive focus handling with keyboard navigation
- **Text Formatting**: Rich text support with colors, styles, and markdown rendering

### Advanced Features

- **Animation System**: Smooth transitions and dynamic UI updates with caching support
- **Performance Optimization**: Advanced caching, metrics collection, and rendering optimizations
- **Internationalization**: Multi-language support with i18n integration
- **Cloud Integration**: Monitoring, configuration, and service discovery capabilities
- **Metrics System**: Comprehensive performance monitoring and visualization
- **Configuration Management**: Flexible configuration system with runtime updates

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
- [Snippets](examples/snippets/README.md)

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

---
