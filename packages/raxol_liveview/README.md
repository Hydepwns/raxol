# Raxol LiveView

Phoenix LiveView integration for Raxol terminals.

## Install

```elixir
{:raxol_core, "~> 2.0"},
{:raxol_liveview, "~> 2.0"}
```

## Quick Start

```elixir
defmodule MyAppWeb.TerminalLive do
  use Phoenix.LiveView
  alias Raxol.LiveView.TerminalBridge

  def mount(_params, _session, socket) do
    buffer = create_buffer()
    {:ok, assign(socket, buffer: buffer)}
  end

  def render(assigns) do
    ~H"""
    <div class="raxol-terminal raxol-theme-nord">
      <%= raw(TerminalBridge.buffer_to_html(@buffer)) %>
    </div>
    """
  end
end
```

## Core APIs

### TerminalBridge
- `buffer_to_html(buffer)` - Convert buffer to HTML
- `buffer_diff_to_html(old, new, opts)` - Efficient diff rendering
- `style_to_classes(style)` - CSS class names
- `style_to_inline(style)` - Inline styles

### TerminalComponent
LiveComponent with keyboard/mouse events, themes, cursor styles.

## Built-in Themes

- Nord
- Dracula
- Solarized Dark/Light
- Monokai

Set via CSS class: `raxol-theme-nord`

## Assets

Include in `assets/js/app.js`:
```javascript
import {RaxolTerminal} from "../../deps/raxol_liveview/priv/static/js/raxol_terminal_hooks"
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: {RaxolTerminal}
})
```

Include CSS in `assets/css/app.css`:
```css
@import "../../deps/raxol_liveview/priv/static/css/raxol_terminal.css";
```

## Performance

- Render: ~1.24ms average
- Diff rendering: 50x faster than full render
- 60fps capable

See [LiveView cookbook](../../docs/cookbook/LIVEVIEW_INTEGRATION.md) for patterns.
