# Changelog - Raxol (Meta-package)

All notable changes to the raxol meta-package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-05

### Added
- Initial release of raxol meta-package for v2.0 modular architecture
- Includes all Raxol packages: raxol_core, raxol_liveview, raxol_plugin
- Single dependency for users who want the complete framework
- Provides incremental adoption path for v2.0 features

### Package Contents
- `raxol_core` ~> 2.0 - Terminal buffer primitives
- `raxol_liveview` ~> 2.0 - Phoenix LiveView integration
- `raxol_plugin` ~> 2.0 - Plugin framework

### Migration
- For v1.x users: Continue using the monolithic `raxol` package from root
- For new v2.0 users: Use this meta-package or individual packages as needed
- See migration guide for detailed upgrade path

### Usage
```elixir
# In mix.exs - get everything
{:raxol, "~> 2.0"}

# Or pick and choose
{:raxol_core, "~> 2.0"}
{:raxol_liveview, "~> 2.0"}
```

[2.0.0]: https://github.com/Hydepwns/raxol/releases/tag/v2.0.0
