# Raxol

[![CI](https://github.com/Hydepwns/raxol/workflows/CI/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml)
[![Tests](https://img.shields.io/badge/tests-2134-brightgreen.svg)](https://github.com/Hydepwns/raxol/actions)
[![Coverage](https://img.shields.io/badge/coverage-99.1%25-brightgreen.svg)](https://codecov.io/gh/Hydepwns/raxol)
[![Performance](https://img.shields.io/badge/parser-3.3μs%2Fop-blue.svg)](bench/README.md)
[![Hex.pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/raxol)

## High-Performance Terminal Application Framework

Raxol brings modern UI development patterns to the terminal. Think **React, Svelte, LiveView** meets tmux.

### Why Raxol?

- **Performance**: 3.3μs parser operations, 2.8MB memory per session
- **Multi-Framework Support**: Choose React, Svelte, LiveView, or HEEx patterns
- **Enterprise Features**: Audit logging, encryption, SAML/OIDC, compliance support
- **Advanced Capabilities**: Sixel graphics, session continuity, real-time collaboration

## Quick Start

```bash
# Add to mix.exs
{:raxol, "~> 1.4.1"}

# Clone and explore
git clone https://github.com/Hydepwns/raxol.git
cd raxol
mix deps.get

# Run quality checks
mix raxol.check

# Run tests
mix raxol.test
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
  import Raxol.LiveView, only: [assign: 2, assign: 3]

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

[View more examples →](examples/README.md)

## Key Features

### Core Terminal Framework
- Full VT100/ANSI compliance with modern extensions
- Sixel graphics and GPU acceleration
- Mouse support with full event handling
- Tab completion and command history

### Multi-Framework UI System
- Universal features across all frameworks (actions, transitions, context, slots)
- 60 FPS animation engine
- Component composition and theming

### Enterprise Features
- WASH-style session continuity
- Real-time collaboration with CRDT sync
- SOC2/HIPAA/GDPR compliant audit logging
- AES-256-GCM encryption with key rotation

## Performance Metrics

| Metric       | Raxol         | Alacritty    | xterm.js     | Blessed.js   |
|--------------|---------------|--------------|--------------|--------------|
| Parser Speed | **3.3μs/op**  | ~5μs/op      | ~15μs/op     | ~50μs/op     |
| Memory Usage | **2.8MB**     | ~15MB        | ~8MB         | ~20MB        |
| Startup Time | **<10ms**     | ~100ms       | N/A          | ~150ms       |
| Test Suite   | **2134 tests**| ~800 tests   | ~600 tests   | ~500 tests   |

### Additional Verified Metrics
- **Cursor Operations**: 0.5μs per movement
- **Buffer Write**: 1.2μs per character
- **Screen Clear**: <50μs for full screen
- **Scroll Performance**: 60fps maintained with 10K lines
- **Input Latency**: <1ms keyboard to screen
- **Concurrent Sessions**: 1000+ terminals per GB RAM

## Documentation

**[Documentation Hub](docs/README.md)** - Complete documentation index

## VS Code Extension

Development version available in `editors/vscode/`. To install:

```bash
cd editors/vscode
npm install
npm run compile
code --install-extension .
```

Features: Syntax highlighting, IntelliSense, component snippets, live preview

## Use Cases

Perfect for terminal IDEs, DevOps tools, system monitoring, database clients, chat applications, and games.

## License

MIT License - see [LICENSE.md](LICENSE.md)
