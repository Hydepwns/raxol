# Raxol

[![Hex pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)
[![GitHub Actions CI](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml)

A terminal application toolkit for Elixir, providing components and a runtime for building interactive TUI applications.

> **Note:** Raxol is actively developed (_pre-release-stage_). APIs may evolve.

<!-- TODO: Add a screenshot or GIF demo here -->

## Features

- **Component Model:** Build UIs with reusable, stateful components implementing the `Raxol.UI.Components.Base.Component` behaviour.
- **Declarative View DSL:** Compose UIs using macros like `panel`, `row`, `column`, and `text` from `Raxol.View.Elements`.
- **Component Hierarchy:** Nest components to build complex UIs, with clear parent-child relationships and event propagation.
- **Lifecycle Management:** Each component supports a full lifecycle (`init`, `mount`, `update`, `render`, `handle_event`, `unmount`).
- **Theming:** Customize appearance with themes via `Raxol.Core.ColorSystem`.
- **User Preferences:** Persist settings across sessions (`Raxol.Core.UserPreferences`).
- **Plugin System:** Extend functionality with custom plugins (`Raxol.Core.Runtime.Plugins`).
  - Comprehensive behavior modules for plugin lifecycle, commands, and state management
  - Event-based plugin system with robust error handling
  - Hot-reloading support for development
  - Specialized modules for command handling, file watching, lifecycle management, and more
- **Terminal Handling:** Robust ANSI/Sixel processing, input handling, double buffering with NIF-based termbox integration.
- **Performance Testing:** Built-in benchmarking and performance testing infrastructure.
  - Configurable performance requirements and metrics collection
  - Event processing: < 1ms average, < 2ms 95th percentile
  - Screen updates: < 2ms average, < 5ms 95th percentile
  - Concurrent operations: < 5ms average, < 10ms 95th percentile
  - Performance regression detection
- **Testable System Interactions:** Uses an adapter pattern for system calls (file system, HTTP) to improve testability.
- **Event-Based Testing:** Comprehensive test infrastructure with event-based synchronization.
  - Deterministic test execution without arbitrary sleeps
  - Unique state tracking for test plugins
  - Proper resource cleanup and isolation
  - Systematic use of Mox for mocking

## Component & View System

Raxol provides a robust, declarative component system inspired by The Elm Architecture. Components are reusable, stateful modules that implement a standard behaviour, supporting a clear lifecycle:

- `init/1` — Initialize state from props
- `mount/1` — Set up resources after mounting
- `update/2` — Update state in response to messages
- `render/1` — Produce the component's view
- `handle_event/2` — Handle user/system events
- `unmount/1` — Clean up resources

Components are composed using the `Raxol.View.Elements` DSL, supporting hierarchical parent-child relationships and explicit event propagation.
Comprehensive test helpers and event-based synchronization ensure reliable, isolated component tests.

See [Component API Reference](docs/components/api/component_api_reference.md) and [Component Architecture Guide](docs/component_architecture.md) for details.

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
          text(content: "Count: #{state.count}") # No padding needed
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
- [CHANGELOG](CHANGELOG.md)
- [UI Components & Layout](docs/guides/03_components_and_layout/components/README.md)
- [Accessibility Guide](docs/guides/05_development_and_testing/development/planning/accessibility/accessibility_guide.md)
- **Core Concepts:**
  - [Runtime Options](docs/guides/02_core_concepts/runtime_options.md)
  - [Async Operations](docs/guides/02_core_concepts/async_operations.md)
  - [Theming](docs/guides/02_core_concepts/theming.md)
- **Extending Raxol:**
  - [Plugin Development](docs/guides/04_extending_raxol/plugin_development.md)
  - [VS Code Extension](docs/guides/04_extending_raxol/vscode_extension.md)
- **Development & Testing:**
  - [Development Setup](docs/guides/05_development_and_testing/DevelopmentSetup.md)
  - [Testing Guide](docs/guides/05_development_and_testing/testing.md)
  - [Performance Testing](docs/testing/performance_testing.md)
- [Terminal Details](docs/guides/02_core_concepts/terminal/README.md)

## Development

See [Development Setup](docs/guides/05_development_and_testing/DevelopmentSetup.md).

> **Note:** The project recently completed a major refactoring, including:
>
> - Comprehensive plugin system improvements with specialized modules
> - Performance testing infrastructure with strict requirements
> - Event-based testing infrastructure replacing Process.sleep calls
> - System interaction adapter pattern for improved testability
> - Current test suite status (2025-05-08): 279 failures, 17 invalid, 21 skipped tests
>   See `CHANGELOG.md` for details.

Common commands:

```bash
mix deps.get
mix test
mix credo
mix dialyzer
mix compile # Use --warnings-as-errors for stricter checks
mix format
```
