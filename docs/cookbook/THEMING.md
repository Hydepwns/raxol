# Cookbook: Theming

Create custom color schemes and themes for your terminals.

## Table of Contents

- [Built-in Themes](#built-in-themes)
- [Custom Color Schemes](#custom-color-schemes)
- [Dynamic Theme Switching](#dynamic-theme-switching)
- [Accessibility](#accessibility)
- [Theme Gallery](#theme-gallery)

---

## Built-in Themes

Raxol.LiveView includes 5 professionally designed themes.

### Available Themes

```elixir
# In your LiveView
<.live_component
  module={Raxol.LiveView.TerminalComponent}
  id="terminal"
  buffer={@buffer}
  theme={:nord}  # Choose theme here
/>
```

**Theme Options:**

1. **`:nord`** - Nord color scheme (dark, cool)
2. **`:dracula`** - Dracula theme (dark, vibrant)
3. **`:solarized_dark`** - Solarized Dark (warm dark)
4. **`:solarized_light`** - Solarized Light (warm light)
5. **`:monokai`** - Monokai (dark, high contrast)

### Theme Preview

**Nord:**
- Background: #2e3440
- Foreground: #d8dee9
- Black: #3b4252
- Red: #bf616a
- Green: #a3be8c
- Yellow: #ebcb8b
- Blue: #81a1c1
- Magenta: #b48ead
- Cyan: #88c0d0
- White: #e5e9f0

**Dracula:**
- Background: #282a36
- Foreground: #f8f8f2
- Selection: #44475a
- Comment: #6272a4
- Red: #ff5555
- Green: #50fa7b
- Yellow: #f1fa8c
- Blue: #bd93f9
- Magenta: #ff79c6
- Cyan: #8be9fd

---

## Custom Color Schemes

Create your own themes.

### Recipe: Basic Custom Theme

```css
/* priv/static/css/custom_terminal.css */

/* Define your theme */
.terminal.theme-custom {
  background-color: #1a1a1a;
  color: #f0f0f0;
}

/* ANSI Colors */
.terminal.theme-custom .fg-black { color: #2e3436; }
.terminal.theme-custom .fg-red { color: #cc0000; }
.terminal.theme-custom .fg-green { color: #4e9a06; }
.terminal.theme-custom .fg-yellow { color: #c4a000; }
.terminal.theme-custom .fg-blue { color: #3465a4; }
.terminal.theme-custom .fg-magenta { color: #75507b; }
.terminal.theme-custom .fg-cyan { color: #06989a; }
.terminal.theme-custom .fg-white { color: #d3d7cf; }

/* Bright colors */
.terminal.theme-custom .fg-bright-black { color: #555753; }
.terminal.theme-custom .fg-bright-red { color: #ef2929; }
.terminal.theme-custom .fg-bright-green { color: #8ae234; }
.terminal.theme-custom .fg-bright-yellow { color: #fce94f; }
.terminal.theme-custom .fg-bright-blue { color: #729fcf; }
.terminal.theme-custom .fg-bright-magenta { color: #ad7fa8; }
.terminal.theme-custom .fg-bright-cyan { color: #34e2e2; }
.terminal.theme-custom .fg-bright-white { color: #eeeeec; }

/* Background colors */
.terminal.theme-custom .bg-black { background-color: #2e3436; }
.terminal.theme-custom .bg-red { background-color: #cc0000; }
/* ... repeat for all colors ... */

/* Text attributes */
.terminal.theme-custom .bold { font-weight: bold; }
.terminal.theme-custom .italic { font-style: italic; }
.terminal.theme-custom .underline { text-decoration: underline; }
.terminal.theme-custom .strikethrough { text-decoration: line-through; }

/* Cursor */
.terminal.theme-custom .cursor {
  background-color: #f0f0f0;
}

.terminal.theme-custom .cursor.block {
  opacity: 0.5;
}

.terminal.theme-custom .cursor.underline {
  border-bottom: 2px solid #f0f0f0;
}

.terminal.theme-custom .cursor.bar {
  border-left: 2px solid #f0f0f0;
}
```

Include in your layout:

```elixir
# lib/my_app_web/components/layouts/root.html.heex
<link rel="stylesheet" href={~p"/assets/custom_terminal.css"} />
```

Use the theme:

```elixir
<.live_component
  module={Raxol.LiveView.TerminalComponent}
  id="terminal"
  buffer={@buffer}
  theme={:custom}  # Your custom theme
/>
```

### Recipe: Programmatic Theme Generation

Generate themes from configuration.

```elixir
defmodule MyApp.ThemeGenerator do
  @moduledoc "Generate CSS themes from Elixir config"

  def generate_theme(name, colors) do
    """
    .terminal.theme-#{name} {
      background-color: #{colors.background};
      color: #{colors.foreground};
    }

    #{generate_ansi_colors(name, colors)}
    #{generate_text_attributes(name)}
    #{generate_cursor_styles(name, colors)}
    """
  end

  defp generate_ansi_colors(name, colors) do
    [
      generate_fg_color(name, "black", colors.black),
      generate_fg_color(name, "red", colors.red),
      generate_fg_color(name, "green", colors.green),
      generate_fg_color(name, "yellow", colors.yellow),
      generate_fg_color(name, "blue", colors.blue),
      generate_fg_color(name, "magenta", colors.magenta),
      generate_fg_color(name, "cyan", colors.cyan),
      generate_fg_color(name, "white", colors.white),
    ]
    |> Enum.join("\n")
  end

  defp generate_fg_color(theme, color, value) do
    """
    .terminal.theme-#{theme} .fg-#{color} { color: #{value}; }
    .terminal.theme-#{theme} .bg-#{color} { background-color: #{value}; }
    """
  end

  defp generate_text_attributes(theme) do
    """
    .terminal.theme-#{theme} .bold { font-weight: bold; }
    .terminal.theme-#{theme} .italic { font-style: italic; }
    .terminal.theme-#{theme} .underline { text-decoration: underline; }
    .terminal.theme-#{theme} .strikethrough { text-decoration: line-through; }
    """
  end

  defp generate_cursor_styles(theme, colors) do
    """
    .terminal.theme-#{theme} .cursor {
      background-color: #{colors.cursor || colors.foreground};
    }
    """
  end
end

# Usage
theme_css = MyApp.ThemeGenerator.generate_theme(:gruvbox, %{
  background: "#282828",
  foreground: "#ebdbb2",
  cursor: "#fe8019",
  black: "#282828",
  red: "#cc241d",
  green: "#98971a",
  yellow: "#d79921",
  blue: "#458588",
  magenta: "#b16286",
  cyan: "#689d6a",
  white: "#a89984"
})

File.write!("priv/static/css/theme_gruvbox.css", theme_css)
```

---

## Dynamic Theme Switching

Let users switch themes at runtime.

### Recipe: Theme Switcher Component

```elixir
defmodule MyAppWeb.TerminalWithThemeLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  @themes [:nord, :dracula, :solarized_dark, :solarized_light, :monokai]

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      buffer: create_buffer(),
      theme: :nord
    )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="theme-selector">
        <label>Theme:</label>
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

  @themes [:nord, :dracula, :solarized_dark, :solarized_light, :monokai]

  defp create_buffer do
    Buffer.create_blank_buffer(60, 20)
    |> Box.draw_box(0, 0, 60, 20, :double)
    |> Buffer.write_at(5, 5, "Try different themes!", %{bold: true})
    |> Buffer.write_at(5, 8, "Red text", %{fg_color: :red})
    |> Buffer.write_at(5, 9, "Green text", %{fg_color: :green})
    |> Buffer.write_at(5, 10, "Blue text", %{fg_color: :blue})
  end
end
```

### Recipe: Persistent Theme Preference

Save user's theme choice.

```elixir
defmodule MyAppWeb.ThemedTerminalLive do
  use MyAppWeb, :live_view

  def mount(_params, session, socket) do
    theme = load_theme_preference(session)

    {:ok, assign(socket, theme: theme)}
  end

  def handle_event("change_theme", %{"theme" => theme_str}, socket) do
    theme = String.to_atom(theme_str)

    # Save preference
    save_theme_preference(socket, theme)

    {:noreply, assign(socket, theme: theme)}
  end

  defp load_theme_preference(session) do
    # From session
    session["theme"] ||
    # Or from user preferences database
    get_user_theme(session["user_id"]) ||
    # Or from browser localStorage (via hook)
    :nord
  end

  defp save_theme_preference(socket, theme) do
    # Push to session
    put_session(socket, :theme, theme)

    # Or save to database
    # save_user_preference(socket.assigns.user_id, :theme, theme)

    # Or push to browser localStorage via JS hook
    push_event(socket, "save_theme", %{theme: theme})
  end

  defp get_user_theme(user_id) do
    # Query from database
    # MyApp.Accounts.get_user_preference(user_id, :terminal_theme)
    nil
  end
end
```

JavaScript hook for localStorage:

```javascript
// assets/js/app.js
let Hooks = {}

Hooks.ThemeManager = {
  mounted() {
    // Load theme from localStorage on mount
    const savedTheme = localStorage.getItem('terminal_theme')
    if (savedTheme) {
      this.pushEvent("load_theme", { theme: savedTheme })
    }

    // Listen for theme saves
    this.handleEvent("save_theme", ({ theme }) => {
      localStorage.setItem('terminal_theme', theme)
    })
  }
}

export default Hooks
```

---

## Accessibility

Ensure themes are accessible.

### Recipe: High Contrast Mode

```css
/* priv/static/css/accessibility.css */

/* High contrast theme for accessibility */
.terminal.theme-high-contrast {
  background-color: #000000;
  color: #ffffff;
}

.terminal.theme-high-contrast .fg-red { color: #ff0000; }
.terminal.theme-high-contrast .fg-green { color: #00ff00; }
.terminal.theme-high-contrast .fg-blue { color: #0000ff; }
.terminal.theme-high-contrast .fg-yellow { color: #ffff00; }

/* Increase cursor visibility */
.terminal.theme-high-contrast .cursor {
  background-color: #ffffff;
  opacity: 1 !important;
}

/* Bold all text for better readability */
.terminal.theme-high-contrast {
  font-weight: 500;
}
```

### Recipe: Contrast Checker

Validate color contrast ratios.

```elixir
defmodule MyApp.ContrastChecker do
  @moduledoc "Check WCAG AA/AAA contrast ratios"

  @wcag_aa 4.5
  @wcag_aaa 7.0

  def check_contrast(fg_color, bg_color) do
    luminance_fg = calculate_luminance(fg_color)
    luminance_bg = calculate_luminance(bg_color)

    ratio = calculate_ratio(luminance_fg, luminance_bg)

    %{
      ratio: ratio,
      passes_aa: ratio >= @wcag_aa,
      passes_aaa: ratio >= @wcag_aaa
    }
  end

  defp calculate_luminance(hex) do
    {r, g, b} = hex_to_rgb(hex)

    # Convert to relative luminance
    r = channel_luminance(r / 255)
    g = channel_luminance(g / 255)
    b = channel_luminance(b / 255)

    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  defp channel_luminance(c) when c <= 0.03928 do
    c / 12.92
  end

  defp channel_luminance(c) do
    :math.pow((c + 0.055) / 1.055, 2.4)
  end

  defp calculate_ratio(l1, l2) do
    lighter = max(l1, l2)
    darker = min(l1, l2)

    (lighter + 0.05) / (darker + 0.05)
  end

  defp hex_to_rgb("#" <> hex) do
    hex_to_rgb(hex)
  end

  defp hex_to_rgb(<<r::binary-2, g::binary-2, b::binary-2>>) do
    {
      String.to_integer(r, 16),
      String.to_integer(g, 16),
      String.to_integer(b, 16)
    }
  end
end

# Usage
MyApp.ContrastChecker.check_contrast("#2e3440", "#d8dee9")
# => %{ratio: 12.4, passes_aa: true, passes_aaa: true}

MyApp.ContrastChecker.check_contrast("#888888", "#999999")
# => %{ratio: 1.2, passes_aa: false, passes_aaa: false}
```

---

## Theme Gallery

Explore community themes.

### Gruvbox Dark

```css
.terminal.theme-gruvbox-dark {
  background-color: #282828;
  color: #ebdbb2;
}

.terminal.theme-gruvbox-dark .fg-black { color: #282828; }
.terminal.theme-gruvbox-dark .fg-red { color: #cc241d; }
.terminal.theme-gruvbox-dark .fg-green { color: #98971a; }
.terminal.theme-gruvbox-dark .fg-yellow { color: #d79921; }
.terminal.theme-gruvbox-dark .fg-blue { color: #458588; }
.terminal.theme-gruvbox-dark .fg-magenta { color: #b16286; }
.terminal.theme-gruvbox-dark .fg-cyan { color: #689d6a; }
.terminal.theme-gruvbox-dark .fg-white { color: #a89984; }

.terminal.theme-gruvbox-dark .fg-bright-black { color: #928374; }
.terminal.theme-gruvbox-dark .fg-bright-red { color: #fb4934; }
.terminal.theme-gruvbox-dark .fg-bright-green { color: #b8bb26; }
.terminal.theme-gruvbox-dark .fg-bright-yellow { color: #fabd2f; }
.terminal.theme-gruvbox-dark .fg-bright-blue { color: #83a598; }
.terminal.theme-gruvbox-dark .fg-bright-magenta { color: #d3869b; }
.terminal.theme-gruvbox-dark .fg-bright-cyan { color: #8ec07c; }
.terminal.theme-gruvbox-dark .fg-bright-white { color: #ebdbb2; }
```

### Tokyo Night

```css
.terminal.theme-tokyo-night {
  background-color: #1a1b26;
  color: #a9b1d6;
}

.terminal.theme-tokyo-night .fg-black { color: #32344a; }
.terminal.theme-tokyo-night .fg-red { color: #f7768e; }
.terminal.theme-tokyo-night .fg-green { color: #9ece6a; }
.terminal.theme-tokyo-night .fg-yellow { color: #e0af68; }
.terminal.theme-tokyo-night .fg-blue { color: #7aa2f7; }
.terminal.theme-tokyo-night .fg-magenta { color: #ad8ee6; }
.terminal.theme-tokyo-night .fg-cyan { color: #449dab; }
.terminal.theme-tokyo-night .fg-white { color: #787c99; }
```

### Catppuccin Mocha

```css
.terminal.theme-catppuccin-mocha {
  background-color: #1e1e2e;
  color: #cdd6f4;
}

.terminal.theme-catppuccin-mocha .fg-black { color: #45475a; }
.terminal.theme-catppuccin-mocha .fg-red { color: #f38ba8; }
.terminal.theme-catppuccin-mocha .fg-green { color: #a6e3a1; }
.terminal.theme-catppuccin-mocha .fg-yellow { color: #f9e2af; }
.terminal.theme-catppuccin-mocha .fg-blue { color: #89b4fa; }
.terminal.theme-catppuccin-mocha .fg-magenta { color: #f5c2e7; }
.terminal.theme-catppuccin-mocha .fg-cyan { color: #94e2d5; }
.terminal.theme-catppuccin-mocha .fg-white { color: #bac2de; }
```

### One Dark

```css
.terminal.theme-one-dark {
  background-color: #282c34;
  color: #abb2bf;
}

.terminal.theme-one-dark .fg-black { color: #282c34; }
.terminal.theme-one-dark .fg-red { color: #e06c75; }
.terminal.theme-one-dark .fg-green { color: #98c379; }
.terminal.theme-one-dark .fg-yellow { color: #e5c07b; }
.terminal.theme-one-dark .fg-blue { color: #61afef; }
.terminal.theme-one-dark .fg-magenta { color: #c678dd; }
.terminal.theme-one-dark .fg-cyan { color: #56b6c2; }
.terminal.theme-one-dark .fg-white { color: #abb2bf; }
```

### Material Theme

```css
.terminal.theme-material {
  background-color: #263238;
  color: #eeffff;
}

.terminal.theme-material .fg-black { color: #000000; }
.terminal.theme-material .fg-red { color: #ff5370; }
.terminal.theme-material .fg-green { color: #c3e88d; }
.terminal.theme-material .fg-yellow { color: #ffcb6b; }
.terminal.theme-material .fg-blue { color: #82aaff; }
.terminal.theme-material .fg-magenta { color: #c792ea; }
.terminal.theme-material .fg-cyan { color: #89ddff; }
.terminal.theme-material .fg-white { color: #ffffff; }
```

---

## Theme Configuration

### Recipe: Theme Config File

```elixir
# config/themes.exs
[
  nord: %{
    name: "Nord",
    background: "#2e3440",
    foreground: "#d8dee9",
    cursor: "#d8dee9",
    colors: %{
      black: "#3b4252",
      red: "#bf616a",
      green: "#a3be8c",
      yellow: "#ebcb8b",
      blue: "#81a1c1",
      magenta: "#b48ead",
      cyan: "#88c0d0",
      white: "#e5e9f0"
    }
  },
  gruvbox_dark: %{
    name: "Gruvbox Dark",
    background: "#282828",
    foreground: "#ebdbb2",
    cursor: "#fe8019",
    colors: %{
      black: "#282828",
      red: "#cc241d",
      green: "#98971a",
      yellow: "#d79921",
      blue: "#458588",
      magenta: "#b16286",
      cyan: "#689d6a",
      white: "#a89984"
    }
  }
]
```

Load and use:

```elixir
defmodule MyApp.Themes do
  @themes Code.eval_file("config/themes.exs")
          |> elem(0)
          |> Enum.into(%{})

  def list_themes do
    Map.keys(@themes)
  end

  def get_theme(name) do
    Map.get(@themes, name)
  end

  def generate_css(theme_name) do
    theme = get_theme(theme_name)
    MyApp.ThemeGenerator.generate_theme(theme_name, theme)
  end
end
```

---

## Best Practices

### Do's

- ✓ Test themes in different lighting conditions
- ✓ Ensure sufficient contrast (WCAG AA minimum)
- ✓ Provide both light and dark options
- ✓ Include high-contrast mode
- ✓ Use semantic color names
- ✓ Document color hex values
- ✓ Test with colorblind simulators

### Don'ts

- ✗ Use low-contrast colors (< 4.5:1 ratio)
- ✗ Rely only on color for information
- ✗ Use red/green as only differentiator (colorblind)
- ✗ Override user system preferences without option
- ✗ Hardcode theme in components
- ✗ Forget to test cursor visibility

---

## Next Steps

- **[LiveView Cookbook](./LIVEVIEW_INTEGRATION.md)** - Web integration
- **[Performance Cookbook](./PERFORMANCE_OPTIMIZATION.md)** - Optimization techniques
- **[Contributing](../../.github/CONTRIBUTING.md)** - Share your themes!

---

**Created a theme?** Submit a PR to add it to the gallery!
