# Raxol

[![Hex.pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/raxol)

Complete terminal application framework for Elixir. Meta-package that includes all Raxol packages.

## Installation

```elixir
def deps do
  [
    {:raxol, "~> 2.0"}
  ]
end
```

This installs:
- `raxol_core` - Buffer primitives
- `raxol_liveview` - Phoenix LiveView integration
- `raxol_plugin` - Plugin framework

## Modular Adoption

Choose packages based on needs:

**Minimal (just buffers):**
```elixir
{:raxol_core, "~> 2.0"}
```

**Web (LiveView terminals):**
```elixir
{:raxol_core, "~> 2.0"},
{:raxol_liveview, "~> 2.0"}
```

**Full framework:**
```elixir
{:raxol, "~> 2.0"}
```

## Features

- Pure functional buffer operations
- Phoenix LiveView integration
- Plugin system with behavior API
- VIM-style navigation
- Command parser with tab completion
- Fuzzy search
- Virtual filesystem
- Cursor effects
- Five built-in themes
- Zero-dependency core

## Quick Start

See individual package documentation:
- [raxol_core](https://hexdocs.pm/raxol_core) - Buffer operations
- [raxol_liveview](https://hexdocs.pm/raxol_liveview) - LiveView integration
- [raxol_plugin](https://hexdocs.pm/raxol_plugin) - Plugin development

## Documentation

Full documentation in [GitHub repository](https://github.com/Hydepwns/raxol):
- [Getting Started](https://github.com/Hydepwns/raxol/blob/master/docs/getting-started/QUICKSTART.md)
- [Core Concepts](https://github.com/Hydepwns/raxol/blob/master/docs/getting-started/CORE_CONCEPTS.md)
- [Cookbook Guides](https://github.com/Hydepwns/raxol/tree/master/docs/cookbook)
- [Examples](https://github.com/Hydepwns/raxol/tree/master/examples)

## License

MIT License - See LICENSE file

## Contributing

Visit [GitHub repository](https://github.com/Hydepwns/raxol)

## Credits

Built by [axol.io](https://axol.io) for [raxol.io](https://raxol.io)
