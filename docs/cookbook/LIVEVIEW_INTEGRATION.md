# LiveView Integration

Recipes for rendering terminals in Phoenix LiveView.

## Basic Terminal Embedding

### Static Terminal

```elixir
defmodule MyAppWeb.SimpleTerminalLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    buffer =
      Buffer.create_blank_buffer(80, 24)
      |> Box.draw_box(0, 0, 80, 24, :double)
      |> Buffer.write_at(10, 10, "Welcome to My App!", %{bold: true, fg_color: :cyan})
      |> Buffer.write_at(10, 12, "Press any key to continue...")

    {:ok, assign(socket, buffer: buffer)}
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <.live_component
        module={Raxol.LiveView.TerminalComponent}
        id="terminal"
        buffer={@buffer}
        theme={:nord}
      />
    </div>
    """
  end
end
```

### Periodic Updates

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

### Keyboard Input

```elixir
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
```

### Mouse Clicks

```elixir
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
  buffer = Buffer.write_at(socket.assigns.buffer, x, y, "X", %{fg_color: :red})
  {:noreply, assign(socket, buffer: buffer)}
end
```

### Paste Support

```elixir
<.live_component
  module={Raxol.LiveView.TerminalComponent}
  id="paste"
  buffer={@buffer}
  theme={:solarized_dark}
  on_paste={fn text -> send(self(), {:paste, text}) end}
/>
```

---

## State Synchronization

### Two-Way Data Binding

Keep socket state in sync with terminal display:

```elixir
defmodule MyAppWeb.CounterLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, buffer: Buffer.create_blank_buffer(40, 15), count: 0)
    |> update_display()}
  end

  def handle_event("increment", _, socket) do
    {:noreply, socket |> update(:count, &(&1 + 1)) |> update_display()}
  end

  def handle_info({:key, "+"}, socket) do
    handle_event("increment", nil, socket)
  end

  defp update_display(socket) do
    buffer =
      Buffer.create_blank_buffer(40, 15)
      |> Box.draw_box(0, 0, 40, 15, :double)
      |> Buffer.write_at(5, 6, "Count: #{socket.assigns.count}", %{fg_color: :green})

    assign(socket, buffer: buffer)
  end
end
```

### External State Changes

Subscribe to PubSub for external updates:

```elixir
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, "system:stats")
  end

  {:ok, assign(socket, buffer: create_buffer(), stats: %{cpu: 0, memory: 0})}
end

def handle_info({:stats_updated, stats}, socket) do
  buffer =
    create_buffer()
    |> Buffer.write_at(5, 5, "CPU: #{stats.cpu}%", cpu_color(stats.cpu))
    |> Buffer.write_at(5, 7, "Memory: #{stats.memory}%", memory_color(stats.memory))

  {:noreply, assign(socket, buffer: buffer, stats: stats)}
end

defp cpu_color(cpu) when cpu > 80, do: %{fg_color: :red, bold: true}
defp cpu_color(cpu) when cpu > 50, do: %{fg_color: :yellow}
defp cpu_color(_), do: %{fg_color: :green}
```

---

## Multiple Terminals

### Split Screen

```elixir
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
```

---

## Error Boundaries

Catch rendering errors without crashing:

```elixir
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
    {:ok, Buffer.write_at(socket.assigns.buffer, 5, 10, "Last key: #{key}")}
  rescue
    e -> {:error, Exception.message(e)}
  end
end
```

---

## Performance: Diff Rendering

Only update changed parts of the buffer. The TerminalComponent handles this automatically, but you can also calculate diffs manually:

```elixir
def handle_info(:tick, socket) do
  frame = socket.assigns.frame + 1
  new_buffer = create_buffer(frame)

  {:noreply, assign(socket,
    buffer: new_buffer,
    previous_buffer: socket.assigns.buffer,
    frame: frame
  )}
end
```

### Debounced Updates

Avoid excessive re-renders:

```elixir
@debounce_ms 300

def handle_info({:key, key}, socket) do
  if socket.assigns.timer_ref do
    Process.cancel_timer(socket.assigns.timer_ref)
  end

  new_input = socket.assigns.input <> key
  timer_ref = Process.send_after(self(), :update_buffer, @debounce_ms)

  {:noreply, assign(socket, input: new_input, timer_ref: timer_ref)}
end

def handle_info(:update_buffer, socket) do
  {:noreply, assign(socket, buffer: create_buffer(socket.assigns.input), timer_ref: nil)}
end
```

---

## CSS Customization

```css
.split-screen {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  height: 600px;
}

.terminal-container {
  background: #1e1e1e;
  border-radius: 8px;
  padding: 1rem;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}
```

---

## Next Steps

- [Performance Cookbook](./PERFORMANCE_OPTIMIZATION.md)
- [Theming Cookbook](./THEMING.md)
- [API Reference](../core/BUFFER_API.md)
