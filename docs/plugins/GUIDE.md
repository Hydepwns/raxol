# Plugin Development Guide

> [Documentation](../README.md) > [Plugins](README.md) > Guide

Complete guide to developing Raxol plugins with lifecycle management.

**Version**: v2.0.0 | **Target**: Plugin developers | **Level**: Intermediate

## Quick Start

### Basic Plugin Structure

```elixir
defmodule YourApp.Plugins.MyPlugin do
  @behaviour Raxol.Core.Runtime.Plugins.Plugin
  use GenServer
  require Logger

  # 1. Define manifest
  def manifest do
    %{
      name: "my-plugin",
      version: "1.0.0",
      description: "Brief description",
      author: "Your Name",
      dependencies: %{"raxol-core" => "~> 1.5"},
      capabilities: [:ui_panel, :keyboard_input],
      config_schema: %{
        hotkey: %{type: :string, default: "ctrl+p"}
      }
    }
  end

  # 2. Define state
  defstruct [:config, :data, :timers]

  # 3. Implement required callbacks
  @impl true
  def init(config) do
    {:ok, %__MODULE__{config: config}}
  end

  @impl true
  def enable(state), do: {:ok, state}

  @impl true
  def disable(state), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok
end
```

See [TEMPLATES.md](TEMPLATES.md) for complete working examples.

## Plugin Lifecycle

### States & Transitions

```
Discovery → Loading → Starting → Running → Stopping → Stopped → Terminated
            ↑ init   ↑ enable           ↑ disable           ↑ terminate
```

### 1. Discovery Phase

System discovers plugins and validates manifests:
- Module discovery
- Manifest validation
- Dependency resolution
- Security analysis (BEAM bytecode inspection)

### 2. Loading Phase (init/1)

```elixir
@impl true
def init(config) do
  state = %__MODULE__{
    config: config,
    data: load_initial_data()
  }
  {:ok, state}
end
```

**Status**: `:loaded`

### 3. Starting Phase (enable/1)

```elixir
@impl true
def enable(state) do
  # Set up resources
  timer = :timer.send_interval(5000, :refresh)
  new_state = %{state | timers: [timer]}
  {:ok, new_state}
end
```

**Status**: `:starting` → `:running`

### 4. Runtime Phase

Plugins handle events and commands while running.

#### Event Filtering (Optional)

```elixir
@callback filter_event(event(), state()) :: {:ok, event()} | :halt | any()

def filter_event({:key_press, "ctrl+p"}, state) do
  # Intercept and handle
  {:ok, {:plugin_event, :palette_open}}
end

def filter_event(event, _state) do
  # Pass through
  {:ok, event}
end
```

#### Command Handling (Optional)

```elixir
@callback handle_command(command(), list(), state()) ::
  {:ok, state(), any()} | {:error, any(), state()}

def handle_command(:refresh, [], state) do
  new_data = fetch_data()
  {:ok, %{state | data: new_data}, :ok}
end

def get_commands do
  [{:refresh, :handle_command, 3}]
end
```

### 5. Stopping Phase (disable/1)

```elixir
@impl true
def disable(state) do
  # Clean up resources
  Enum.each(state.timers, &:timer.cancel/1)
  {:ok, %{state | timers: []}}
end
```

**Status**: `:stopping` → `:stopped`

### 6. Termination Phase (terminate/2)

```elixir
@impl true
def terminate(_reason, state) do
  # Final cleanup
  :ok
end
```

## Plugin Manifest

Complete manifest configuration:

```elixir
def manifest do
  %{
    # Required
    name: "unique-name",              # Kebab-case
    version: "1.0.0",                 # Semantic versioning
    description: "What it does",      # User-facing
    author: "Your Name",              # Author info

    # Dependencies
    dependencies: %{
      "raxol-core" => "~> 1.5",      # Raxol version
      "other-plugin" => "~> 2.0"     # Plugin deps
    },

    # Capabilities
    capabilities: [
      :ui_panel,        # Renders UI panels
      :keyboard_input,  # Handles keyboard
      :shell_command,   # Executes commands
      :file_system,     # Accesses filesystem
      :file_watcher,    # Watches files
      :status_line,     # Status line integration
      :theme_provider   # Provides themes
    ],

    # Configuration
    config_schema: %{
      field: %{
        type: :string,           # :string, :integer, :boolean, :list, :map
        default: "value",        # Default value
        description: "Purpose",  # Documentation
        required: false,         # Optional?
        enum: ["a", "b"]        # Valid values (optional)
      }
    }
  }
end
```

## Event System

### Event Types

