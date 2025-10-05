# Raxol Plugin

Plugin system for extensible terminal applications.

## Install

```elixir
{:raxol_core, "~> 2.0"},
{:raxol_plugin, "~> 2.0"}
```

## Quick Start

```elixir
defmodule MyPlugin do
  @behaviour Raxol.Plugin

  def init(_opts) do
    {:ok, %{count: 0}}
  end

  def handle_input(key, state) do
    case key do
      " " -> {:ok, %{state | count: state.count + 1}}
      _ -> {:ok, state}
    end
  end

  def render(state, buffer) do
    Buffer.write_at(buffer, 0, 0, "Count: #{state.count}")
  end

  def cleanup(_state), do: :ok
end
```

## Plugin Behavior

Required callbacks:
- `init(opts)` - Initialize plugin state
- `handle_input(key, state)` - Process keyboard input
- `render(state, buffer)` - Render to buffer
- `cleanup(state)` - Clean up resources

Optional:
- `handle_info(msg, state)` - Handle async messages

## Running Plugins

```elixir
# Standalone
{:ok, pid} = Raxol.Plugin.Runner.start_link(MyPlugin, [])

# In your app
def handle_event("keydown", %{"key" => key}, socket) do
  {:ok, state} = MyPlugin.handle_input(key, socket.assigns.plugin_state)
  buffer = MyPlugin.render(state, socket.assigns.buffer)
  {:noreply, assign(socket, plugin_state: state, buffer: buffer)}
end
```

## Examples

See `lib/raxol/plugins/spotify/` for a complete real-world plugin.

Docs: [Building Plugins](../../docs/plugins/BUILDING_PLUGINS.md)
