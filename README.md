# Raxol

[![Hex pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)
[![GitHub Actions CI](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml)

A terminal application toolkit for Elixir, providing components and a runtime for building interactive TUI applications.

> **Note:** Raxol is actively developed (_pre-release-stage_). APIs may evolve.

<!-- TODO: Add a screenshot or GIF demo here -->

## Features

- **Component Model:** Build UIs with reusable components (`Raxol.Core.Runtime.Application` behaviour).
- **Declarative View DSL:** Define UIs using `Raxol.View.Elements` macros (`box`, `text`, etc.).
- **Layout System:** Arrange components using flexible layouts (`panel`, `row`, `column`).
- **Theming:** Customize appearance with themes via `Raxol.Core.ColorSystem`.
- **User Preferences:** Persist settings across sessions (`Raxol.Core.UserPreferences`).
- **Plugin System:** Extend functionality with custom plugins (`Raxol.Core.Runtime.Plugins`).
- **Terminal Handling:** Robust ANSI/Sixel processing, input handling, double buffering with NIF-based termbox integration.
- **Testable System Interactions:** Uses an adapter pattern for system calls (file system, HTTP) to improve testability.

## Installation

Add `raxol` to `mix.exs`:

```elixir
def deps do
  [
    {:raxol, "~> 0.2.0"} # Check Hex for the latest version, 0.2.0 is the last tag.
  ]
end
```

Then run `mix deps.get`. See [Development Setup](docs/guides/05_development_and_testing/DevelopmentSetup.md) for more.

## Getting Started

```elixir
defmodule MyApp do
  use Raxol.Core.Runtime.Application # Use the Application behaviour
  import Raxol.View.Elements         # Import View DSL macros

  @impl true
  def init(_context), do: {:ok, %{count: 0}} # Initial state

  @impl true
  def update(message, state) do
    # Handle UI events (:increment, :decrement)
    new_state =
      case message do
        :increment -> Map.update!(state, :count, &(&1 + 1))
        :decrement -> Map.update!(state, :count, &(&1 - 1))
        _ -> state
      end
    {:ok, new_state, []} # Return new state, no commands
  end

  @impl true
  def view(state) do
    # Render UI based on state
    view do
      panel title: "Counter" do
        row do
          button(label: "-", on_click: :decrement)
          text(content: "Count: \#{state.count}") # No padding needed
          button(label: "+", on_click: :increment)
        end
      end
    end
  end

  # Optional callbacks: handle_event/1, handle_tick/1, subscriptions/1
end

# Or, using the convenience wrapper for common use cases:
Raxol.start_link(MyApp)
```

See [Getting Started Tutorial](docs/guides/01_getting_started/quick_start.md) and `/examples` for more runnable demos.

## Documentation

Main documentation index: [docs/README.md](docs/README.md)

- [Architecture Overview](docs/ARCHITECTURE.md)
- [CHANGELOG](docs/changes/CHANGELOG.md)
- [UI Components & Layout](docs/guides/03_components_and_layout/components/README.md)
- [Accessibility Guide](docs/guides/05_development_and_testing/development/planning/accessibility/accessibility_guide.md)
- **Core Concepts:**
  - [Runtime Options](docs/guides/02_core_concepts/runtime_options.md)
  - [Async Operations](docs/guides/02_core_concepts/async_operations.md)
  - [Theming](docs/guides/02_core_concepts/theming.md)
- **Extending Raxol:**
  - [Plugin Development](docs/guides/04_extending_raxol/plugin_development.md)
  - [VS Code Extension](docs/guides/04_extending_raxol/vscode_extension.md) (Planned)
- **Development & Testing:**
  - [Development Setup](docs/guides/05_development_and_testing/DevelopmentSetup.md)
  - [Testing Guide](docs/guides/05_development_and_testing/testing.md)
- [Terminal Details](docs/guides/02_core_concepts/terminal/README.md)

## Development

See [Development Setup](docs/guides/05_development_and_testing/DevelopmentSetup.md).

> **Note:** The project recently completed a major refactoring. See `CHANGELOG.md` for context.

Common commands:

```bash
mix deps.get
mix test
mix credo
mix dialyzer
mix compile # Use --warnings-as-errors for stricter checks
mix format
```

Helper scripts are in `/scripts` ([Scripts README](scripts/README.md)).

GitHub Actions details: [.github/workflows/README.md](.github/workflows/README.md).

## Project Structure

- `/assets` -> Processed web assets -> `/priv/static`
- `/docker` -> Docker configs (`act`)
- `/docs` -> Guides, Components, Architecture, Documentation Snippets
- `/examples` -> Runnable example applications and demos
- `/extensions` -> IDE integrations (VS Code)
- `/lib` -> Core Elixir code (`raxol/core`, `raxol/ui`, `raxol/terminal`, etc.)
- `/priv` -> Compiled assets (`priv/static`), themes, plugins
- `/scripts` -> Development helper scripts
- `/test` -> Test suites

## License

MIT - see [LICENSE](LICENSE.md).
