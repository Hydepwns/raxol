# Plugin Development Guide

How to build Raxol plugins with lifecycle management, event filtering, and process isolation.

## Quick Start

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
Discovery -> Loading -> Starting -> Running -> Stopping -> Stopped -> Terminated
             | init    | enable              | disable              | terminate
```

### Loading Phase (init/1)

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

### Starting Phase (enable/1)

```elixir
@impl true
def enable(state) do
  timer = :timer.send_interval(5000, :refresh)
  new_state = %{state | timers: [timer]}
  {:ok, new_state}
end
```

### Stopping Phase (disable/1)

```elixir
@impl true
def disable(state) do
  Enum.each(state.timers, &:timer.cancel/1)
  {:ok, %{state | timers: []}}
end
```

### Termination (terminate/2)

```elixir
@impl true
def terminate(_reason, state) do
  # Final cleanup
  :ok
end
```

## Plugin Manifest

```elixir
def manifest do
  %{
    # Required
    name: "unique-name",              # Kebab-case
    version: "1.0.0",                 # Semantic versioning
    description: "What it does",
    author: "Your Name",

    # Dependencies
    dependencies: %{
      "raxol-core" => "~> 1.5",
      "other-plugin" => "~> 2.0"
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
        default: "value",
        description: "Purpose",
        required: false,
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
System Event -> filter_event/2 (priority order) -> Core Processing
                     |
              Can modify, pass through, or halt
```

### Event Filtering

Implement `filter_event/2` to intercept, modify, or block events:

```elixir
# Block events (stops propagation)
def filter_event({:key_press, "F12"}, _state), do: :halt

# Modify events
def filter_event({:key_press, "j"}, _state) do
  {:ok, {:key_press, :arrow_down}}
end

# Pass through unchanged
def filter_event(event, _state), do: {:ok, event}
```

### Command Handling

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

### Plugin Priority

Control event processing order with `priority` in the manifest:

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

Plugins without explicit priority default to `1000`.

Dependencies are automatically sorted -- dependent plugins see events after their dependencies have processed them.

### Error Handling in Filters

Filter errors are logged but don't stop event propagation. Filters run under `PluginSupervisor` with a 1-second timeout by default. If a filter crashes, the event passes through to the next plugin.

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
capabilities: [:keyboard_input]

def filter_event({:key_press, hotkey}, state) when hotkey == state.config.hotkey do
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
  {:ok, {:file_changed, path}}
end
```

## State Management

Plugin state is managed through an ETS-backed `StateManager` for concurrent access and crash recovery. Each plugin's state is isolated. State updates from `handle_event/2` are automatically persisted.

State persists across hot reloads. If a plugin crashes, its last known state is preserved and restored on restart.

## Security Analysis

Raxol automatically analyzes plugin BEAM bytecode to detect security-sensitive operations.

### Detected Capabilities

| Capability | Detected Operations |
|------------|---------------------|
| `:file_access` | `File.*`, `:file.*`, `Path.*` |
| `:network_access` | `:gen_tcp.*`, `:ssl.*`, `Req.*`, `HTTPoison.*` |
| `:code_injection` | `Code.eval_*`, `Module.create`, `:erl_eval.*` |
| `:system_commands` | `System.cmd`, `Port.open`, `:os.cmd` |

### Security Policies

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

Declare capabilities in your manifest to pass validation -- they must match what the bytecode analyzer detects.

## Process Isolation

Plugin operations run under `PluginSupervisor` for crash isolation. Plugin crashes don't affect the core application.

```elixir
alias Raxol.Core.Runtime.Plugins.PluginSupervisor

# Synchronous with isolation
case PluginSupervisor.run_plugin_task(:my_plugin, fn ->
  risky_operation()
end) do
  {:ok, result} -> handle_result(result)
  {:error, {:crashed, reason}} -> log_crash(reason)
  {:error, {:timeout, ms}} -> log_timeout(ms)
end

# Fire and forget
PluginSupervisor.async_plugin_task(:my_plugin, fn ->
  background_work()
end)

# Concurrent tasks with individual failure isolation
results = PluginSupervisor.run_plugin_tasks_concurrent(:my_plugin, [
  fn -> fetch_data() end,
  fn -> process_config() end,
  fn -> load_cache() end
])
# => [{:ok, data}, {:ok, config}, {:ok, cache}]
```

Custom timeouts: `PluginSupervisor.run_plugin_task(:my_plugin, fun, timeout: 10_000)`

## Testing

See [TESTING.md](TESTING.md) for the full testing guide.

```elixir
defmodule MyPluginTest do
  use ExUnit.Case

  test "plugin lifecycle" do
    {:ok, state} = MyPlugin.init(%{})
    {:ok, state} = MyPlugin.enable(state)
    assert state.enabled
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
