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

## Quick Start

### Installation

```elixir
# Full installation with runtime (for terminal applications)
{:raxol, "~> 1.5.4"}

# Components-only (no terminal runtime, just UI components)
{:raxol, "~> 1.5.4", runtime: false}
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

**[Full Documentation →](https://hexdocs.pm/raxol)** - Complete API reference and guides

### Recent Features
- **Code Consolidation** (v1.5.4) - BaseManager pattern, TimerManager integration, 99.8% test coverage
- **Type Spec Generator** (v1.4.1) - Automated type specification generation with `mix raxol.gen.specs`
- **Unified Configuration** (v1.4.1) - TOML-based configuration system via `Raxol.Config`

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
