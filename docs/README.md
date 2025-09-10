# Raxol Documentation

Documentation for the Raxol full-stack terminal application framework.

## Quick Start

**New to Raxol?** Start here:

1. **Install**: [Development Setup](DEVELOPMENT.md#quick-setup) (Nix recommended)
2. **Learn**: Interactive tutorials with `mix raxol.tutorial`
3. **Try**: Component demos with `mix raxol.playground`

## Core Documentation

### System Architecture & Setup
- [**Architecture Decision Records**](./adr/README.md) - Architectural foundation
  - 9 ADRs covering major decisions
  - Production implementations with metrics and validation
  - Enterprise documentation for onboarding and maintenance
- [**Architecture**](ARCHITECTURE.md) - System design, layers, and modules
- [**Development**](DEVELOPMENT.md) - Setup, workflow, and commands  
- [**Configuration**](CONFIGURATION.md) - Settings and environment config

### Framework Features
- [**Web Interface**](WEB_INTERFACE_GUIDE.md) - Phoenix LiveView integration with WASH-style continuity
- [**Plugin System**](PLUGIN_SYSTEM_GUIDE.md) - Creating and managing plugins
- [**Component System**](./components/README.md) - Component architecture and lifecycle
- [**Component API**](./components/api/README.md) - Component development API

## User Guides

Guides organized by topic:

- [**Getting Started**](./getting-started.md) - Installation and first app
- [**Core Concepts**](./examples/guides/02_core_concepts/) - Framework fundamentals  
- [**Components & Layout**](./examples/guides/03_components_and_layout/) - UI building blocks and layout
- [**Extensions**](./examples/guides/04_extending_raxol/) - Plugins and customization
- [**Development**](./examples/guides/05_development_and_testing/) - Testing and workflow
- [**Enterprise**](./examples/guides/06_enterprise/) - Auth, monitoring, deployment
- **WASH System** - Web continuity architecture and design (documentation in progress)

## Examples & Code

### Interactive Examples
- [**Example Browser**](./examples/snippets/README.md) - Browse all examples
- [**Basic Examples**](./examples/snippets/basic/) - Simple patterns and concepts
- [**Advanced Examples**](./examples/snippets/advanced/) - Complex implementations
- [**Showcase**](./examples/snippets/showcase/) - Feature demonstrations

### Interactive Learning
- **Interactive Tutorial**: `mix raxol.tutorial` - Hands-on learning with code execution
- [**Getting Started Guide**](./getting-started.md) - Comprehensive getting started guide
- [**Component Deep Dive**](./tutorials/02_component_deep_dive.md) - Advanced component patterns
- [**Terminal Emulation**](./tutorials/03_terminal_emulation.md) - Terminal implementation details
- **Component Playground**: `mix raxol.playground` - Live component testing and preview

## Framework Overview

**What is Raxol?**  
A terminal framework for Elixir that enables building terminal applications with both local and web interfaces. Features WASH-style web continuity for terminal-to-web migration with persistent session state.

### Key Capabilities
- **Terminal Emulation**: Full ANSI/VT100+ compliance with Sixel graphics
- **Component System**: React-style UI components with lifecycle management  
- **WASH-Style Web Continuity**: Terminal-web migration with persistent state
- **Real-time Collaboration**: Multi-user sessions with cursor tracking and shared state
- **Plugin Architecture**: Runtime-loadable extensions with hot reloading
- **Enterprise Ready**: Authentication, audit logging, encryption, compliance

### Performance
- **Response Time**: <1ms local, <5ms web sessions
- **Throughput**: 10,000+ operations/second per session
- **Scalability**: 100+ concurrent users tested
- **Memory**: Efficient buffer management with configurable limits

## Resources

### External Links
- [GitHub Repository](https://github.com/Hydepwns/raxol)
- [Hex.pm Package](https://hex.pm/packages/raxol)
- [API Documentation](https://hexdocs.pm/raxol)
- [Issue Tracker](https://github.com/Hydepwns/raxol/issues)

### Project Files
- [Changelog](../CHANGELOG.md) - Release history
- [Contributing](../CONTRIBUTING.md) - Development guidelines
- [License](../LICENSE.md) - MIT License

## Getting Help

- **Documentation Issues**: [File an issue](https://github.com/Hydepwns/raxol/issues)
- **Feature Requests**: [GitHub Discussions](https://github.com/Hydepwns/raxol/discussions)
- **Community**: Join our Discord community

---

**Need something specific?** Use the search function or browse the guides above. Most questions are answered in the [Getting Started](./getting-started.md) guide.