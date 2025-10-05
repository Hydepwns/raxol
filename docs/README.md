# Documentation

Navigation for Raxol documentation.

## Quick Navigation

### Essentials
- [Installation](../README.md#installation)
- [Getting Started](getting-started/QUICKSTART.md)
- [Package Guide](getting-started/PACKAGES.md)
- [API Reference](api-reference.md)
- [Examples](../examples/README.md)

### Core Documentation
- [Development](DEVELOPMENT.md)
- [UI Components](components.md)
- [Testing](testing.md)
- [Security](security.md)

### Guides
- [Custom Components](guides/custom_components.md)
- [Performance](cookbook/PERFORMANCE_OPTIMIZATION.md)
- [Accessibility](guides/accessibility_implementation_guide.md)
- [Multi-Framework](guides/multi_framework_migration_guide.md)

### Advanced
- [Architecture Decisions](adr/)
- [Benchmarks](bench/)

### Tools & Automation
- Scripts: `scripts/` directory
- CI/CD: `.github/workflows/`

### Standards
- [Naming Conventions](development/NAMING_CONVENTIONS.md)
- [Duplicate Prevention](development/duplicate_filename_prevention.md)

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

## Updates

1. Follow existing patterns
2. Update index for new sections
3. Keep examples executable
4. Verify with `mix docs`

---

Questions: [open an issue](https://github.com/Hydepwns/raxol/issues)