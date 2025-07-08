# Raxol

A modern toolkit for building terminal user interfaces (TUIs) in Elixir with components, styling, and event handling.

## Features

- **Terminal Emulator**: ANSI support, buffer management, cursor handling
- **Component Architecture**: Reusable UI components with state management
- **Event System**: Keyboard, mouse, window resize, and custom events
- **Buffer Management**: Scrollback, selection, and history support
- **Theme Support**: Customizable styling with color system integration
- **Accessibility**: Screen reader support, keyboard navigation, focus management
- **Animation**: Smooth transitions and dynamic UI updates
- **Performance**: Advanced caching, metrics, and rendering optimizations

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
    {:raxol, "~> 0.5.0"}
  ]
end
```

```bash
mix deps.get
git submodule update --init --recursive
```

**Note**: You'll need to install Erlang 25.3.2.7, Elixir 1.17.1, PostgreSQL, and other dependencies manually.

## Quick Start

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

## Documentation

- [Quick Start](examples/guides/01_getting_started/quick_start.md)
- [Terminal Emulator](examples/guides/02_core_concepts/terminal_emulator.md)
- [API Reference](examples/guides/02_core_concepts/api/README.md)
- [Components](examples/guides/03_components_and_layout/components/README.md)
- [Snippets](examples/snippets/README.md)

## Performance

- Event processing: < 1ms average
- Screen updates: < 2ms average
- Concurrent operations: < 5ms average

## License

MIT License - see [LICENSE.md](LICENSE.md)

## Support

- [Documentation](docs/README.md)
- [Issues](https://github.com/Hydepwns/raxol/issues)
