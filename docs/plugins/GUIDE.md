# Plugin Development Guide

> [Documentation](../README.md) > [Plugins](README.md) > Guide

Complete guide to developing Raxol plugins with lifecycle management.

**Version**: v1.6.0 | **Target**: Plugin developers | **Level**: Intermediate

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
- Security check

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
System Event → filter_event/2 (each plugin) → Core Processing
```

### Event Filtering

```elixir
# Block events
def filter_event({:key_press, "F12"}, _state), do: :halt

# Modify events
def filter_event({:key_press, "j"}, state) do
  {:ok, {:key_press, :arrow_down}}
end

# Pass through
def filter_event(event, _state), do: {:ok, event}
```

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

### Hot Reload

State persists across hot reloads:

```elixir
def enable(state) do
  # Restore from previous state if hot reload
  state = maybe_restore_state(state)
  {:ok, state}
end
```

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
