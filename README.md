# Raxol

[![Hex pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![GitHub Actions CI](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml)

**Raxol** is a modern toolkit for building interactive terminal (TUI) applications in Elixir.
It offers a powerful component system, a flexible runtime, and a robust plugin architecture—making it easy to create beautiful, responsive terminal UIs.

> **Note:** Raxol is in active development (pre-release).
> APIs will change as we improve the toolkit.
>
> <!-- TODO: Add a screenshot or GIF demo here -->

## Architecture

- Terminal: I/O, buffer, cursor, command, style, parser, input.
- Core: Lifecycle, events, plugins, color, UX.
- Plugins: Modular/extensible.
- Style: Color/theming/layout.
- UI: Components/layout/render.
- AI: Content gen, perf.
- Animation: Anim, easing, gestures.

See [ARCHITECTURE.md](docs/ARCHITECTURE.md).

## ✨ Features

- **Component Model:** Build UIs from reusable, stateful components.
- **Declarative View DSL:** Compose layouts with expressive macros (`panel`, `row`, `column`, `text`, etc.).
- **Lifecycle Management:** Each component supports a full lifecycle (`init`, `mount`, `update`, `render`, `handle_event`, `unmount`).
- **Theming & Preferences:** Customizable themes and persistent user settings.
- **Plugin System:** Extend Raxol with hot-reloadable plugins and robust error handling.
- **Terminal Handling:** Advanced ANSI/Sixel support, input handling, and double buffering.
- **Performance & Testing:** Built-in benchmarking, event-based test helpers, and system interaction adapters for reliable, fast tests.

## 🚀 Get Started

Add Raxol to your `mix.exs`:

```elixir
# mix.exs, check hex.pm/packages/raxol
def deps do
  [
    {:raxol, "~> 0.4.0"}
  ]
end
```

## Common Commands

```bash
# Fetch dependencies
mix deps.get

# Run tests
mix test
mix test.watch
mix credo
mix dialyzer
mix format
mix compile --warnings-as-errors
```

## 📦 Static Assets

All static assets (JavaScript, CSS, images, etc.) are located in the `priv/static/@static` directory.

- If you need to add or update frontend assets, use the `@static` folder.
- The asset pipeline (npm, bundlers, etc.) should be run from `priv/static/@static`.
- References to static files in templates and code should use the `/@static/` path prefix.

## 🛠️ Example: A Simple Counter App

```elixir
defmodule ExampleApp do
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  @impl true
  def init(_), do: {:ok, %{count: 0}}

  # Raxol event handling
  @impl true
  def update(:increment, state), do: {:ok, %{state | count: state.count + 1}, []}
  def update(:decrement, state), do: {:ok, %{state | count: state.count - 1}, []}
  def update(_, state), do: {:ok, state, []}

  # Raxol view DSL
  @impl true
  def view(state) do
    view do
      panel title: "Counter" do
        row do
          button(label: "-", on_click: :decrement)
          text(content: "Count: #{state.count}")
          button(label: "+", on_click: :increment)
        end
      end
    end
  end
end

# Starts ExampleApp
Raxol.start_link(ExampleApp)
```

> **Above example uses Raxol view DSL**, which lets you build TUI layouts and UI elements declaratively using Elixir macros.
> Compose layouts and UI elements with a syntax _similar_ to HTML— but in pure, undiddled, and unopinionated Elixir.

**How the View DSL works:**

- `panel/1` – Draws a bordered panel with an optional title.
- `row/1` and `column/1` – Arrange child elements horizontally or vertically.
- `button/1` – Interactive button with label and event handler.
- `text/1` – Displays static or dynamic text.

You can nest these macros to create complex layouts.
All properties (like `title`, `label`, `on_click`, etc.) are passed as keyword lists.
For more, see the [UI Components & Layout Guide](examples/guides/03_components_and_layout/components/README.md).

## 📚 Resources

- [Accessibility Guide](examples/guides/05_development_and_testing/development/planning/accessibility/accessibility_guide.md)
- [Architecture Overview](docs/ARCHITECTURE.md)
- [Changelog](CHANGELOG.md)
- [Docs Index](docs/README.md)
- [Plugin Development](examples/guides/04_extending_raxol/plugin_development.md)
- [Testing Guide](examples/guides/05_development_and_testing/testing.md)
- [Terminal Details](examples/guides/02_core_concepts/terminal/README.md)
- [VS Code Extension](examples/guides/04_extending_raxol/vscode_extension.md)

## License

MIT © 2024 Raxol Team
