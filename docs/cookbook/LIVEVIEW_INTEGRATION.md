# Cookbook: LiveView Integration

Practical recipes for rendering terminals in Phoenix LiveView.

## Table of Contents

- [Basic Terminal Embedding](#basic-terminal-embedding)
- [Event Handling](#event-handling)
- [State Synchronization](#state-synchronization)
- [Multiple Terminals](#multiple-terminals)
- [Error Boundaries](#error-boundaries)
- [Performance Optimization](#performance-optimization)

---

## Basic Terminal Embedding

### Recipe: Simple Static Terminal

Display a terminal with static content.

```elixir
# lib/my_app_web/live/simple_terminal_live.ex
defmodule MyAppWeb.SimpleTerminalLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    buffer = create_welcome_screen()
    {:ok, assign(socket, buffer: buffer)}
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <h1>My Terminal App</h1>

      <.live_component
        module={Raxol.LiveView.TerminalComponent}
        id="terminal"
        buffer={@buffer}
        theme={:nord}
      />
    </div>
    """
  end

  defp create_welcome_screen do
    Buffer.create_blank_buffer(80, 24)
    |> Box.draw_box(0, 0, 80, 24, :double)
    |> Buffer.write_at(10, 10, "Welcome to My App!", %{bold: true, fg_color: :cyan})
    |> Buffer.write_at(10, 12, "Press any key to continue...")
  end
end
```

### Recipe: Periodic Updates

Update terminal content automatically.

```elixir
defmodule MyAppWeb.ClockLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(1000, self(), :tick)
    end

    {:ok, assign(socket, buffer: create_clock())}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={Raxol.LiveView.TerminalComponent}
      id="clock"
      buffer={@buffer}
      theme={:monokai}
    />
    """
  end

  def handle_info(:tick, socket) do
    {:noreply, assign(socket, buffer: create_clock())}
  end

  defp create_clock do
    time = Time.utc_now() |> Time.to_string() |> String.slice(0..7)

    Buffer.create_blank_buffer(30, 10)
    |> Box.draw_box(0, 0, 30, 10, :single)
    |> Buffer.write_at(10, 4, time, %{fg_color: :green, bold: true})
  end
end
```

---

## Event Handling

### Recipe: Keyboard Input

Handle keyboard events.

```elixir
defmodule MyAppWeb.KeyboardLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    socket = assign(socket,
      buffer: create_buffer(),
      last_key: nil,
      key_count: 0
    )
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={Raxol.LiveView.TerminalComponent}
      id="keyboard"
      buffer={@buffer}
      theme={:nord}
      on_keypress={&send(self(), {:keypress, &1})}
    />
    """
  end

  def handle_info({:keypress, key}, socket) do
    socket =
      socket
      |> update(:key_count, &(&1 + 1))
      |> assign(last_key: key)
      |> update_buffer()

    {:noreply, socket}
  end

  defp update_buffer(socket) do
    buffer =
      create_buffer()
      |> Buffer.write_at(5, 5, "Last key: #{inspect(socket.assigns.last_key)}")
      |> Buffer.write_at(5, 7, "Total keys: #{socket.assigns.key_count}")

    assign(socket, buffer: buffer)
  end

  defp create_buffer do
    Buffer.create_blank_buffer(60, 15)
    |> Box.draw_box(0, 0, 60, 15, :single)
    |> Buffer.write_at(5, 2, "Press any key...", %{fg_color: :cyan})
  end
end
```

### Recipe: Mouse Clicks

Handle mouse click events.

```elixir
defmodule MyAppWeb.MouseLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      buffer: create_buffer(),
      clicks: []
    )}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={Raxol.LiveView.TerminalComponent}
      id="mouse"
      buffer={@buffer}
      theme={:dracula}
      on_click={fn coord -> send(self(), {:click, coord}) end}
    />
    """
  end

  def handle_info({:click, {x, y}}, socket) do
    # Add click to buffer
    char = Enum.at(["X", "O", "*", "+", "#"], rem(length(socket.assigns.clicks), 5))

    buffer = Buffer.write_at(socket.assigns.buffer, x, y, char, %{fg_color: :red})

    socket =
      socket
      |> update(:clicks, &[{x, y} | Enum.take(&1, 99)])  # Keep last 100
      |> assign(buffer: buffer)

    {:noreply, socket}
  end

  defp create_buffer do
    Buffer.create_blank_buffer(80, 24)
    |> Box.draw_box(0, 0, 80, 24, :single)
    |> Buffer.write_at(10, 2, "Click anywhere to draw!", %{fg_color: :yellow})
  end
end
```

### Recipe: Paste Support

Handle paste events.

```elixir
defmodule MyAppWeb.PasteLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      buffer: create_buffer(),
      pasted_text: ""
    )}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={Raxol.LiveView.TerminalComponent}
      id="paste"
      buffer={@buffer}
      theme={:solarized_dark}
      on_paste={fn text -> send(self(), {:paste, text}) end}
    />
    """
  end

  def handle_info({:paste, text}, socket) do
    buffer =
      create_buffer()
      |> Buffer.write_at(5, 5, "Pasted: #{String.slice(text, 0..40)}")

    {:noreply, assign(socket, buffer: buffer, pasted_text: text)}
  end

  defp create_buffer do
    Buffer.create_blank_buffer(70, 20)
    |> Box.draw_box(0, 0, 70, 20, :rounded)
    |> Buffer.write_at(5, 2, "Try pasting text (Ctrl+V / Cmd+V)", %{fg_color: :cyan})
  end
end
```

---

## State Synchronization

### Recipe: Two-Way Data Binding

Keep socket state in sync with terminal display.

```elixir
defmodule MyAppWeb.CounterLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      buffer: Buffer.create_blank_buffer(40, 15),
      count: 0
    )
    |> update_display()}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.live_component
        module={Raxol.LiveView.TerminalComponent}
        id="counter"
        buffer={@buffer}
        theme={:nord}
        on_keypress={&send(self(), {:key, &1})}
      />

      <div class="controls">
        <button phx-click="increment">Increment</button>
        <button phx-click="decrement">Decrement</button>
        <button phx-click="reset">Reset</button>
      </div>
    </div>
    """
  end

  def handle_event("increment", _, socket) do
    {:noreply, socket |> update(:count, &(&1 + 1)) |> update_display()}
  end

  def handle_event("decrement", _, socket) do
    {:noreply, socket |> update(:count, &(&1 - 1)) |> update_display()}
  end

  def handle_event("reset", _, socket) do
    {:noreply, socket |> assign(count: 0) |> update_display()}
  end

  def handle_info({:key, "+"}, socket) do
    handle_event("increment", nil, socket)
  end

  def handle_info({:key, "-"}, socket) do
    handle_event("decrement", nil, socket)
  end

  def handle_info({:key, "r"}, socket) do
    handle_event("reset", nil, socket)
  end

  def handle_info({:key, _}, socket) do
    {:noreply, socket}
  end

  defp update_display(socket) do
    buffer =
      Buffer.create_blank_buffer(40, 15)
      |> Box.draw_box(0, 0, 40, 15, :double)
      |> Buffer.write_at(5, 3, "Counter", %{bold: true, fg_color: :cyan})
      |> Buffer.write_at(5, 6, "Count: #{socket.assigns.count}", %{fg_color: :green})
      |> Buffer.write_at(5, 9, "Press + or - to change")
      |> Buffer.write_at(5, 10, "Press r to reset")

    assign(socket, buffer: buffer)
  end
end
```

### Recipe: External State Changes

Synchronize with external processes.

```elixir
defmodule MyAppWeb.MonitorLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    # Subscribe to external updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "system:stats")
    end

    {:ok, assign(socket,
      buffer: create_buffer(),
      stats: %{cpu: 0, memory: 0, disk: 0}
    )}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={Raxol.LiveView.TerminalComponent}
      id="monitor"
      buffer={@buffer}
      theme={:monokai}
    />
    """
  end

  def handle_info({:stats_updated, stats}, socket) do
    buffer = create_buffer()
      |> Buffer.write_at(5, 5, "CPU: #{stats.cpu}%", cpu_color(stats.cpu))
      |> Buffer.write_at(5, 7, "Memory: #{stats.memory}%", memory_color(stats.memory))
      |> Buffer.write_at(5, 9, "Disk: #{stats.disk}%", disk_color(stats.disk))

    {:noreply, assign(socket, buffer: buffer, stats: stats)}
  end

  defp create_buffer do
    Buffer.create_blank_buffer(50, 20)
    |> Box.draw_box(0, 0, 50, 20, :double)
    |> Buffer.write_at(5, 2, "System Monitor", %{bold: true, fg_color: :cyan})
  end

  defp cpu_color(cpu) when cpu > 80, do: %{fg_color: :red, bold: true}
  defp cpu_color(cpu) when cpu > 50, do: %{fg_color: :yellow}
  defp cpu_color(_), do: %{fg_color: :green}

  defp memory_color(mem) when mem > 90, do: %{fg_color: :red, bold: true}
  defp memory_color(mem) when mem > 70, do: %{fg_color: :yellow}
  defp memory_color(_), do: %{fg_color: :green}

  defp disk_color(disk) when disk > 95, do: %{fg_color: :red, bold: true}
  defp disk_color(disk) when disk > 80, do: %{fg_color: :yellow}
  defp disk_color(_), do: %{fg_color: :green}
end
```

---

## Multiple Terminals

### Recipe: Split Screen

Display multiple terminals side-by-side.

```elixir
defmodule MyAppWeb.SplitScreenLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      left_buffer: create_left_panel(),
      right_buffer: create_right_panel()
    )}
  end

  def render(assigns) do
    ~H"""
    <div class="split-screen">
      <div class="left-panel">
        <.live_component
          module={Raxol.LiveView.TerminalComponent}
          id="left-terminal"
          buffer={@left_buffer}
          theme={:nord}
          on_keypress={fn k -> send(self(), {:left_key, k}) end}
        />
      </div>

      <div class="right-panel">
        <.live_component
          module={Raxol.LiveView.TerminalComponent}
          id="right-terminal"
          buffer={@right_buffer}
          theme={:dracula}
          on_keypress={fn k -> send(self(), {:right_key, k}) end}
        />
      </div>
    </div>
    """
  end

  def handle_info({:left_key, key}, socket) do
    buffer = Buffer.write_at(
      socket.assigns.left_buffer,
      5, 10,
      "Left key: #{key}    "
    )
    {:noreply, assign(socket, left_buffer: buffer)}
  end

  def handle_info({:right_key, key}, socket) do
    buffer = Buffer.write_at(
      socket.assigns.right_buffer,
      5, 10,
      "Right key: #{key}    "
    )
    {:noreply, assign(socket, right_buffer: buffer)}
  end

  defp create_left_panel do
    Buffer.create_blank_buffer(40, 24)
    |> Box.draw_box(0, 0, 40, 24, :single)
    |> Buffer.write_at(5, 2, "Left Panel", %{bold: true})
  end

  defp create_right_panel do
    Buffer.create_blank_buffer(40, 24)
    |> Box.draw_box(0, 0, 40, 24, :single)
    |> Buffer.write_at(5, 2, "Right Panel", %{bold: true})
  end
end
```

---

## Error Boundaries

### Recipe: Graceful Error Handling

Catch rendering errors without crashing.

```elixir
defmodule MyAppWeb.SafeTerminalLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}
  require Logger

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      buffer: create_buffer(),
      error: nil
    )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= if @error do %>
        <div class="alert alert-danger">
          Error: <%= @error %>
        </div>
      <% end %>

      <.live_component
        module={Raxol.LiveView.TerminalComponent}
        id="safe-terminal"
        buffer={@buffer}
        theme={:nord}
        on_keypress={&send(self(), {:key, &1})}
      />
    </div>
    """
  end

  def handle_info({:key, key}, socket) do
    case safe_update(socket, key) do
      {:ok, buffer} ->
        {:noreply, assign(socket, buffer: buffer, error: nil)}

      {:error, reason} ->
        Logger.error("Buffer update failed: #{inspect(reason)}")
        {:noreply, assign(socket, error: "Failed to process key: #{reason}")}
    end
  end

  defp safe_update(socket, key) do
    try do
      buffer = Buffer.write_at(
        socket.assigns.buffer,
        5, 10,
        "Last key: #{key}"
      )
      {:ok, buffer}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp create_buffer do
    Buffer.create_blank_buffer(60, 20)
    |> Box.draw_box(0, 0, 60, 20, :double)
    |> Buffer.write_at(5, 5, "Safe terminal with error handling", %{fg_color: :cyan})
  end
end
```

---

## Performance Optimization

### Recipe: Diff Rendering

Only update changed parts of the buffer.

```elixir
defmodule MyAppWeb.OptimizedLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box, Renderer}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(100, self(), :tick)  # 10fps updates
    end

    initial = create_buffer(0)

    {:ok, assign(socket,
      buffer: initial,
      previous_buffer: initial,
      frame: 0
    )}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={Raxol.LiveView.TerminalComponent}
      id="optimized"
      buffer={@buffer}
      theme={:nord}
    />
    """
  end

  def handle_info(:tick, socket) do
    frame = socket.assigns.frame + 1
    new_buffer = create_buffer(frame)

    # Only send diff to client (automatic in TerminalComponent)
    # But you can manually calculate if needed:
    # diff = Renderer.render_diff(socket.assigns.previous_buffer, new_buffer)

    {:noreply, assign(socket,
      buffer: new_buffer,
      previous_buffer: socket.assigns.buffer,
      frame: frame
    )}
  end

  defp create_buffer(frame) do
    # Create a simple animation
    x = rem(frame, 70) + 5
    y = rem(div(frame, 70), 20) + 2

    Buffer.create_blank_buffer(80, 24)
    |> Box.draw_box(0, 0, 80, 24, :single)
    |> Buffer.write_at(x, y, "*", %{fg_color: :cyan})
  end
end
```

### Recipe: Debounced Updates

Avoid excessive re-renders.

```elixir
defmodule MyAppWeb.DebouncedLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  @debounce_ms 300

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      buffer: create_buffer(""),
      input: "",
      timer_ref: nil
    )}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={Raxol.LiveView.TerminalComponent}
      id="debounced"
      buffer={@buffer}
      theme={:nord}
      on_keypress={fn k -> send(self(), {:key, k}) end}
    />
    """
  end

  def handle_info({:key, key}, socket) do
    # Cancel previous timer
    if socket.assigns.timer_ref do
      Process.cancel_timer(socket.assigns.timer_ref)
    end

    # Update input
    new_input = socket.assigns.input <> key

    # Schedule update
    timer_ref = Process.send_after(self(), :update_buffer, @debounce_ms)

    {:noreply, assign(socket, input: new_input, timer_ref: timer_ref)}
  end

  def handle_info(:update_buffer, socket) do
    buffer = create_buffer(socket.assigns.input)
    {:noreply, assign(socket, buffer: buffer, timer_ref: nil)}
  end

  defp create_buffer(text) do
    Buffer.create_blank_buffer(60, 15)
    |> Box.draw_box(0, 0, 60, 15, :single)
    |> Buffer.write_at(5, 5, "Input: #{text}", %{fg_color: :green})
    |> Buffer.write_at(5, 7, "(Debounced by #{@debounce_ms}ms)", %{fg_color: :gray})
  end
end
```

---

## CSS Customization

Add custom styles to your layout.

```css
/* app.css */

/* Split screen layout */
.split-screen {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  height: 600px;
}

.left-panel,
.right-panel {
  height: 100%;
}

/* Terminal container */
.terminal-container {
  background: #1e1e1e;
  border-radius: 8px;
  padding: 1rem;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

/* Error alert */
.alert {
  padding: 1rem;
  margin-bottom: 1rem;
  border-radius: 4px;
}

.alert-danger {
  background: #ff4444;
  color: white;
}
```

---

## Next Steps

- **[Performance Cookbook](./PERFORMANCE_OPTIMIZATION.md)** - Advanced optimization techniques
- **[Theming Cookbook](./THEMING.md)** - Custom themes and styling
- **[API Reference](../core/BUFFER_API.md)** - Complete function documentation

---

**Happy coding!** Share your recipes by opening a PR.
