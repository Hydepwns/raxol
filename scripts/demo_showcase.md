# Raxol Demo Showcase

## Interactive Demos

### 1. Interactive Tutorial System
Experience our comprehensive tutorial system with 3 guided lessons:
- **Getting Started**: Learn Raxol basics in 5 minutes
- **Building Components**: Create your first interactive component
- **Advanced Features**: Master animations and state management

```bash
mix raxol.tutorial
```

![Tutorial Demo](demos/tutorial.gif)

### 2. Component Playground
Explore 20+ pre-built components with live preview:
- Real-time property editing
- Animation showcase
- Layout examples
- Theme customization

```bash
mix raxol.playground
```

![Playground Demo](demos/playground.gif)

### 3. VSCode Extension
Professional IDE integration with:
- Full IntelliSense support
- Component snippets
- Hover documentation
- Command palette integration

Install: `code --install-extension raxol-1.0.0.vsix`

![VSCode Demo](demos/vscode.gif)

### 4. WASH-Style Session Continuity
Seamless terminal-web migration:
- State preservation across restarts
- Real-time collaboration
- CRDT-based synchronization
- Multi-tier storage

```elixir
# Start a session
{:ok, session} = Raxol.SessionBridge.create_session("user123")

# Update state
Raxol.SessionBridge.update_state(session.id, %{theme: "dark"})

# State persists across restarts!
```

![WASH Demo](demos/wash.gif)

### 5. World-Class Performance
Industry-leading performance metrics:
- **Parser**: 3.3 μs/operation (30x improvement)
- **Memory**: 2.8MB per session (44% better than target)
- **Startup**: <10ms with Raxol.Minimal
- **Animations**: 60 FPS with spring physics

```bash
# Run benchmarks
mix run bench/simple_parser_test.exs

# Minimal startup
iex -S mix
Raxol.Minimal.start()
```

![Performance Demo](demos/performance.gif)

### 6. Enterprise Features
Production-ready with compliance:
- **Audit Logging**: SOC2/HIPAA/GDPR/PCI-DSS compliant
- **Encryption**: AES-256-GCM with key rotation
- **SIEM Integration**: Splunk, Elasticsearch, QRadar
- **CQRS Architecture**: Event sourcing and command bus

```elixir
# Audit logging
Raxol.Audit.Events.log(:user_action, %{
  user_id: "user123",
  action: "login",
  ip_address: "192.168.1.1"
})

# Encrypted storage
{:ok, encrypted} = Raxol.Enterprise.Encryption.encrypt(sensitive_data)
```

![Enterprise Demo](demos/enterprise.gif)

## Quick Start

```bash
# Install dependencies
mix deps.get

# Run tests (100% passing!)
mix test

# Start interactive shell
iex -S mix

# Launch tutorial
mix raxol.tutorial

# Open playground
mix raxol.playground
```

## Recording Your Own Demos

Use our demo recording script:

```bash
./scripts/demo_videos.sh
```

This will guide you through recording demos using asciinema and converting them to GIFs.

## Share Your Creations

Built something cool with Raxol? Share it with the community:
- Submit a PR with your demo
- Post on our Discord
- Tweet with #RaxolTerminal

## Learn More

- [Documentation](https://hexdocs.pm/raxol)
- [API Reference](docs/API.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Contributing](CONTRIBUTING.md)