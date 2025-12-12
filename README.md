# Raxol

[![CI](https://github.com/Hydepwns/raxol/actions/workflows/ci-unified.yml/badge.svg?branch=master)](https://github.com/Hydepwns/raxol/actions/workflows/ci-unified.yml)
[![Security](https://github.com/Hydepwns/raxol/actions/workflows/security.yml/badge.svg?branch=master)](https://github.com/Hydepwns/raxol/actions/workflows/security.yml)
[![Coverage](https://img.shields.io/badge/coverage-98.7%25-brightgreen.svg)](https://codecov.io/gh/Hydepwns/raxol)
[![Performance](https://img.shields.io/badge/parser-3.3μs%2Fseq-brightgreen.svg)](bench/README.md)
[![Hex.pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/raxol)

## Terminal Application Framework

Terminal framework supporting React, LiveView, HEEx, and Raw UI patterns.

### Features

- Sub-microsecond parser operations
- Multi-framework UI support (React, LiveView, HEEx, Raw)
- Enterprise features: audit logging, encryption, SAML/OIDC
- Graphics: Sixel support, session continuity
- **NEW**: VIM navigation, command parser, fuzzy search, virtual filesystem, cursor effects
- **Cross-platform**: Windows, macOS, Linux support

### Platform Support

Raxol works on all major platforms with automatic backend selection:

- **Unix/macOS**: Native termbox2 NIF for optimal performance (~50μs per frame)
- **Windows 10+**: Pure Elixir driver using OTP 28+ raw mode (~500μs per frame)
- **All platforms**: Consistent API, automatic fallback, full feature parity

Windows support uses VT100 terminal emulation (enabled by default in Windows 10+). No additional setup required.

## Modular Packages (v2.0+)

Raxol is now available as focused, independently releasable packages:

- **[raxol_core](https://hex.pm/packages/raxol_core)** - Lightweight buffer primitives (< 100KB, zero deps)
- **[raxol_liveview](https://hex.pm/packages/raxol_liveview)** - Phoenix LiveView integration
- **[raxol_plugin](https://hex.pm/packages/raxol_plugin)** - Plugin system
- **raxol** - Full framework (includes all packages)

See **[Package Guide](docs/getting-started/PACKAGES.md)** for detailed comparison, migration paths, and installation instructions.

## Quick Start

See [Installation Guide](docs/_includes/installation.md) and [Quickstart Tutorial](docs/getting-started/QUICKSTART.md).

## Choose Your Framework

```elixir
use Raxol.UI, framework: :react      # Familiar React patterns
use Raxol.UI, framework: :liveview   # Phoenix LiveView patterns
use Raxol.UI, framework: :heex       # Phoenix templates
use Raxol.UI, framework: :raw        # Direct terminal control
```

### React-Style Example
```elixir
defmodule MyApp do
  use Raxol.Component

  def render(assigns) do
    ~H"""
    <Box padding={2}>
      <Text color="green" bold>Hello, Raxol!</Text>
      <Button on_click={@on_click}>Click me!</Button>
    </Box>
    """
  end
end
```

### Emulator Usage
```elixir
# Default configuration
emulator = Emulator.new(80, 24)

# With GenServers for concurrent operations
emulator = Emulator.new(80, 24, use_genservers: true)

# Minimal configuration
emulator = Emulator.new(80, 24, enable_history: false, alternate_buffer: false)
```

[View more examples →](examples/README.md)

## Components-Only Mode

When importing Raxol with `runtime: false`, you get access to:

### UI Components
- All framework adapters (React, LiveView, HEEx, Raw)
- Complete component library (Button, Input, Table, Modal, etc.)
- State management and context systems
- Animation and transition engines
- Theme system and styling utilities

### Not Included in Components-Only
- Terminal emulator runtime
- ANSI/VT100 sequence processing
- PTY/TTY management
- SSH session handling
- Sixel graphics rendering

This makes Raxol perfect as a lightweight UI component library for web applications or other non-terminal use cases.

## Architecture

### Terminal Framework
- VT100/ANSI compliance with modern extensions
- Sixel graphics, GPU acceleration
- Mouse support, event handling
- Tab completion, command history

### UI System
- Universal features: actions, transitions, context, slots
- 60 FPS animation engine
- Component composition, theming

### Enterprise Features
- Session continuity
- Real-time collaboration with CRDT sync
- SOC2/HIPAA/GDPR audit logging
- AES-256-GCM encryption with key rotation

## Performance

See [Performance Metrics](docs/_includes/performance-metrics.md) and [Benchmark Docs](docs/bench/).

## Documentation

### Getting Started

- **[Quickstart](https://github.com/Hydepwns/raxol/blob/master/docs/getting-started/QUICKSTART.md)** - 5/10/15 minute tutorials
- **[Core Concepts](https://github.com/Hydepwns/raxol/blob/master/docs/getting-started/CORE_CONCEPTS.md)** - Understand buffers and rendering
- **[Migration Guide](https://github.com/Hydepwns/raxol/blob/master/docs/getting-started/MIGRATION_FROM_DIY.md)** - For teams with existing terminal code

### Cookbooks

- **[LiveView Integration](https://github.com/Hydepwns/raxol/blob/master/docs/cookbook/LIVEVIEW_INTEGRATION.md)** - Render terminals in Phoenix
- **[Performance Optimization](https://github.com/Hydepwns/raxol/blob/master/docs/cookbook/PERFORMANCE_OPTIMIZATION.md)** - 60fps techniques
- **[Theming](https://github.com/Hydepwns/raxol/blob/master/docs/cookbook/THEMING.md)** - Custom color schemes

### Features

- **[VIM Navigation](https://github.com/Hydepwns/raxol/blob/master/docs/features/VIM_NAVIGATION.md)** - VIM-style keybindings and movement
- **[Command Parser](https://github.com/Hydepwns/raxol/blob/master/docs/features/COMMAND_PARSER.md)** - Tab completion, history, argument parsing
- **[Fuzzy Search](https://github.com/Hydepwns/raxol/blob/master/docs/features/FUZZY_SEARCH.md)** - Multi-mode search with highlighting
- **[File System](https://github.com/Hydepwns/raxol/blob/master/docs/features/FILESYSTEM.md)** - Virtual filesystem with Unix commands
- **[Cursor Effects](https://github.com/Hydepwns/raxol/blob/master/docs/features/CURSOR_EFFECTS.md)** - Visual trails and glow effects
- **[Features Overview](https://github.com/Hydepwns/raxol/blob/master/docs/features/README.md)** - Complete guide to all features

### API Reference

- **[Buffer API](https://github.com/Hydepwns/raxol/blob/master/docs/core/BUFFER_API.md)** - Complete buffer operations reference
- **[Architecture](https://github.com/Hydepwns/raxol/blob/master/docs/core/ARCHITECTURE.md)** - Design decisions and internals
- **[Full Documentation](https://hexdocs.pm/raxol)** - Complete API reference

### Recent Features
- **Feature Additions** (v2.0.0 Phase 6) - VIM navigation, command parser, fuzzy search, filesystem, cursor effects
- **Documentation Overhaul** (v2.0.0 Phase 4) - Beginner-friendly guides and practical cookbooks
- **Plugin System** (v2.0.0 Phase 3) - Spotify plugin showcase
- **LiveView Integration** (v2.0.0 Phase 2) - Terminal rendering in Phoenix
- **Raxol.Core** (v2.0.0 Phase 1) - Lightweight buffer primitives (< 100KB, zero deps)
- **Code Consolidation** (v1.5.4) - BaseManager pattern, TimerManager integration, 99.8% test coverage
- **Type Spec Generator** (v1.4.1) - Automated type specification generation
- **Unified Configuration** (v1.4.1) - TOML-based configuration system

## VS Code Extension

Development version available in `editors/vscode/`. To install:

```bash
cd editors/vscode
npm install
npm run compile
code --install-extension .
```

Features: syntax highlighting, IntelliSense, component snippets, live preview

## Use Cases

Use cases: terminal IDEs, DevOps tools, system monitoring, database clients, chat applications, games.

## Roadmap

### Planned Features

- **Svelte Framework Support** - Reactive component patterns with compile-time optimization
- **Enhanced Graphics** - WebGL-style rendering in terminal
- **Multi-session Collaboration** - Real-time shared terminal sessions
- **Plugin Marketplace** - Community plugins and themes
- **Mobile Terminal** - iOS/Android terminal clients

See [ROADMAP.md](ROADMAP.md) for detailed timeline and feature specifications.

## License

MIT License - see [LICENSE.md](LICENSE.md)
