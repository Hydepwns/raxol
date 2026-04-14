# `Raxol.Terminal.Integration.State`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/integration/integration_state.ex#L1)

Manages the state of the integrated terminal system.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Integration.State{
  buffer: any(),
  buffer_manager: Raxol.Terminal.Window.Manager.t() | nil | map(),
  config: Raxol.Terminal.Integration.Config.t() | nil | map(),
  cursor_manager: any(),
  height: integer(),
  input: any(),
  io: Raxol.Terminal.IO.IOServer.t() | nil,
  output: any(),
  renderer: Raxol.Terminal.Rendering.RenderServer.t() | nil | map(),
  scroll_buffer: Raxol.Terminal.Buffer.Scroll.t() | nil,
  width: integer(),
  window: any(),
  window_manager: module() | nil
}
```

# `cleanup`

Cleans up resources.

# `get_memory_usage`

Gets the current memory usage.

# `get_scroll_position`

Gets the current scroll position.

# `get_visible_content`

Gets the visible content from the current window.

# `new`

Creates a new integration state with the given options.

# `new`

Creates a new integration state with specified width, height, and config.

# `render`

Renders the current state.

# `resize`

Resizes the terminal.

# `update`

Updates the integration state with new content.

# `update_renderer_config`

Updates the renderer configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
