# Terminal Configuration System

This directory contains the new terminal configuration system, which was refactored from the original monolithic `configuration.ex` file (2394 lines).

## Module Structure

The configuration system is organized into focused modules:

- **Schema** (`schema.ex`): Defines the configuration schema with types and documentation
- **Validation** (`validation.ex`): Validates configuration values against the schema
- **Persistence** (`persistence.ex`): Loads and saves configuration to disk
- **Defaults** (`defaults.ex`): Generates default configuration values
- **Capabilities** (`capabilities.ex`): Detects terminal capabilities based on environment
- **Profiles** (`profiles.ex`): Manages terminal configuration profiles
- **Application** (`application.ex`): Applies configuration to the terminal

The main entry point is the `Raxol.Terminal.Config` module, which provides a façade with delegated functions to the appropriate modules.

## Usage

### Basic Usage

```elixir
alias Raxol.Terminal.Config

# Get default configuration
config = Config.generate_default_config()

# Load a preset profile
{:ok, iterm_config} = Config.load_profile("iterm2")

# Apply configuration
{:ok, _} = Config.apply_config(config)

# Apply a partial update
{:ok, _} = Config.apply_partial_config(%{display: %{width: 100}})

# Validate configuration
{:ok, validated} = Config.validate_config(config)
```

### Detecting Capabilities

```elixir
# Detect terminal capabilities
capabilities = Config.detect_capabilities()

# Generate an optimized configuration based on capabilities
optimized = Config.optimized_config()
```

### Persistence

```elixir
# Save configuration
:ok = Config.save_config(config)

# Load configuration
{:ok, loaded} = Config.load_config()
```

## Migration from the Old API

The old `Raxol.Terminal.Configuration` module is now deprecated but remains as a façade for backward compatibility. It delegates all calls to the new modules.

When migrating code:

1. Replace `alias Raxol.Terminal.Configuration` with `alias Raxol.Terminal.Config`
2. Update function calls according to this mapping:

| Old API                                | New API                                       |
| -------------------------------------- | --------------------------------------------- |
| `Configuration.new()`                  | `Config.generate_default_config()`            |
| `Configuration.detect_and_configure()` | `Config.detect_capabilities()`                |
| `Configuration.apply(config)`          | `Config.apply_config(config)`                 |
| `Configuration.get_preset(:name)`      | `Config.load_profile("name")`                 |
| `Configuration.validate(config)`       | `Config.validate_config(config)`              |
| `Configuration.update(config, opts)`   | `Config.apply_partial_config(updated_config)` |

Note that the new API uses a different configuration structure, with settings organized into logical groups (`display`, `input`, `rendering`, etc.).

## Future Development

- Add more terminal types and profiles
- Improve capability detection in different environments
- Add a configuration visualization tool
- Implement a validation/migration system for configuration file format changes
- Add a programmatic API for third-party extensions to register their own configuration options
