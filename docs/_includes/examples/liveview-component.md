## LiveView Terminal Component

```elixir
defmodule MyAppWeb.TerminalLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    buffer = Buffer.create_blank_buffer(80, 24)
    buffer = Box.draw_box(buffer, 0, 0, 80, 24, :rounded)
    buffer = Buffer.write_at(buffer, 10, 10, "Hello from LiveView!")

    {:ok, assign(socket, buffer: buffer)}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={Raxol.LiveView.TerminalComponent}
      id="terminal"
      buffer={@buffer}
      theme={:nord}
    />
    """
  end
end
```
