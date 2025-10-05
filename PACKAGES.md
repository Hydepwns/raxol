# Raxol Packages

Modular architecture for incremental adoption.

## Packages

### [raxol_core](packages/raxol_core/)
Buffer primitives. Zero dependencies, < 100KB.
```elixir
{:raxol_core, "~> 2.0"}
```

### [raxol_liveview](packages/raxol_liveview/)
Phoenix LiveView integration. Requires phoenix_live_view.
```elixir
{:raxol_core, "~> 2.0"},
{:raxol_liveview, "~> 2.0"}
```

### [raxol_plugin](packages/raxol_plugin/)
Plugin system for extensible apps.
```elixir
{:raxol_core, "~> 2.0"},
{:raxol_plugin, "~> 2.0"}
```

### raxol (coming soon)
Full framework including all packages.

## Comparison

| Package | Size | Dependencies | Use Case |
|---------|------|--------------|----------|
| raxol_core | ~100KB | None | CLI tools, minimal apps |
| raxol_liveview | ~500KB | phoenix_live_view | Web terminals |
| raxol_plugin | ~200KB | raxol_core | Extensible apps |
| raxol | ~1MB | All above | Full framework |

## Migration Paths

### 1. Minimal (CLI tools)
```elixir
{:raxol_core, "~> 2.0"}
```

### 2. Web (LiveView integration)
```elixir
{:raxol_core, "~> 2.0"},
{:raxol_liveview, "~> 2.0"}
```

### 3. Extensible (Plugin system)
```elixir
{:raxol_core, "~> 2.0"},
{:raxol_plugin, "~> 2.0"}
```

### 4. Full (Everything)
```elixir
{:raxol, "~> 2.0"}  # Coming soon
```

## Migration Guide

See [MIGRATION_FROM_DIY.md](docs/getting-started/MIGRATION_FROM_DIY.md) for detailed migration strategies.

## Publishing Status

All packages ready for Hex.pm. Publishing planned for v2.0.0 release.
