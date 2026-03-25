# Architecture

How Raxol works, from application model to terminal output.

## The Big Picture

```
Your App (TEA)          Raxol Framework              Terminal
┌─────────────┐    ┌──────────────────────┐    ┌─────────────┐
│ init/1       │    │ Lifecycle (GenServer) │    │ termbox2 NIF│
│ update/2     │───>│ Rendering Engine      │───>│ or          │
│ view/1       │    │ Layout Engine         │    │ IOTerminal  │
│ subscribe/1  │    │ Event Dispatcher      │    │ or          │
└─────────────┘    └──────────────────────┘    │ LiveView    │
                                                └─────────────┘
```

Your app provides pure functions. Raxol manages the runtime loop, layout, rendering, and I/O. You never write ANSI escape codes.

## Application Model: TEA

Every Raxol app implements The Elm Architecture:

```elixir
use Raxol.Core.Runtime.Application

def init(context) -> model                    # Initial state
def update(message, model) -> {model, cmds}   # State transitions
def view(model) -> view_tree                  # Declarative UI
def subscribe(model) -> [subscription]        # External events
```

The runtime calls `view(model)` after every `update`, diffs the result against the previous view tree, and renders only what changed. This is the same virtual DOM idea from React, but for terminals.

## Layer Stack

### 1. View DSL -> Element Tree

The `view/1` callback uses macros to build a tree of plain maps:

```elixir
column style: %{padding: 1} do
  [
    text("Hello", fg: :cyan),
    row do
      [button("+", on_click: :inc), button("-", on_click: :dec)]
    end
  ]
end
```

Produces: `%{type: :column, children: [%{type: :text, ...}, %{type: :row, ...}], ...}`

### 2. Layout Engine -> Positioned Elements

`Raxol.UI.Layout.Engine` takes the element tree and computes `{x, y, width, height}` for every node. Supports:

- **Flexbox**: `row`/`column` with `flex`, `gap`, `align_items`, `justify_content`
- **CSS Grid**: `grid` with `template_columns`, `template_rows`
- **Box model**: `padding`, `border`, `margin`, `width`, `height`

### 3. UIRenderer -> Cell Grid

`Raxol.UI.UIRenderer` walks the positioned tree and produces cell tuples:

```elixir
{x, y, char, fg_color, bg_color, attrs}
```

Each cell is one character at one position with its styling.

### 4. Screen Buffer -> Diff

`Raxol.Terminal.ScreenBuffer` holds the current and previous frame. Only changed cells produce output.

### 5. Terminal Backend -> Output

Platform-detected backend writes ANSI escape sequences:

- **Unix/macOS**: Native C NIF via termbox2 (`lib/termbox2_nif/c_src/`)
- **Windows**: Pure Elixir `IOTerminal` using `IO.write/1`
- **Browser**: LiveView bridge via PubSub (`Raxol.LiveView.TEALive`)
- **SSH**: Erlang `:ssh` module (`Raxol.SSH.Server`)

## Event Flow

```
Terminal Input
  -> Driver (raw bytes -> Event struct)
  -> Dispatcher (GenServer)
  -> Capture phase (root -> target, W3C-style)
  -> Target handlers (on_click, on_change)
  -> Bubble phase (target -> root)
  -> Component handle_event/3
  -> App update/2
```

Events bubble through the view tree. Any handler can return `:stop` to halt propagation or `:passthrough` to continue. Unhandled events reach `update/2`.

## OTP Architecture

Every Raxol app runs as a supervision tree:

```
Application Supervisor
├── Lifecycle (GenServer) -- owns the TEA loop
├── Dispatcher (GenServer) -- event routing
├── FocusManager (GenServer) -- tab order, focus state
├── Rendering.Engine -- view -> layout -> render -> output
├── ThemeManager -- ETS-backed theme registry
├── I18nServer -- ETS-backed translations
└── [ProcessComponent supervisors] -- optional per-widget processes
```

### Process-Per-Component (Optional)

Any widget can run in its own process via `process_component/2`:

```elixir
process_component(ExpensiveChart, data: sensor_feed)
```

The component gets its own GenServer under a DynamicSupervisor. If it crashes, it restarts without affecting the rest of the UI. State is preserved in ETS across restarts.

### Hot Code Reload (Dev Only)

`Raxol.Dev.CodeReloader` watches `.ex` files via FileSystem, debounces changes, recompiles, and sends `:render_needed` to the Lifecycle. Your app updates in-place without restart.

## Performance Design

- **Buffer diff**: Only changed cells are written. ~2ms for 80x24.
- **ETS for reads**: Theme, i18n, config, and metrics use ETS tables. Reads bypass GenServer serialization entirely.
- **Synchronized output**: Uses DEC mode 2026 (`\e[?2026h`) to batch terminal writes, preventing flicker.
- **Damage tracking**: `DamageTracker` computes rectangular dirty regions. `RenderBatcher` coalesces rapid updates into single frames at 60fps.
- **Color downsampling**: `Raxol.Core.ColorSystem.Adaptive` detects terminal capabilities and maps 24-bit colors to 256 or 16 colors automatically.

## Terminal Compatibility

- **Unicode width**: `Raxol.Terminal.Emulator.CharWidth` handles double-width CJK, combining characters, emoji
- **Border fallback**: Box drawing uses ASCII (`+-|`) when Unicode isn't supported
- **Color detection**: `COLORTERM`, `TERM`, capability queries for truecolor/256/16/mono

## Key Modules

| Module | Role |
|--------|------|
| `Raxol.Core.Runtime.Lifecycle` | TEA loop GenServer |
| `Raxol.Core.Runtime.Events.Dispatcher` | Event routing + bubbling |
| `Raxol.Core.Runtime.Rendering.Engine` | view -> layout -> render |
| `Raxol.UI.Layout.Engine` | Flexbox/Grid layout computation |
| `Raxol.UI.UIRenderer` | Element tree -> cell grid |
| `Raxol.Terminal.ScreenBuffer` | Double-buffered cell storage |
| `Raxol.Terminal.Renderer` | Cell grid -> ANSI string |
| `Raxol.Terminal.Driver` | Platform backend selection |
| `Raxol.Core.Renderer.View` | View DSL macros |

## References

- [Buffer API](./BUFFER_API.md)
- [Quickstart Guide](../getting-started/QUICKSTART.md)
- [Widget Gallery](../getting-started/WIDGET_GALLERY.md)
- [Theming Cookbook](../cookbook/THEMING.md)
