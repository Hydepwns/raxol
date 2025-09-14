# Raxol

[![CI](https://github.com/Hydepwns/raxol/workflows/CI/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml)
[![Tests](https://img.shields.io/badge/tests-300%2B%20files-brightgreen.svg)](https://github.com/Hydepwns/raxol/actions)
[![Coverage](https://img.shields.io/badge/coverage-98.7%25-brightgreen.svg)](https://codecov.io/gh/Hydepwns/raxol)
[![Performance](https://img.shields.io/badge/parser-3.3μs%2Fop-blue.svg)](bench/README.md)
[![Hex.pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/raxol)

## High-Performance Terminal Application Framework

Raxol brings modern UI development patterns to the terminal. Think **React, Svelte, LiveView** meets tmux.

### Why Raxol?

- **World-Class Performance**: 3.3μs parser operations, 2.8MB memory per session
- **Multi-Framework Support**: Choose React, Svelte, LiveView, or HEEx patterns
- **Enterprise Ready**: Audit logging, encryption, SAML/OIDC, compliance (SOC2/HIPAA/GDPR)
- **Innovation First**: Sixel graphics, WASH session continuity, real-time collaboration

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

> **Note**: If you cloned before September 2025, reset with: `git fetch origin && git reset --hard origin/master`

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

| Metric       | Raxol         | Industry Standard |
|--------------|---------------|-------------------|
| Parser Speed | **3.3μs/op**  | 100μs/op          |
| Memory Usage | **2.8MB**     | 10MB/session      |
| Startup Time | **<10ms**     | 100ms             |
| Test Coverage| **98.7%**     | 80%               |

## Documentation

**[Documentation Hub](docs/README.md)** - Complete documentation index

## VS Code Extension

```bash
code --install-extension raxol-1.0.1.vsix
```

Features: Syntax highlighting, IntelliSense, component snippets, live preview

## Use Cases

Perfect for terminal IDEs, DevOps tools, system monitoring, database clients, chat applications, and games.

## License

MIT License - see [LICENSE.md](LICENSE.md)
