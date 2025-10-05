# Raxol LiveView

[![Hex.pm](https://img.shields.io/hexpm/v/raxol_liveview.svg)](https://hex.pm/packages/raxol_liveview)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/raxol_liveview)

Phoenix LiveView integration for Raxol terminal buffers. Render terminal UIs in the browser with real-time updates.

## Features

- **Real-time Terminal Rendering** - Convert Raxol buffers to HTML with WebSocket updates
- **60fps Performance** - Average 1.24ms rendering time
- **Full Event Handling** - Keyboard, mouse, paste, focus/blur
- **Five Built-in Themes** - Nord, Dracula, Solarized Dark/Light, Monokai
- **Accessibility** - ARIA labels, keyboard navigation, high contrast support

## Installation

Add `raxol_liveview` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:raxol_core, "~> 2.0"},
    {:raxol_liveview, "~> 2.0"}
  ]
end
```

## Quick Start

### Basic Terminal Component

```elixir
defmodule MyAppWeb.TerminalLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.Buffer
  alias Raxol.LiveView.TerminalComponent

  def mount(_params, _session, socket) do
    buffer = Buffer.create_blank_buffer(80, 24)
    buffer = Buffer.write_at(buffer, 0, 0, "Hello from LiveView!")

    {:ok, assign(socket, buffer: buffer)}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={TerminalComponent}
      id="terminal-1"
      buffer={@buffer}
      theme={:nord}
      on_keypress={&handle_keypress/1}
    />
    """
  end

  def handle_keypress(key) do
    # Handle keyboard input
    IO.puts("Key pressed: #{key}")
  end
end
```

### With Event Handling

```elixir
def render(assigns) do
  ~H"""
  <.live_component
    module={Raxol.LiveView.TerminalComponent}
    id="terminal"
    buffer={@buffer}
    theme={:dracula}
    on_keypress={fn key -> send(self(), {:key, key}) end}
    on_click={fn {x, y} -> send(self(), {:click, x, y}) end}
  />
  """
end

def handle_info({:key, key}, socket) do
  buffer = update_buffer_with_key(socket.assigns.buffer, key)
  {:noreply, assign(socket, buffer: buffer)}
end
```

## Available Themes

- `:nord` - Nord color scheme
- `:dracula` - Dracula color scheme
- `:solarized_dark` - Solarized Dark
- `:solarized_light` - Solarized Light
- `:monokai` - Monokai color scheme

## Core Modules

### `Raxol.LiveView.TerminalBridge`

Convert Raxol buffers to HTML with efficient caching and diffing.

```elixir
alias Raxol.LiveView.TerminalBridge

html = TerminalBridge.buffer_to_html(buffer, theme: :nord)
```

### `Raxol.LiveView.TerminalComponent`

LiveComponent for embedding terminals in LiveView templates.

**Props:**
- `buffer` - Raxol.Core.Buffer to render
- `theme` - Theme name (atom)
- `on_keypress` - Keyboard event handler
- `on_click` - Mouse click handler
- `on_paste` - Paste event handler

## Performance

- Average rendering: 1.24ms (well under 16ms for 60fps)
- Virtual DOM diffing for efficient updates
- Optimized HTML generation with caching
- Tested with buffers up to 200x50

## CSS Customization

Include the default styles in your `app.css`:

```css
@import "../../deps/raxol_liveview/priv/static/css/raxol_terminal.css";
```

Or customize with CSS variables:

```css
.raxol-terminal {
  --terminal-bg: #1e1e1e;
  --terminal-fg: #d4d4d4;
  --terminal-font: 'Fira Code', 'Courier New', monospace;
}
```

## Examples

Full examples available in the [main repository](https://github.com/Hydepwns/raxol/tree/master/examples/liveview):
- 01_simple_terminal - Basic LiveView integration
- Interactive REPL examples
- Real-time data visualization

## Documentation

Additional documentation in the [main repository](https://github.com/Hydepwns/raxol):
- [LiveView Integration Guide](https://github.com/Hydepwns/raxol/blob/master/docs/cookbook/LIVEVIEW_INTEGRATION.md)
- [Performance Optimization](https://github.com/Hydepwns/raxol/blob/master/docs/cookbook/PERFORMANCE_OPTIMIZATION.md)
- [Theming Guide](https://github.com/Hydepwns/raxol/blob/master/docs/cookbook/THEMING.md)

## Package Ecosystem

- **raxol_core** - Buffer primitives (required dependency)
- **raxol_liveview** (this package) - Phoenix LiveView integration
- **raxol_plugin** - Plugin system
- **raxol** - Full framework

## License

MIT License - See LICENSE file included in this package

## Contributing

Contributions welcome! Please visit the [main repository](https://github.com/Hydepwns/raxol)

## Credits

Built by [axol.io](https://axol.io) for [raxol.io](https://raxol.io)