- **Input**: `{:key_press, key}`, `{:mouse_click, x, y}`
- **Terminal**: `{:terminal_resize, {w, h}}`, `{:terminal_focus, bool}`
- **System**: `{:file_change, path}`, `{:process_exit, pid, reason}`
- **Plugin**: `{:plugin_loaded, name}`, `{:plugin_unloaded, name}`

### Event Flow

```
System Event → filter_event/2 (priority order) → Core Processing
                     ↓
              Can modify, pass through, or halt
```

### Event Filtering

Implement `filter_event/2` to intercept, modify, or block events:

```elixir
# Block events (stops propagation to other plugins and core)
def filter_event({:key_press, "F12"}, _state), do: :halt

# Modify events
def filter_event({:key_press, "j"}, _state) do
  {:ok, {:key_press, :arrow_down}}
end

# Pass through unchanged
def filter_event(event, _state), do: {:ok, event}
```

### Plugin Priority

Control event processing order with the `priority` metadata field:

```elixir
def manifest do
  %{
    name: "high-priority-plugin",
    version: "1.0.0",
    priority: 1,  # Lower = higher priority (processed first)
    # ...
  }
end
```

Plugins without explicit priority default to `1000` (low priority).

### Plugin Dependencies

Declare dependencies to ensure correct processing order:

```elixir
def manifest do
  %{
    name: "dependent-plugin",
    version: "1.0.0",
    dependencies: %{
      "base-plugin" => "~> 1.0"  # Processed after base-plugin
    },
    # ...
  }
end
```

The event processor automatically sorts plugins by dependency order, ensuring
dependent plugins see events after their dependencies have processed them.

### Error Handling in Filters

Filter errors are logged but don't stop event propagation:

```elixir
# If this crashes, the event passes through to the next plugin
def filter_event(event, state) do
  # Plugin errors are isolated
  {:ok, transform(event)}
end
```

Filters run under `PluginSupervisor` with a 1-second timeout by default.

## Capabilities

### UI Panel

```elixir
def render_panel(state, width, height) do
  [
    %{text: "Header", style: bold()},
    %{text: "Content", style: normal()}
  ]
  |> pad_to_height(height, width)
end
```

### Keyboard Input

```elixir
# Register in manifest
capabilities: [:keyboard_input]

# Handle in filter_event/2
def filter_event({:key_press, hotkey}, state) when hotkey == state.config.hotkey do
  # Handle hotkey
  {:ok, {:plugin_event, :activated}}
end
```

### Status Line

```elixir
def get_status_line(state) do
  "Plugin: #{state.count} items"
end
```

### File Watcher

```elixir
def init(config) do
  {:ok, watcher} = FileSystem.start_link(dirs: [config.watch_dir])
  FileSystem.subscribe(watcher)
  {:ok, %__MODULE__{watcher: watcher}}
end

def filter_event({:file_event, _watcher, {path, _events}}, state) do
  # Handle file change
  {:ok, {:file_changed, path}}
end
```

## State Management

Plugin state is managed through an ETS-backed `StateManager` for efficient
concurrent access and crash recovery.

### Best Practices

```elixir
defstruct [
  :config,          # User configuration
  :ui_state,        # UI-related state
  :data,            # Plugin data
  :timers,          # Active timers
  :subscriptions,   # Event subscriptions
  :cache            # Cached computations
]
```

### State Isolation

Each plugin's state is isolated. State updates from `handle_event/2` are
automatically persisted:

```elixir
def handle_event(event, state) do
  # Return updated state - automatically persisted
  {:ok, %{state | last_event: event}}
end
```

### Hot Reload

State persists across hot reloads:

```elixir
def enable(state) do
  # Restore from previous state if hot reload
  state = maybe_restore_state(state)
  {:ok, state}
end
```

### Crash Recovery

If a plugin crashes, its last known state is preserved and restored on restart.
The ETS-backed storage ensures state survives individual plugin failures.

## Performance

### Monitoring

Plugin System v2.0 tracks:
- CPU usage per plugin
- Memory usage
- Event processing time
- Command execution time

### Best Practices

- Keep `filter_event/2` fast (< 1ms)
- Use async for slow operations
- Cache expensive computations
- Clean up resources in `disable/1`

## Error Handling

```elixir
def handle_command(:risky_operation, _args, state) do
  case safe_operation() do
    {:ok, result} ->
      {:ok, state, result}
    {:error, reason} ->
      Logger.error("Operation failed: #{inspect(reason)}")
      {:error, reason, state}
  end
end
```

## Security Analysis

Raxol automatically analyzes plugin BEAM bytecode to detect security-sensitive operations.

### Detected Capabilities

The `BeamAnalyzer` inspects compiled modules for:

