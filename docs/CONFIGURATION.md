# Raxol Terminal Emulator Configuration Guide

## Overview

The Raxol Terminal Emulator uses a centralized configuration system that manages all aspects of the terminal's operation. This guide explains how to configure the terminal emulator and its various components.

## Configuration File

The main configuration file is located at `config/raxol.exs`. The configuration is organized into several sections:

```elixir
import Config

config :raxol,
  terminal: %{
    width: 80,
    height: 24,
    mode: :normal
  },
  buffer: %{
    max_size: 10000,
    scrollback: 1000
  },
  renderer: %{
    mode: :gpu,
    double_buffering: true
  }
```

## Configuration Sections

### Terminal Configuration

Controls the basic terminal settings:

```elixir
terminal: %{
  width: 80,        # Terminal width in characters
  height: 24,       # Terminal height in characters
  mode: :normal     # Terminal mode (:normal or :raw)
}
```

### Buffer Configuration

Manages the terminal buffer settings:

```elixir
buffer: %{
  max_size: 10_000,  # Maximum buffer size in characters
  scrollback: 1000  # Number of lines to keep in scrollback
}
```

### Renderer Configuration

Controls the rendering system:

```elixir
renderer: %{
  mode: :gpu,           # Rendering mode (:gpu or :cpu)
  double_buffering: true # Whether to use double buffering
}
```

## Runtime Configuration

The configuration can be modified at runtime using the `Raxol.Core.Config.Manager` module:

```elixir
# Get a configuration value
width = Raxol.Core.Config.Manager.get(:terminal_width)

# Set a configuration value
:ok = Raxol.Core.Config.Manager.set(:terminal_width, 100)

# Update a configuration value
:ok = Raxol.Core.Config.Manager.update(:terminal_width, &(&1 + 50))

# Delete a configuration value
:ok = Raxol.Core.Config.Manager.delete(:custom_key)

# Get all configuration values
config = Raxol.Core.Config.Manager.get_all()

# Reload configuration from file
:ok = Raxol.Core.Config.Manager.reload()
```

## Configuration Validation

The configuration system validates all configuration values to ensure they are valid:

- Terminal width and height must be positive integers
- Terminal mode must be either `:normal` or `:raw`
- Buffer max size must be a positive integer
- Buffer scrollback must be a non-negative integer
- Renderer mode must be either `:gpu` or `:cpu`
- Renderer double buffering must be a boolean

## Configuration Persistence

Configuration changes can be persisted to the configuration file:

```elixir
# Set a value and persist it
:ok = Raxol.Core.Config.Manager.set(:terminal_width, 100, persist: true)

# Set a value without persisting it
:ok = Raxol.Core.Config.Manager.set(:terminal_width, 100, persist: false)
```

## Environment-Specific Configuration

The configuration system supports environment-specific settings:

```elixir
# config/dev.exs
import Config

config :raxol,
  terminal: %{
    width: 100,
    height: 30
  }

# config/prod.exs
import Config

config :raxol,
  terminal: %{
    width: 80,
    height: 24
  }
```

## Best Practices

1. **Configuration Organization**

   - Keep related settings together
   - Use descriptive names
   - Document configuration options

2. **Validation**

   - Always validate configuration values
   - Provide meaningful error messages
   - Handle invalid configurations gracefully

3. **Persistence**

   - Only persist necessary changes
   - Use environment-specific settings
   - Back up configuration files

4. **Security**
   - Don't store sensitive data in configuration
   - Use environment variables for secrets
   - Validate all configuration inputs

## Troubleshooting

### Common Issues

1. **Invalid Configuration**

   - Check for missing required fields
   - Verify value types and ranges
   - Check for syntax errors

2. **Configuration Not Loading**

   - Verify file path
   - Check file permissions
   - Validate file syntax

3. **Runtime Changes Not Persisting**
   - Check persist option
   - Verify file permissions
   - Check for write errors

### Error Messages

- `:invalid_config_file` - Configuration file is invalid or missing
- `:invalid_value` - Configuration value is invalid
- `:persist_error` - Failed to persist configuration changes

## Migration Guide

### From Legacy Configuration

1. **Update Configuration Structure**

   - Move settings to appropriate sections
   - Update value formats
   - Add missing required fields

2. **Update Configuration Access**

   - Replace direct access with Manager calls
   - Update validation logic
   - Add persistence support

3. **Test Configuration**
   - Verify all settings work
   - Check validation
   - Test persistence

## API Reference

### Raxol.Core.Config.Manager

#### Functions

- `start_link/1` - Start the configuration manager
- `get/2` - Get a configuration value
- `set/3` - Set a configuration value
- `update/3` - Update a configuration value
- `delete/2` - Delete a configuration value
- `get_all/0` - Get all configuration values
- `reload/0` - Reload configuration from file

## Support

For issues and feature requests, please use the issue tracker on GitHub.
