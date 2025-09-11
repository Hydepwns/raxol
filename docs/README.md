# Raxol Documentation Hub

Central navigation for all Raxol documentation.

## Documentation Categories

### Getting Started
- [**Quick Start Guide**](../README.md#quick-start) - Installation and first steps
- [**Interactive Tutorial**](guides/tutorial.md) - Learn Raxol interactively
- [**Examples**](../examples/README.md) - Code examples and patterns

### Developer Guides
- [**Development Guide**](development.md) - Contributing and development setup
- [**Architecture Guide**](ARCHITECTURE.md) - System design and patterns
- [**API Reference**](https://hexdocs.pm/raxol) - Complete API documentation

### Framework Documentation
- [**Multi-Framework UI**](guides/multi-framework.md) - React, Svelte, LiveView patterns
- [**Terminal Subsystem**](../lib/raxol/terminal/README.md) - Terminal emulation details
- [**Component Catalog**](guides/components.md) - Available UI components

### Performance & Testing
- [**Benchmarking Guide**](bench/README.md) - Performance testing
- [**Test Suite**](../test/README.md) - Testing framework and patterns
- [**Metrics System**](../lib/raxol/core/metrics/README.md) - Performance monitoring

### Advanced Topics
- [**Architecture Decisions**](adr/README.md) - ADR documentation
- [**Security & Compliance**](guides/security.md) - Enterprise features
- [**Plugin Development**](guides/plugins.md) - Extending Raxol

### Tools & Automation
- [**Scripts**](../scripts/README.md) - Development scripts and tools
- [**CI/CD Workflows**](../.github/workflows/README.md) - GitHub Actions setup
- [**VS Code Extension**](../vscode-raxol/README.md) - IDE integration

### Standards & Guidelines
- [**Naming Conventions**](development/NAMING_CONVENTIONS.md) - Code organization
- [**Duplicate Prevention**](development/duplicate_filename_prevention.md) - File naming
- [**Contributing**](../CONTRIBUTING.md) - Contribution guidelines

## Quick Links

| Resource | Description |
|----------|-------------|
| [HexDocs](https://hexdocs.pm/raxol) | Official API documentation |
| [GitHub](https://github.com/Hydepwns/raxol) | Source code repository |
| [Issues](https://github.com/Hydepwns/raxol/issues) | Bug reports and features |
| [Changelog](../CHANGELOG.md) | Version history |

## Documentation Structure

```
docs/
├── README.md           # This file - Documentation hub
├── guides/            # User and developer guides
├── development/       # Development documentation
├── adr/              # Architecture Decision Records
├── bench/            # Benchmarking documentation
└── releases/         # Release notes and history
```

## Quick Commands

```bash
# Interactive tutorial
mix raxol.tutorial

# Component playground
mix raxol.playground

# Run tests
mix test

# Run benchmarks
mix run bench/scripts/ansi_parser_bench.exs

# Generate docs
mix docs
```

## Documentation Updates

To update documentation:
1. Follow patterns in existing docs
2. Update this index if adding new sections
3. Keep examples executable
4. Run `mix docs` to verify generation

---

For questions or improvements, please [open an issue](https://github.com/Hydepwns/raxol/issues).