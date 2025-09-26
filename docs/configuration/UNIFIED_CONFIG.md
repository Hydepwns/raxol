# Unified TOML Configuration System

## Overview

Raxol v1.4.1 introduces a unified configuration system based on TOML files. Enhanced in v1.5.4 with UnifiedConfigManager using BaseManager pattern. The `Raxol.Config` module provides centralized configuration management with environment-specific overrides, runtime updates, and validation.

## Features

- **TOML-based configuration** - Human-readable configuration files
- **Environment-specific configs** - Different settings for dev/test/prod
- **Runtime updates** - Modify configuration without restarts
- **Validation** - Automatic validation of configuration values
- **Default values** - Sensible defaults with override capability
- **Hot-reload** - Reload configuration files on demand

## Configuration Files

### Directory Structure
```
config/
├── raxol.toml                    # Main configuration file
├── raxol.example.toml           # Example with all options documented
└── environments/
    ├── development.toml         # Development overrides
    ├── test.toml               # Test environment settings
    └── production.toml         # Production optimizations
```

### Loading Order

1. `config/raxol.toml` - Base configuration
2. `config/environments/{env}.toml` - Environment-specific overrides
3. Runtime overrides via `Config.set/2`

Later values override earlier ones.

## Configuration Schema

### Complete Example (raxol.toml)

```toml
# Terminal Configuration
[terminal]
width = 80
height = 24
scrollback_size = 10000
encoding = "UTF-8"
bell = true

[terminal.cursor]
style = "block"          # Options: block, underline, bar
blink = true
blink_rate = 500         # milliseconds

[terminal.colors]
palette = "default"      # Options: default, solarized, dracula, nord
true_color = true

# Buffer Management
[buffer]
max_size = 1048576       # 1MB in bytes
chunk_size = 4096
compression = false
compression_threshold = 10240

# Rendering Performance
[rendering]
fps_target = 60
max_frame_skip = 3
enable_animations = true
animation_duration = 200  # milliseconds
performance_mode = false
gpu_acceleration = true

# Plugin System
[plugins]
enabled = true
directory = "plugins"
auto_reload = false
allowed = []             # Empty = all allowed
disabled = []
load_timeout = 5000      # milliseconds

# Security Settings
[security]
session_timeout = 1800   # 30 minutes
max_sessions = 5
enable_audit = true
password_min_length = 8
password_require_special = true
password_require_numbers = true
enable_2fa = false

[security.rate_limiting]
enabled = true
window = 60000           # 1 minute
max_requests = 100

# Performance Profiling
[performance]
profiling_enabled = false
benchmark_on_start = false
cache_size = 100000
cache_ttl = 300000       # 5 minutes
worker_pool_size = 4

# Theme Settings
[theme]
name = "default"
auto_switch = false
custom_themes_dir = "themes"

# Logging Configuration
[logging]
level = "info"           # Options: debug, info, warning, error
file = "logs/raxol.log"
max_file_size = 10485760 # 10MB
rotation_count = 5
format = "text"          # Options: text, json
include_metadata = true

# Accessibility Features
[accessibility]
screen_reader = false
high_contrast = false
focus_indicators = true
reduce_motion = false
font_scaling = 1.0

# Keybindings
[keybindings]
enabled = true
config_file = "keybindings.toml"
vim_mode = false
emacs_mode = false
```

## API Usage

### Starting the Config Server

The config server is automatically started by `Raxol.Application`:

```elixir
# In your application.ex
children = [
  {Raxol.Config, [config_file: "config/raxol.toml"]},
  # ... other children
]
```

### Getting Configuration Values

```elixir
# Get a configuration value
width = Raxol.Config.get([:terminal, :width])
# => 80

# With default value
bg_color = Raxol.Config.get([:terminal, :background], default: "#000000")
# => "#000000" if not configured

# Get entire section
terminal_config = Raxol.Config.get([:terminal])
# => %{"width" => 80, "height" => 24, ...}

# Get all configuration
all_config = Raxol.Config.all()
```

### Setting Configuration at Runtime

```elixir
# Update a single value
Raxol.Config.set([:terminal, :width], 120)

# Update multiple values
Raxol.Config.set([:rendering], %{
  "fps_target" => 120,
  "gpu_acceleration" => true
})
```

### Loading Additional Configuration Files

```elixir
# Load and merge additional configuration
{:ok, config} = Raxol.Config.load_file("config/custom.toml")

# Reload all configuration files
:ok = Raxol.Config.reload()
```

### Validating Configuration

```elixir
# Validate current configuration
case Raxol.Config.validate() do
  {:ok, :valid} ->
    IO.puts("Configuration is valid")

  {:error, errors} ->
    IO.puts("Configuration errors:")
    Enum.each(errors, &IO.puts("  - #{&1}"))
end
```

### Exporting Configuration

```elixir
# Export current configuration (including runtime changes)
:ok = Raxol.Config.export("config/current.toml")
```

## Environment-Specific Configuration

