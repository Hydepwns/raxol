# Theming

Custom color schemes and themes for your terminals.

## Built-in Themes

Raxol.LiveView ships with 5 themes:

```elixir
<.live_component
  module={Raxol.LiveView.TerminalComponent}
  id="terminal"
  buffer={@buffer}
  theme={:nord}
/>
```

Options: `:nord`, `:dracula`, `:solarized_dark`, `:solarized_light`, `:monokai`.

### Color Previews

**Nord** - bg: #2e3440, fg: #d8dee9, accent colors: red #bf616a, green #a3be8c, yellow #ebcb8b, blue #81a1c1, magenta #b48ead, cyan #88c0d0.

**Dracula** - bg: #282a36, fg: #f8f8f2, red #ff5555, green #50fa7b, yellow #f1fa8c, blue #bd93f9, magenta #ff79c6, cyan #8be9fd.

---

## Custom Color Schemes

### CSS Theme

```css
/* priv/static/css/custom_terminal.css */
.terminal.theme-custom {
  background-color: #1a1a1a;
  color: #f0f0f0;
}

.terminal.theme-custom .fg-black { color: #2e3436; }
.terminal.theme-custom .fg-red { color: #cc0000; }
.terminal.theme-custom .fg-green { color: #4e9a06; }
.terminal.theme-custom .fg-yellow { color: #c4a000; }
.terminal.theme-custom .fg-blue { color: #3465a4; }
.terminal.theme-custom .fg-magenta { color: #75507b; }
.terminal.theme-custom .fg-cyan { color: #06989a; }
.terminal.theme-custom .fg-white { color: #d3d7cf; }

.terminal.theme-custom .bold { font-weight: bold; }
.terminal.theme-custom .italic { font-style: italic; }
.terminal.theme-custom .underline { text-decoration: underline; }

.terminal.theme-custom .cursor {
  background-color: #f0f0f0;
}
```

Include in your layout and use `theme={:custom}`.

### Programmatic Generation

```elixir
defmodule MyApp.ThemeGenerator do
  def generate_theme(name, colors) do
    """
    .terminal.theme-#{name} {
      background-color: #{colors.background};
      color: #{colors.foreground};
    }

    #{generate_ansi_colors(name, colors)}
    """
  end

  defp generate_ansi_colors(name, colors) do
    for {color_name, value} <- colors.ansi do
      """
      .terminal.theme-#{name} .fg-#{color_name} { color: #{value}; }
      .terminal.theme-#{name} .bg-#{color_name} { background-color: #{value}; }
      """
    end
    |> Enum.join("\n")
  end
end
```

---

## Dynamic Theme Switching

```elixir
defmodule MyAppWeb.TerminalWithThemeLive do
  use MyAppWeb, :live_view

  @themes [:nord, :dracula, :solarized_dark, :solarized_light, :monokai]

  def mount(_params, _session, socket) do
    {:ok, assign(socket, buffer: create_buffer(), theme: :nord)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="theme-selector">
        <%= for theme <- @themes do %>
          <button
            phx-click="change_theme"
            phx-value-theme={theme}
            class={"theme-button #{if theme == @theme, do: "active"}"}
          >
            <%= theme %>
          </button>
        <% end %>
      </div>

      <.live_component
        module={Raxol.LiveView.TerminalComponent}
        id="terminal"
        buffer={@buffer}
        theme={@theme}
      />
    </div>
    """
  end

  def handle_event("change_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, theme: String.to_atom(theme))}
  end
end
```

### Persistent Preferences

Save theme to session, database, or browser localStorage via a JS hook:

```javascript
// assets/js/app.js
Hooks.ThemeManager = {
  mounted() {
    const saved = localStorage.getItem('terminal_theme')
    if (saved) this.pushEvent("load_theme", { theme: saved })

    this.handleEvent("save_theme", ({ theme }) => {
      localStorage.setItem('terminal_theme', theme)
    })
  }
}
```

---

## Accessibility

### High Contrast Mode

```css
.terminal.theme-high-contrast {
  background-color: #000000;
  color: #ffffff;
}

.terminal.theme-high-contrast .fg-red { color: #ff0000; }
.terminal.theme-high-contrast .fg-green { color: #00ff00; }
.terminal.theme-high-contrast .fg-blue { color: #0000ff; }

.terminal.theme-high-contrast .cursor {
  background-color: #ffffff;
  opacity: 1 !important;
}

.terminal.theme-high-contrast {
  font-weight: 500;
}
```

### Contrast Checker

Validate WCAG AA/AAA contrast ratios:

```elixir
defmodule MyApp.ContrastChecker do
  @wcag_aa 4.5
  @wcag_aaa 7.0

  def check_contrast(fg_hex, bg_hex) do
    ratio = calculate_ratio(luminance(fg_hex), luminance(bg_hex))
    %{ratio: ratio, passes_aa: ratio >= @wcag_aa, passes_aaa: ratio >= @wcag_aaa}
  end
end

# Usage
MyApp.ContrastChecker.check_contrast("#2e3440", "#d8dee9")
# => %{ratio: 12.4, passes_aa: true, passes_aaa: true}
```

---

## Theme Gallery

Community themes ready to use:

### Gruvbox Dark
bg: #282828, fg: #ebdbb2. red #cc241d, green #98971a, yellow #d79921, blue #458588, magenta #b16286, cyan #689d6a.

### Tokyo Night
bg: #1a1b26, fg: #a9b1d6. red #f7768e, green #9ece6a, yellow #e0af68, blue #7aa2f7, magenta #ad8ee6, cyan #449dab.

### Catppuccin Mocha
bg: #1e1e2e, fg: #cdd6f4. red #f38ba8, green #a6e3a1, yellow #f9e2af, blue #89b4fa, magenta #f5c2e7, cyan #94e2d5.

### One Dark
bg: #282c34, fg: #abb2bf. red #e06c75, green #98c379, yellow #e5c07b, blue #61afef, magenta #c678dd, cyan #56b6c2.

### Material
bg: #263238, fg: #eeffff. red #ff5370, green #c3e88d, yellow #ffcb6b, blue #82aaff, magenta #c792ea, cyan #89ddff.

Full CSS for each theme is available in `priv/static/css/`.

---

## Best Practices

- Test themes in different lighting conditions
- Ensure sufficient contrast (WCAG AA minimum: 4.5:1)
- Provide both light and dark options
- Include high-contrast mode
- Test with colorblind simulators
- Don't rely only on color for information
- Don't override system preferences without an option to revert

---

## Next Steps

- [LiveView Cookbook](./LIVEVIEW_INTEGRATION.md)
- [Performance Cookbook](./PERFORMANCE_OPTIMIZATION.md)
