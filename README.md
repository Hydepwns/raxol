# Raxol

[![Hex.pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![Codecov](https://codecov.io/gh/Hydepwns/raxol/branch/master/graph/badge.svg)](https://codecov.io/gh/Hydepwns/raxol)

A modern toolkit for building terminal user interfaces (TUIs) in Elixir with components, styling, and event handling.

## Features

- **Terminal Emulator**: ANSI support, buffer management, cursor handling, improved reliability
- **Component Architecture**: Reusable UI components with state management
- **Plugin System**: Extensible plugin architecture for custom features and integrations
- **Event System**: Keyboard, mouse, window resize, and custom events
- **Buffer Management**: Scrollback, selection, and history support
- **Theme Support**: Customizable styling with color system integration
- **Accessibility**: Screen reader support, keyboard navigation, focus management
- **Animation**: Smooth transitions and dynamic UI updates
- **Performance**: Advanced caching, metrics, and rendering optimizations
- **Documentation System**: Markdown rendering, search indexing, and TOC generation
- **Code Quality**: Zero duplicate code, comprehensive test coverage, modular design
- **Release Process**: Streamlined cross-platform builds with standardized workflow

## Installation

See [Installation Guide](docs/DEVELOPMENT.md#installation) for detailed setup instructions including:
- Nix development environment (recommended)
- Manual installation steps
- Dependency requirements

## Quick Start

### Release Commands

Raxol includes streamlined release commands for cross-platform builds:

```bash
# Development builds (fast, unoptimized)
mix release.dev

# Production builds (optimized, signed)
mix release.prod

# Build for all platforms (macOS, Linux, Windows)
mix release.all

# Clean previous builds
mix release.clean

# Create and push version tag
mix release.tag
```

Build artifacts are available in `burrito_out/` with detailed manifests.

### Interactive Demo Runner

The easiest way to explore Raxol is through our interactive demo runner:

```bash
# Show interactive menu to select from available demos
mix run bin/demo.exs

# Run a specific demo directly
mix run bin/demo.exs form
mix run bin/demo.exs accessibility
mix run bin/demo.exs component_showcase

# List all available demos
mix run bin/demo.exs --list

# Search for demos
mix run bin/demo.exs --search "table"

# Get help
mix run bin/demo.exs --help
```

### Create Your First App

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

## Plugin System

Raxol supports a powerful plugin system for extending terminal and UI functionality. Plugins can be registered and managed at runtime, and can handle input, output, events, and more.

**Example:**

```elixir
# Register a plugin
Raxol.Core.Runtime.Plugins.register(MyPlugin)

# Start a plugin
Raxol.Core.Runtime.Plugins.start(MyPlugin)

# List enabled plugins
Raxol.Core.Runtime.Plugins.list()
```

See [Plugin Development Guide](examples/guides/04_extending_raxol/plugin_development.md) for details.

## Available Demos

Raxol comes with a comprehensive set of examples demonstrating various features:

### Basic Examples

- **Form**: Simple form with validation and focus management
- **Table**: Advanced table component with sorting and filtering
- **Component Showcase**: Complete component library demonstration

### Advanced Features

- **Accessibility**: Screen reader support and keyboard navigation
- **Keyboard Shortcuts**: Custom shortcut handling and configuration
- **UX Refinement**: Focus management and user experience improvements

### Showcases

- **Color System**: Comprehensive color system and theming
- **Focus Ring**: Focus indication with various animation types
- **Select List**: Enhanced selection with search and pagination

### Work in Progress

- **Integrated Accessibility**: Advanced accessibility features

## Documentation

Complete documentation is available in the [Documentation Hub](docs/CONSOLIDATED_README.md):

- [Getting Started Guide](examples/guides/01_getting_started/quick_start.md)
- [Component System](docs/components/README.md)
- [Examples & Snippets](examples/snippets/README.md)
- [API Reference](https://hexdocs.pm/raxol/0.6.0)

## Performance

- Event processing: < 1ms average
- Screen updates: < 2ms average
- Concurrent operations: < 5ms average
- Code quality: 0 duplicate code issues, 100% modular design

## License

MIT License - see [LICENSE.md](LICENSE.md)

## Support

- [Documentation Hub](docs/CONSOLIDATED_README.md)
- [Issues](https://github.com/Hydepwns/raxol/issues)