### Development (config/environments/development.toml)
```toml
[logging]
level = "debug"
include_metadata = true

[performance]
profiling_enabled = true
benchmark_on_start = false

[plugins]
auto_reload = true

[rendering]
performance_mode = false
```

### Test (config/environments/test.toml)
```toml
[terminal]
width = 80
height = 24
scrollback_size = 100

[logging]
level = "warning"
file = "logs/test.log"

[performance]
profiling_enabled = false
worker_pool_size = 2
```

### Production (config/environments/production.toml)
```toml
[logging]
level = "warning"
format = "json"

[performance]
cache_size = 1000000
worker_pool_size = 8

[rendering]
performance_mode = true
gpu_acceleration = true

[security]
enable_audit = true
enable_2fa = true
```

## Integration Examples

### With Terminal Emulator

```elixir
defmodule MyTerminal do
  def init do
    width = Raxol.Config.get([:terminal, :width])
    height = Raxol.Config.get([:terminal, :height])

    Raxol.Terminal.Emulator.new(width, height)
  end
end
```

### With Rendering Pipeline

```elixir
defmodule MyRenderer do
  def render(buffer) do
    fps_target = Raxol.Config.get([:rendering, :fps_target])
    frame_time = 1000 / fps_target

    # Render with target frame time
    do_render(buffer, frame_time)
  end
end
```

### With Plugin System

```elixir
defmodule PluginLoader do
  def load_plugins do
    if Raxol.Config.get([:plugins, :enabled]) do
      dir = Raxol.Config.get([:plugins, :directory])
      auto_reload = Raxol.Config.get([:plugins, :auto_reload])

      load_from_directory(dir, auto_reload: auto_reload)
    end
  end
end
```

## Dynamic Configuration Updates

### Listening for Configuration Changes

```elixir
defmodule ConfigWatcher do
  use GenServer

  def init(state) do
    # Check config every second
    Process.send_after(self(), :check_config, 1000)
    {:ok, state}
  end

  def handle_info(:check_config, state) do
    new_value = Raxol.Config.get([:my, :setting])

    state = if new_value != state.current_value do
      handle_config_change(new_value)
      %{state | current_value: new_value}
    else
      state
    end

    Process.send_after(self(), :check_config, 1000)
    {:noreply, state}
  end
end
```

### Reloading Configuration

```elixir
# In an IEx session or admin interface
Raxol.Config.reload()

# Or reload and validate
case Raxol.Config.reload() do
  :ok ->
    IO.puts("Configuration reloaded successfully")
  {:error, reason} ->
    IO.puts("Failed to reload: #{inspect(reason)}")
end
```

## Validation Rules

The config system includes built-in validation for:

1. **Terminal dimensions** - Must be positive integers
2. **Performance settings** - Cache size, worker pool size must be positive
3. **Security settings** - Session timeout, max sessions must be positive

Custom validation can be added by modifying `validate_config/1` in `Raxol.Config`.

## Best Practices

### 1. Use Environment-Specific Files
Don't put environment-specific values in the main config:
```toml
# Bad - in raxol.toml
[database]
host = "localhost"  # Changes per environment

# Good - in environments/development.toml
[database]
host = "localhost"

# Good - in environments/production.toml
[database]
host = "db.production.example.com"
```

### 2. Document Configuration Options
Always include raxol.example.toml with all options documented:
```toml
# Frame rate target for rendering
# Higher values = smoother animation but more CPU usage
# Default: 60
fps_target = 60
```

### 3. Validate Critical Settings
Add validation for critical business logic:
```elixir
defp validate_custom_settings(config) do
  if config["my_critical_setting"] < threshold do
    {:error, "my_critical_setting must be >= #{threshold}"}
  else
    :ok
  end
end
```

### 4. Use Defaults Wisely
Always provide sensible defaults in code:
```elixir
timeout = Raxol.Config.get([:network, :timeout], default: 5000)
```

### 5. Group Related Settings
Use nested tables for organization:
```toml
[network]
timeout = 5000
retries = 3

[network.pool]
size = 10
overflow = 5
```

## Migration Guide

### From Application.get_env

Before:
```elixir
width = Application.get_env(:raxol, :terminal_width, 80)
```

After:
```elixir
width = Raxol.Config.get([:terminal, :width], default: 80)
```

### From Multiple Config Files

Before (config/config.exs):
```elixir
config :raxol,
  terminal_width: 80,
  terminal_height: 24
```

After (config/raxol.toml):
```toml
[terminal]
width = 80
height = 24
```

## Troubleshooting

### Config Server Not Started
```elixir
# Ensure it's in your application supervision tree
{Raxol.Config, []}
```

### Invalid TOML Syntax
```bash
# Validate TOML syntax
mix run -e "File.read!('config/raxol.toml') |> Toml.decode!()"
```

### Missing Configuration
```elixir
# Always use defaults
value = Raxol.Config.get([:section, :key], default: "fallback")
```

### Performance Considerations

The config system caches all values in memory. For large configurations:
- Keep configuration files under 1MB
- Avoid storing large data blobs
- Use references to external files for large datasets