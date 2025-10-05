# Raxol

[![CI](https://github.com/Hydepwns/raxol/workflows/CI/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml)
[![Tests](https://img.shields.io/badge/tests-793%20(100%25%20pass)-brightgreen.svg)](https://github.com/Hydepwns/raxol/actions)
[![Coverage](https://img.shields.io/badge/coverage-98.7%25-brightgreen.svg)](https://codecov.io/gh/Hydepwns/raxol)
[![Performance](https://img.shields.io/badge/parser-3.2μs%2Fseq-brightgreen.svg)](bench/README.md)
[![Hex.pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/raxol)

## Terminal Application Framework

Terminal framework supporting React, Svelte, LiveView, and HEEx UI patterns.

### Features

- Sub-microsecond parser operations
- Multi-framework UI support (React, Svelte, LiveView, HEEx)
- Enterprise features: audit logging, encryption, SAML/OIDC
- Graphics: Sixel support, session continuity
- **NEW**: VIM navigation, command parser, fuzzy search, virtual filesystem, cursor effects

## Modular Packages (v2.0+)

Raxol is now available as focused, independently releasable packages:

- **[raxol_core](packages/raxol_core/)** - Lightweight buffer primitives (< 100KB, zero deps)
- **[raxol_liveview](packages/raxol_liveview/)** - Phoenix LiveView integration
- **[raxol_plugin](packages/raxol_plugin/)** - Plugin system
- **raxol** (coming soon) - Full framework (includes all packages)

**[View Package Guide →](PACKAGES.md)**

## Quick Start

### Installation

Choose your package based on needs:

```elixir
# Minimal - Just terminal buffers
{:raxol_core, "~> 2.0"}

# Web integration - Add LiveView support
{:raxol_core, "~> 2.0"},
{:raxol_liveview, "~> 2.0"}

# Extensible apps - Add plugin system
{:raxol_core, "~> 2.0"},
{:raxol_plugin, "~> 2.0"}

# Or use v1.x (full framework)
{:raxol, "~> 1.5.4"}
```

Using `runtime: false` provides UI components without terminal emulator runtime for:
- Web applications
- Component libraries
- Testing UI logic
- Reduced application size

### Development Setup

```bash
# Clone and explore
git clone https://github.com/Hydepwns/raxol.git
cd raxol
mix deps.get

# Run quality checks
mix raxol.check

# Run tests
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test

# Generate type specs
mix raxol.gen.specs lib --recursive
```

## Choose Your Framework

```elixir
use Raxol.UI, framework: :react      # Familiar React patterns
use Raxol.UI, framework: :svelte     # Reactive with compile-time optimization
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
- All framework adapters (React, Svelte, LiveView, HEEx)
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

| Metric       | Raxol         | Alacritty    | Kitty        | iTerm2       | WezTerm      |
|--------------|---------------|--------------|--------------|--------------|--------------|
| Parser Speed | 3.3μs/op      | ~5μs/op      | ~4μs/op      | ~15μs/op     | ~6μs/op      |
| Memory Usage | 2.8MB         | ~15MB        | ~25MB        | ~50MB        | ~20MB        |
| Startup Time | <10ms         | ~50ms        | ~40ms        | ~100ms       | ~60ms        |
| Test Suite   | 793 tests     | ~800 tests   | ~600 tests   | ~500 tests   | ~700 tests   |

### Additional Metrics
- Cursor Operations: 0.5μs per movement
- Buffer Write: 1.2μs per character
- Screen Clear: <50μs for full screen
- Input Latency: <2ms keyboard to screen
- Render Performance: 60 FPS maintained

## Documentation

### Getting Started

- **[Quickstart](docs/getting-started/QUICKSTART.md)** - 5/10/15 minute tutorials
- **[Core Concepts](docs/getting-started/CORE_CONCEPTS.md)** - Understand buffers and rendering
- **[Migration Guide](docs/getting-started/MIGRATION_FROM_DIY.md)** - For teams with existing terminal code

### Cookbooks

- **[LiveView Integration](docs/cookbook/LIVEVIEW_INTEGRATION.md)** - Render terminals in Phoenix
- **[Performance Optimization](docs/cookbook/PERFORMANCE_OPTIMIZATION.md)** - 60fps techniques
- **[Theming](docs/cookbook/THEMING.md)** - Custom color schemes

### Features

- **[VIM Navigation](docs/features/VIM_NAVIGATION.md)** - VIM-style keybindings and movement
- **[Command Parser](docs/features/COMMAND_PARSER.md)** - Tab completion, history, argument parsing
- **[Fuzzy Search](docs/features/FUZZY_SEARCH.md)** - Multi-mode search with highlighting
- **[File System](docs/features/FILESYSTEM.md)** - Virtual filesystem with Unix commands
- **[Cursor Effects](docs/features/CURSOR_EFFECTS.md)** - Visual trails and glow effects
- **[Features Overview](docs/features/README.md)** - Complete guide to all features

### API Reference

- **[Buffer API](docs/core/BUFFER_API.md)** - Complete buffer operations reference
- **[Architecture](docs/core/ARCHITECTURE.md)** - Design decisions and internals
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

## License

MIT License - see [LICENSE.md](LICENSE.md)
