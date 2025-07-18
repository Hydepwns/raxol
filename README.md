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

## Installation

### Using Nix (Recommended)

For the best development experience, we recommend using Nix:

```bash
# Enter the development environment
nix-shell

# Or if you have direnv installed, just cd into the project
cd raxol
# direnv will automatically load the environment

# Install dependencies and setup
mix deps.get
git submodule update --init --recursive
mix setup
```

### Manual Installation

```elixir
# mix.exs
def deps do
  [
    {:raxol, "~> 0.6.0"}
  ]
end
```

```bash
# Enter the development environment, initialize the submodule for termbox2
mix deps.get
git submodule update --init --recursive
```

**Note**: You'll need to install Erlang 25.3.2.7, Elixir 1.17.1, PostgreSQL, and other dependencies manually.

## Quick Start

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

- [Quick Start](examples/guides/01_getting_started/quick_start.md)
- [Terminal Emulator](examples/guides/02_core_concepts/terminal_emulator.md)
- [API Reference](examples/guides/02_core_concepts/api/README.md)
- [Components](examples/guides/03_components_and_layout/components/README.md)
- [Snippets](examples/snippets/README.md)
- [HexDocs for 0.6.0](https://hexdocs.pm/raxol/0.6.0)

## Performance

- Event processing: < 1ms average
- Screen updates: < 2ms average
- Concurrent operations: < 5ms average
- Code quality: 0 duplicate code issues, 100% modular design

## License

MIT License - see [LICENSE.md](LICENSE.md)

## Support

- [Documentation](docs/README.md)
- [Issues](https://github.com/Hydepwns/raxol/issues)
