# Raxol Documentation Hub

Central navigation for all Raxol documentation.

## Quick Navigation

### Essentials
- [Installation](../README.md#installation)
- [Getting Started](getting-started.md)
- [API Reference](api-reference.md)
- [Examples](../examples/README.md)

### Core Documentation
- [Development](development.md)
- [UI Components](components.md)
- [Performance](performance.md)
- [Testing](testing.md)
- [Security](security.md)

### Guides
- [Custom Components](guides/custom_components.md)
- [Performance Optimization](guides/performance_optimization.md)
- [Accessibility](guides/accessibility_implementation_guide.md)
- [Multi-Framework](guides/multi_framework_migration_guide.md)

### Advanced
- [Architecture Decisions](adr/)
- [Benchmarks](bench/)

### Tools & Automation
- **Scripts** - Development scripts in `scripts/` directory
- **CI/CD Workflows** - GitHub Actions in `.github/workflows/`

### Standards & Guidelines
- [**Naming Conventions**](development/NAMING_CONVENTIONS.md) - Code organization
- [**Duplicate Prevention**](development/duplicate_filename_prevention.md) - File naming

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