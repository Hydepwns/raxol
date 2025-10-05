# Raxol Plugin Examples

This directory contains examples of Raxol plugins - self-contained components that extend terminal functionality.

## What is a Raxol Plugin?

A Raxol plugin is a module that implements the `Raxol.Plugin` behavior:

```elixir
defmodule MyPlugin do
  @behaviour Raxol.Plugin

  @impl true
  def init(opts), do: {:ok, %{}}

  @impl true
  def handle_input(key, modifiers, state), do: {:ok, state}

  @impl true
  def render(buffer, state), do: buffer

  @impl true
  def cleanup(state), do: :ok
end
```

Plugins provide:
- **State management** - Encapsulated plugin state
- **Input handling** - Keyboard and mouse events
- **Rendering** - Buffer-based UI rendering
- **Lifecycle hooks** - Init and cleanup

## Available Plugin Examples

### [Spotify](./spotify/)

Control Spotify playback from your terminal with full OAuth integration.

**Features:**
- View currently playing track
- Playback controls (play/pause/next/previous)
- Browse and play playlists
- Device switching
- Search functionality

**Examples:**
- `01_simple_playback.exs` - Basic play/pause control
- `02_playlist_browser.exs` - Browse and play playlists
- `03_api_usage.exs` - Direct API usage
- `04_custom_integration.exs` - Embed in custom terminal

[View Spotify examples →](./spotify/)

## Core Plugin Examples

### Counter Plugin (Basic State)

```elixir
defmodule CounterPlugin do
  @behaviour Raxol.Plugin
  alias Raxol.Core.Buffer

  def init(_opts), do: {:ok, %{count: 0}}

  def handle_input(" ", _mods, state), do: {:ok, %{state | count: state.count + 1}}
  def handle_input("r", _mods, state), do: {:ok, %{state | count: 0}}
  def handle_input("q", _mods, state), do: {:exit, state}
  def handle_input(_, _, state), do: {:ok, state}

  def render(buffer, state) do
    buffer
    |> Buffer.write_at(0, 0, "Counter: #{state.count}")
    |> Buffer.write_at(0, 1, "[SPACE: +1 | R: reset | Q: quit]")
  end

  def cleanup(_state), do: :ok
end

Raxol.Plugin.run(CounterPlugin)
```

### TODO List (Lists & Navigation)

```elixir
defmodule TodoPlugin do
  @behaviour Raxol.Plugin
  alias Raxol.Core.{Buffer, Box}

  def init(_) do
    {:ok, %{items: [], input: "", mode: :list, selected: 0}}
  end

  def handle_input(key, _mods, %{mode: :list} = state) do
    case key do
      :up -> {:ok, %{state | selected: max(state.selected - 1, 0)}}
      :down -> {:ok, %{state | selected: min(state.selected + 1, length(state.items) - 1)}}
      "i" -> {:ok, %{state | mode: :insert}}
      "x" -> {:ok, %{state | items: List.delete_at(state.items, state.selected)}}
      "q" -> {:exit, state}
      _ -> {:ok, state}
    end
  end

  def handle_input(key, _mods, %{mode: :insert} = state) do
    cond do
      key == :escape ->
        {:ok, %{state | mode: :list, input: ""}}

      key == :enter ->
        items = state.items ++ [state.input]
        {:ok, %{state | items: items, input: "", mode: :list}}

      key == :backspace ->
        {:ok, %{state | input: String.slice(state.input, 0..-2//1)}}

      String.length(key) == 1 ->
        {:ok, %{state | input: state.input <> key}}

      true ->
        {:ok, state}
    end
  end

  def render(buffer, state) do
    buffer = Box.draw_box(buffer, 0, 0, buffer.width, buffer.height, :double)
    buffer = Buffer.write_at(buffer, 2, 0, " TODO List ", %{bold: true})

    buffer = if state.mode == :insert do
      buffer
      |> Buffer.write_at(2, 2, "Add item: #{state.input}_", %{fg_color: :green})
      |> Buffer.write_at(2, buffer.height - 2, "[ENTER: save | ESC: cancel]")
    else
      buffer
      |> render_items(state.items, state.selected, 2)
      |> Buffer.write_at(2, buffer.height - 2, "[I: add | X: delete | Q: quit]")
    end

    buffer
  end

  defp render_items(buffer, items, selected, start_y) do
    items
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {item, idx}, buf ->
      style = if idx == selected do
        %{bg_color: :blue, fg_color: :white}
      else
        %{}
      end

      prefix = if idx == selected, do: "> ", else: "  "
      Buffer.write_at(buf, 2, start_y + idx, "#{prefix}#{item}", style)
    end)
  end

  def cleanup(_), do: :ok
end
```

