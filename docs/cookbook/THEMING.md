# Theming

Color schemes and styling for terminal and LiveView apps.

## Terminal Theming

### Inline colors

The View DSL accepts colors directly via `fg:` and `bg:`:

```elixir
text("Hello", fg: :cyan)                    # Named ANSI color
text("Warning", fg: :yellow, style: [:bold]) # Bold yellow
text("Custom", fg: {255, 107, 174})          # RGB tuple
text("256-color", fg: 198)                   # 256-color palette index
text("Hex color", fg: "#ff6bae")             # Hex string
```

Available named colors: `:black`, `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`.

### Color by status

Pattern match to return colors based on data:

```elixir
defp severity_color(:critical), do: :red
defp severity_color(:warning), do: :yellow
defp severity_color(:info), do: :cyan
defp severity_color(_), do: :white

# Usage:
text(message, fg: severity_color(level))
```

### Terminal capability detection

Raxol auto-detects terminal color support and downsamples:

- **Truecolor** (24-bit): RGB tuples and hex strings render exactly
- **256-color**: RGB is mapped to the nearest 256-color value
- **16-color**: Mapped to the closest ANSI color
- **Mono**: All colors stripped, styling preserved (bold, underline)

`Raxol.Core.ColorSystem.Adaptive.adapt_color_safe/1` handles this transparently.

### Synthwave '84 palette example

The flagship demo uses Synthwave '84 Soft mapped to ANSI:

```elixir
# Consistent color language across your app
defp accent, do: :cyan       # Titles, active elements
defp highlight, do: :magenta # Key hints, borders
defp warn, do: :yellow       # Warnings, headers
defp ok, do: :green          # Success, healthy
defp err, do: :red           # Errors, critical

# Usage:
text(" DASHBOARD ", fg: accent(), style: [:bold])
text(" q:quit  Tab:switch ", fg: highlight())
text("CPU: #{pct}%", fg: if(pct > 90, do: err(), else: ok()))
```

### Themed panels

Create a reusable panel helper:

```elixir
defp panel(title, opts \\ []) do
  border = Keyword.get(opts, :border, :single)
  active = Keyword.get(opts, :active, false)
  children = Keyword.get(opts, :children, [])

  box style: %{border: (if active, do: :double, else: border), flex: 1} do
    column do
      [text(" #{title} ", fg: :cyan, style: [:bold]) | children]
    end
  end
end
```

---

## Theme System

### ThemeManager

Register and switch themes at runtime:

```elixir
# Register a custom theme
Raxol.UI.Theming.ThemeManager.register_theme(:ocean, %{
  name: "Ocean",
  colors: %{
    primary: {64, 196, 255},
    secondary: {0, 255, 157},
    background: {15, 25, 45},
    foreground: {200, 220, 240},
    error: {255, 85, 85},
    warning: {255, 200, 0}
  },
  component_styles: %{
    button: %{fg: {64, 196, 255}, bold: true},
    text_input: %{border: :single, fg: {200, 220, 240}},
    tree: %{fg: {200, 220, 240}}
  }
})

# Switch theme
Raxol.UI.Theming.ThemeManager.set_theme(:ocean)
```

### Component-level theming

Widgets read theme styles from the render context:

```elixir
# In your component render:
def render(state, context) do
  theme = context[:theme] || %{}
  theme_style = Raxol.UI.Theming.Theme.component_style(theme, :button)
  base_style = Map.merge(theme_style, state.style || %{})
  # ...render with base_style...
end
```

### Pseudo-state styles

Themes can define styles for `:focus`, `:active`, and `:disabled` states:

```elixir
component_styles: %{
  button: %{
    fg: :cyan,
    focus: %{fg: :white, bg: :blue, bold: true},
    active: %{fg: :black, bg: :cyan},
    disabled: %{fg: :white, dim: true}
  }
}
```

The `FocusHelper` module resolves the correct style based on widget state.

### Built-in themes

Themes are stored as JSON in `priv/themes/`:

```bash
ls priv/themes/
# default.json, nord.json, dracula.json, ...
```

---

## LiveView Theming

When using the LiveView bridge, themes apply via CSS classes:

```elixir
<.live_component
  module={Raxol.LiveView.TerminalComponent}
  id="terminal"
  buffer={@buffer}
  theme={:nord}
/>
```

Built-in LiveView themes: `:nord`, `:dracula`, `:solarized_dark`, `:solarized_light`, `:monokai`.

### Custom CSS theme

```css
.terminal.theme-custom {
  background-color: #1a1a2e;
  color: #e0e0e0;
}

.terminal.theme-custom .fg-cyan { color: #40c4ff; }
.terminal.theme-custom .fg-magenta { color: #ff6bae; }
.terminal.theme-custom .fg-green { color: #00ff9d; }
.terminal.theme-custom .fg-yellow { color: #ffd700; }
.terminal.theme-custom .fg-red { color: #ff5555; }

.terminal.theme-custom .cursor {
  background-color: #40c4ff;
}
```

### Dynamic theme switching

```elixir
def handle_event("change_theme", %{"theme" => theme}, socket) do
  {:noreply, assign(socket, theme: String.to_existing_atom(theme))}
end
```

---

## Color Palettes

Popular palettes mapped to ANSI for quick reference:

### Nord
`red: #bf616a, green: #a3be8c, yellow: #ebcb8b, blue: #81a1c1, magenta: #b48ead, cyan: #88c0d0`

### Dracula
`red: #ff5555, green: #50fa7b, yellow: #f1fa8c, blue: #bd93f9, magenta: #ff79c6, cyan: #8be9fd`

### Tokyo Night
`red: #f7768e, green: #9ece6a, yellow: #e0af68, blue: #7aa2f7, magenta: #ad8ee6, cyan: #449dab`

### Catppuccin Mocha
`red: #f38ba8, green: #a6e3a1, yellow: #f9e2af, blue: #89b4fa, magenta: #f5c2e7, cyan: #94e2d5`

---

## Accessibility

### High contrast

Use maximum contrast ratios. Avoid relying on color alone:

```elixir
# Bad: color is the only indicator
text("OK", fg: :green)
text("FAIL", fg: :red)

# Good: text + color
text("[OK] Passed", fg: :green)
text("[!!] FAILED", fg: :red, style: [:bold])
```

### WCAG contrast checking

Ensure foreground/background pairs meet WCAG AA (4.5:1 ratio):

```elixir
# High contrast pairs that work everywhere:
text("...", fg: :white, bg: :black)    # 21:1
text("...", fg: :black, bg: :green)    # ~5.5:1
text("...", fg: :black, bg: :cyan)     # ~8.6:1
text("...", fg: :black, bg: :yellow)   # ~10.2:1
```

---

## Examples

- `examples/demo.exs` -- Flagship demo using Synthwave '84 mapped to ANSI
- `examples/advanced/color_system_demo.ex` -- Color system with adaptive downsampling

## Next Steps

- [Building Apps](./BUILDING_APPS.md) -- TEA patterns and recipes
- [SSH Deployment](./SSH_DEPLOYMENT.md) -- Serve apps over SSH
- [Performance](./PERFORMANCE_OPTIMIZATION.md) -- 60fps techniques