| Capability | Detected Operations |
|------------|---------------------|
| `:file_access` | `File.*`, `:file.*`, `Path.*` |
| `:network_access` | `:gen_tcp.*`, `:ssl.*`, `Req.*`, `HTTPoison.*` |
| `:code_injection` | `Code.eval_*`, `Module.create`, `:erl_eval.*` |
| `:system_commands` | `System.cmd`, `Port.open`, `:os.cmd` |

### Security Policies

Plugins are validated against configurable security policies:

```elixir
alias Raxol.Core.Runtime.Plugins.Security.CapabilityDetector

# Default policy (denies all sensitive operations)
policy = CapabilityDetector.default_policy()

# Custom policy allowing specific capabilities
policy = CapabilityDetector.create_policy([:file_access])

# Validate a plugin module
case CapabilityDetector.validate_against_policy(MyPlugin, policy) do
  :ok -> :load_plugin
  {:error, :file_access_denied} -> :reject_plugin
  {:error, :network_access_denied} -> :reject_plugin
end
```

### Capability Reports

Generate human-readable security reports:

```elixir
report = CapabilityDetector.capability_report(MyPlugin)
# Capability Report for MyPlugin
# ==================================================
#
# [X] File System Access
# [ ] Network Access
# [ ] Dynamic Code Evaluation
# [ ] System Command Execution
#
# --------------------------------------------------
# Total sensitive capabilities: 1
```

### Declaring Capabilities

Declare capabilities in your manifest to pass security validation:

```elixir
def manifest do
  %{
    name: "my-plugin",
    version: "1.0.0",
    capabilities: [:file_access],  # Must match detected capabilities
    # ...
  }
end
```

## Process Isolation

Plugin operations run under `PluginSupervisor` for crash isolation.

### Isolated Task Execution

Plugin crashes don't affect the core application:

```elixir
alias Raxol.Core.Runtime.Plugins.PluginSupervisor

# Synchronous execution with isolation
case PluginSupervisor.run_plugin_task(:my_plugin, fn ->
  risky_operation()
end) do
  {:ok, result} -> handle_result(result)
  {:error, {:crashed, reason}} -> log_crash(reason)
  {:error, {:timeout, ms}} -> log_timeout(ms)
end

# Fire and forget (async)
PluginSupervisor.async_plugin_task(:my_plugin, fn ->
  background_work()
end)
```

### Timeout Control

Set custom timeouts for slow operations:

```elixir
# Default timeout: 5000ms
PluginSupervisor.run_plugin_task(:my_plugin, fn ->
  slow_operation()
end, timeout: 10_000)
```

### Concurrent Plugin Tasks

Run multiple operations concurrently with individual failure isolation:

```elixir
results = PluginSupervisor.run_plugin_tasks_concurrent(:my_plugin, [
  fn -> fetch_data() end,
  fn -> process_config() end,
  fn -> load_cache() end
])
# => [{:ok, data}, {:ok, config}, {:ok, cache}]
# Failed tasks return {:error, reason} without affecting others
```

### Safe Callback Invocation

Call plugin callbacks with automatic export checking:

```elixir
case PluginSupervisor.call_plugin_callback(:my_plugin, MyPlugin, :on_load, []) do
  {:ok, result} -> result
  :not_exported -> :skip
  {:error, reason} -> handle_error(reason)
end
```

## Testing

See [TESTING.md](TESTING.md) for comprehensive testing guide.

### Quick Example

```elixir
defmodule MyPluginTest do
  use ExUnit.Case

  test "plugin lifecycle" do
    # Init
    {:ok, state} = MyPlugin.init(%{})

    # Enable
    {:ok, state} = MyPlugin.enable(state)
    assert state.enabled

    # Disable
    {:ok, state} = MyPlugin.disable(state)
    refute state.enabled
  end
end
```

## Examples

- [Command Palette](../../lib/raxol/plugins/examples/command_palette_plugin.ex)
- [Status Line](../../lib/raxol/plugins/examples/status_line_plugin.ex)
- [File Browser](../../lib/raxol/plugins/examples/file_browser_plugin.ex)
- [Git Integration](../../lib/raxol/plugins/examples/git_integration_plugin.ex)
- [Spotify](examples/SPOTIFY.md)

## See Also

- [TEMPLATES.md](TEMPLATES.md) - Ready-to-use plugin templates
- [TESTING.md](TESTING.md) - Testing strategies
- [README.md](README.md) - Plugin system overview

## Module Reference

- `Raxol.Core.Runtime.Plugins.Security.BeamAnalyzer` - BEAM bytecode security analysis
- `Raxol.Core.Runtime.Plugins.Security.CapabilityDetector` - Policy-based capability validation
- `Raxol.Core.Runtime.Plugins.PluginSupervisor` - Crash-isolated plugin task execution
- `Raxol.Core.Runtime.Plugins.PluginEventProcessor` - Event filtering and routing