## Building Your Own Plugin

### 1. Create Plugin Module

```elixir
defmodule MyApp.MyPlugin do
  @behaviour Raxol.Plugin

  alias Raxol.Core.Buffer

  @impl true
  def init(opts) do
    # Initialize your state
    {:ok, %{}}
  end

  @impl true
  def handle_input(key, modifiers, state) do
    # Handle keyboard/mouse input
    case key do
      "q" -> {:exit, state}
      _ -> {:ok, state}
    end
  end

  @impl true
  def render(buffer, state) do
    # Render to buffer
    Buffer.write_at(buffer, 0, 0, "Hello from my plugin!")
  end

  @impl true
  def cleanup(state) do
    # Cleanup resources
    :ok
  end
end
```

### 2. Run Your Plugin

```elixir
# Standalone
Raxol.Plugin.run(MyApp.MyPlugin)

# With options
Raxol.Plugin.run(MyApp.MyPlugin, width: 100, height: 40)

# In your application
{:ok, state} = MyApp.MyPlugin.init([])
# ... render loop ...
MyApp.MyPlugin.cleanup(state)
```

## Plugin Patterns

### Async Operations

```elixir
defmodule AsyncPlugin do
  @behaviour Raxol.Plugin

  def init(_opts) do
    # Schedule periodic updates
    :timer.send_interval(1000, self(), :tick)
    {:ok, %{counter: 0}}
  end

  def handle_info(:tick, state) do
    {:ok, %{state | counter: state.counter + 1}}
  end

  # Other callbacks...
end
```

### API Integration

```elixir
defmodule APIPlugin do
  def init(opts) do
    api_key = Keyword.fetch!(opts, :api_key)

    Task.async(fn ->
      fetch_data(api_key)
    end)

    {:ok, %{data: nil, loading: true}}
  end

  def handle_info({_ref, data}, state) do
    {:ok, %{state | data: data, loading: false}}
  end

  # Other callbacks...
end
```

### Multi-Mode Plugins

```elixir
defmodule MultiModePlugin do
  def handle_input(key, mods, state) do
    case state.mode do
      :main -> handle_main(key, mods, state)
      :edit -> handle_edit(key, mods, state)
      :search -> handle_search(key, mods, state)
    end
  end

  def render(buffer, state) do
    case state.mode do
      :main -> render_main(buffer, state)
      :edit -> render_edit(buffer, state)
      :search -> render_search(buffer, state)
    end
  end
end
```

## Documentation

- [Building Plugins Guide](../../docs/plugins/BUILDING_PLUGINS.md) - Complete plugin development guide
- [Spotify Plugin Guide](../../docs/plugins/SPOTIFY.md) - Detailed Spotify plugin documentation
- [Buffer API](../../docs/core/BUFFER_API.md) - Buffer rendering reference
- [Plugin Behavior](../../lib/raxol/plugin.ex) - Plugin behavior specification

## Testing Plugins

```elixir
defmodule MyPluginTest do
  use ExUnit.Case

  alias Raxol.Core.Buffer

  test "plugin initialization" do
    assert {:ok, state} = MyPlugin.init([])
    assert state.counter == 0
  end

  test "input handling" do
    state = %{counter: 0}
    modifiers = %{ctrl: false, alt: false, shift: false, meta: false}

    assert {:ok, new_state} = MyPlugin.handle_input(" ", modifiers, state)
    assert new_state.counter == 1
  end

  test "rendering" do
    buffer = Buffer.create_blank_buffer(20, 5)
    state = %{counter: 42}

    rendered = MyPlugin.render(buffer, state)
    string = Buffer.to_string(rendered)

    assert string =~ "42"
  end
end
```

## Publishing Plugins

See [Publishing Plugins](../../docs/plugins/BUILDING_PLUGINS.md#publishing-plugins) for:
- Package structure
- mix.exs configuration
- Publishing to Hex
- Documentation requirements

## Contributing

Have a cool plugin? Share it with the community:

1. Add your plugin to `lib/raxol/plugins/`
2. Create examples in `examples/plugins/your_plugin/`
3. Add documentation to `docs/plugins/`
4. Submit a PR!

## Resources

- [Plugin API Reference](https://hexdocs.pm/raxol/Raxol.Plugin.html)
- [Core Buffer API](https://hexdocs.pm/raxol/Raxol.Core.Buffer.html)
- [Component System](https://hexdocs.pm/raxol/Raxol.UI.Components.html)
