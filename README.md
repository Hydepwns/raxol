# Raxol

[![Hex pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)
[![GitHub Actions CI](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml)

**Raxol** is a modern toolkit for building interactive terminal (TUI) applications in Elixir. It offers a powerful component system, a flexible runtime, and a robust plugin architecture—making it easy to create beautiful, responsive terminal UIs.

> **Note:** Raxol is in active development (pre-release). APIs may change as we improve the toolkit.

<!-- TODO: Add a screenshot or GIF demo here -->

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
def deps do
  [
    {:raxol, "~> 0.2.0"} # Check Hex for the latest version
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## 🛠️ Example: A Simple Counter

```elixir
defmodule MyApp do
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  @impl true
  def init(_), do: {:ok, %{count: 0}}

  @impl true
  def update(:increment, state), do: {:ok, %{state | count: state.count + 1}, []}
  def update(:decrement, state), do: {:ok, %{state | count: state.count - 1}, []}
  def update(_, state), do: {:ok, state, []}

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

# Start your app:
Raxol.start_link(MyApp)
```

Explore more in the [Getting Started Tutorial](docs/guides/01_getting_started/quick_start.md) and the `/examples` directory.

## 📚 Documentation

- [Main Docs Index](docs/README.md)
- [Architecture Overview](docs/ARCHITECTURE.md)
- [CHANGELOG](CHANGELOG.md)
- [UI Components & Layout](docs/guides/03_components_and_layout/components/README.md)
- [Accessibility Guide](docs/guides/05_development_and_testing/development/planning/accessibility/accessibility_guide.md)
- [Plugin Development](docs/guides/04_extending_raxol/plugin_development.md)
- [VS Code Extension](docs/guides/04_extending_raxol/vscode_extension.md)
- [Development Setup](docs/guides/05_development_and_testing/DevelopmentSetup.md)
- [Testing Guide](docs/guides/05_development_and_testing/testing.md)
- [Performance Testing](docs/testing/performance_testing.md)
- [Terminal Details](docs/guides/02_core_concepts/terminal/README.md)

## 🧑‍💻 Development

Raxol is evolving quickly! Recent updates include:

- A revamped plugin system
- Performance testing infrastructure
- Event-based test synchronization
- System interaction adapters for testability

**Test suite status (2025-05-08):** 279 failures, 17 invalid, 21 skipped (see `CHANGELOG.md` for details).

### Common Commands

```bash
mix deps.get
mix test
mix credo
mix dialyzer
mix compile --warnings-as-errors
mix format
```

## License

MIT © 2024 Raxol Team
