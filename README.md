# Raxol

The Most Advanced Terminal Framework in Elixir

[![CI](https://github.com/Hydepwns/raxol/workflows/CI/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml) [![Codecov](https://codecov.io/gh/Hydepwns/raxol/branch/master/graph/badge.svg)](https://codecov.io/gh/Hydepwns/raxol) [![Hex.pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol) [![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/raxol) [![Compilation](https://img.shields.io/badge/warnings-0-brightgreen.svg)](https://github.com/Hydepwns/raxol) [![Tests](https://img.shields.io/badge/tests-1751%20passing-brightgreen.svg)](https://github.com/Hydepwns/raxol/actions)

## Project Status

**Version**: 1.0.0 - Production-Ready with Enterprise Features

| Metric | Status | Details |
|--------|--------|---------|
| **Code Quality** | Excellent | 0 compilation warnings (100% reduction from 227) |
| **Test Coverage** | 100% | 1751/1751 tests passing, 2 skipped |
| **Documentation** | Complete | 100% public API coverage |
| **Performance** | Optimized | Parser: 3.3 μs/op (30x improvement) |
| **Features** | Complete | All major features implemented |
| **Enterprise** | Ready | Audit + Encryption + Compliance |

## What is Raxol?

Raxol is a full-stack terminal application framework that combines:

- **Advanced Terminal Emulator**: Full ANSI/VT100+ compliant terminal emulator with Sixel graphics, Unicode support
- **Component-Based TUI Framework**: React-style component system for building rich terminal user interfaces  
- **WASH-Style Web Continuity**: Seamless terminal-web migration with persistent state and real-time collaboration
- **Extensible Plugin Architecture**: Runtime plugin system for extending functionality
- **Enterprise Features**: Built-in authentication, session management, metrics, and monitoring

## Architecture

Raxol follows a layered, modular architecture designed for extensibility and performance:

```
┌─────────────────────────────────────────────────────────┐
│                    Applications                         │
│         (User TUI Apps, Plugins, Extensions)            │
├─────────────────────────────────────────────────────────┤
│                 UI Framework Layer                      │
│      (Components, Layouts, Themes, Event System)        │
├─────────────────────────────────────────────────────────┤
│                Web Interface Layer                      │
│     (Phoenix LiveView, WebSockets, Auth, API)           │
├─────────────────────────────────────────────────────────┤
│               Terminal Emulator Core                    │
│      (ANSI Parser, Buffer Manager, Input Handler)       │
├─────────────────────────────────────────────────────────┤
│                Platform Services                        │
│   (Plugins, Config, Metrics, Security, Persistence)     │
└─────────────────────────────────────────────────────────┘
```

### Design Principles

- **Separation of Concerns**: Each layer has clear responsibilities
- **Event-Driven**: Components communicate through events
- **Supervision Trees**: Fault-tolerant with OTP supervision
- **Performance First**: Optimized for high-throughput terminal operations
- **Extensible**: Plugin system allows extending any layer

## Core Features

### Terminal Framework
- **Terminal Emulator**: Full ANSI/VT100+ compliance with Sixel graphics and Unicode
- **Component System**: React-style UI components with state management and lifecycle hooks
- **WASH-Style Web Continuity**: Seamless terminal-web migration with state preservation and real-time collaboration
- **Plugin Architecture**: Runtime-loadable extensions with hot reloading and dependency management
- **Performance**: Sub-millisecond operations with efficient buffer management and damage tracking

### Enterprise Ready
- **Authentication & Security**: Built-in auth, audit logging, encryption, and compliance features
- **Monitoring & Metrics**: Comprehensive telemetry with Prometheus integration
- **Scalability**: Supports 100+ concurrent users with horizontal scaling capabilities

## Installation

**Package**: Add `{:raxol, "~> 0.9.0"}` to your `mix.exs` dependencies

**Development**: 
```bash
git clone https://github.com/Hydepwns/raxol.git
cd raxol
nix-shell  # Recommended for auto-configured environment
mix deps.get && mix test
mix raxol.tutorial  # Start interactive tutorials
mix raxol.playground  # Try component playground
```

**Prerequisites**: Elixir 1.17+, PostgreSQL (optional), Node.js (for assets)

## Performance

- **Response Time**: <1ms local, <5ms web sessions  
- **Throughput**: 10,000+ operations/second per session
- **Test Coverage**: 100% (1751/1751 tests passing)
- **Quality**: Zero compilation warnings, production-ready

## Documentation

**📚 [Complete Documentation Hub](docs/CONSOLIDATED_README.md)**

### Architecture Decision Records ✅
**[ADR Documentation](docs/adr/README.md)** - Complete architectural foundation documented
- 9 comprehensive ADRs covering all major architectural decisions
- Production-ready implementations with performance metrics
- Enterprise-grade decision context and trade-off analysis

### Developer Resources
- **Interactive Tutorials**: `mix raxol.tutorial` - Guided hands-on learning
- **Component Playground**: `mix raxol.playground` - Live component testing
- [Development Setup](docs/DEVELOPMENT.md) - Installation and environment
- [Component Reference](docs/components/README.md) - UI building blocks  
- [API Documentation](https://hexdocs.pm/raxol) - Complete API reference

## License

MIT License - see [LICENSE.md](LICENSE.md)

## Support

- [Documentation Hub](docs/CONSOLIDATED_README.md)
- [Hex.pm Package](https://hex.pm/packages/raxol)

---

*This README is generated from schema files to ensure consistency. To modify, update the schema files in `docs/schema/` and regenerate.*
