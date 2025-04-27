# Raxol

[![Hex pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)
[![GitHub Actions CI](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml)

A terminal application toolkit for Elixir, providing components and a runtime for building interactive TUI applications.

> **Note:** Raxol is actively developed (pre-1.0). While a major refactoring was recently completed, APIs may still evolve.

<!-- TODO: Add a screenshot or GIF demo here -->

## Features

- **ANSI & Sixel Support:** Robust handling of ANSI escape codes, colors, Unicode characters, and Sixel graphics.
- **Component Model:** Build UIs with reusable components (implementing the `Base.Component` behaviour).
- **Declarative View DSL:** Define UIs using convenient macros (`Raxol.View.Elements`).
- **Layout System:** Flexible layouts for arranging components within the terminal window.
- **Flexible Theming:** Customize the look and feel with built-in and custom themes.
- **Extensible Plugin System:** Enhance functionality with custom plugins.
- **User Preferences:** Persist settings like themes across sessions.
- **Performance:** Optimized rendering pipeline with double buffering and efficient updates.

## Installation

Add `raxol` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:raxol, "~> 0.1.0"}
  ]
end
```

Then, fetch the dependencies:

```bash
mix deps.get
```

For detailed installation options and requirements, see the [Development Environment Setup](docs/development/DevelopmentSetup.md).

## Getting Started

Here's a basic example of a Raxol application demonstrating state and event handling:

```elixir
defmodule MyApp do
  # Import Application behaviour and View DSL macros
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  @impl true
  def init(_context) do
    # Initial state: a map with a count
    {:ok, %{count: 0}}
  end

  @impl true
  def update(message, state) do
    # Handle messages sent by UI events (e.g., button clicks)
    new_state =
      case message do
        :increment -> %{state | count: state.count + 1}
        :decrement -> %{state | count: state.count - 1}
        _ -> state # Ignore other messages
      end
    # Return the new state and any commands (none in this case)
    {:ok, new_state, []}
  end

  @impl true
  def view(state) do
    # Render the UI based on the current state
    view do
      panel title: "Counter Example" do
        row do
          # Buttons trigger :decrement and :increment messages on click
          button(label: "-", on_click: :decrement)
          text(content: " Count: #{state.count} ", align: :center)
          button(label: "+", on_click: :increment)
        end
      end
    end
  end

  # Optional: Handle subscriptions (e.g., timers, external events)
  # @impl true
  # def subscribe(_state), do: []
end

# Start the application
# This would typically be done within your application's supervisor tree
# or run directly for simple scripts:
# Raxol.Core.Runtime.Lifecycle.start_application(MyApp)
```

> **Note:** Implement the `Raxol.Core.Runtime.Application` behaviour for the main application logic and use `Raxol.View.Elements` macros (`view`, `panel`, etc.) to define the UI structure. See the examples in `/examples` and the [Getting Started Tutorial](docs/guides/quick_start.md) for more details.

For a more comprehensive guide, please refer to the [Getting Started Tutorial](docs/guides/quick_start.md).

Explore the `/examples` directory for more detailed usage patterns and advanced features.

## Documentation

Detailed documentation can be found in the `/docs` directory or online (TODO: Add the hosted documentation link here):

- [Architecture Overview](docs/ARCHITECTURE.md) - Learn about the reorganized codebase structure
- [CHANGELOG](CHANGELOG.md) - See recent changes
- [Getting Started Tutorial](docs/guides/quick_start.md)
- [UI Components & Layout](docs/guides/components.md)
- [Async Operations (Subscriptions & Commands)](docs/guides/async_operations.md)
- [Runtime Options](docs/guides/runtime_options.md)
- [Terminal Emulator Details](docs/development/terminal_emulator.md)
- [Development Environment Setup](docs/development/DevelopmentSetup.md)
- [Version Management](docs/development/VersionManagement.md)

## Development

To set up your development environment, please see the [Development Environment Setup](docs/development/DevelopmentSetup.md) guide.

> **Note:** The project recently completed a major refactoring. See `CHANGELOG.md` and `docs/development/planning/handoff_prompt.md` for details on recent changes and current development focus.

Common development commands:

```bash
# Fetch dependencies
mix deps.get

# Run the full test suite
mix test

# Run static analysis (Credo for style, Dialyzer for types)
mix credo
mix dialyzer

# Compile with warnings as errors (strict check)
mix compile --warnings-as-errors

# Format code
mix format
```

We also provide a range of helper scripts for various development tasks, including:

- Running different test suites (integration, platform-specific, visualization, etc.)
- Performing code quality and pre-commit checks
- Managing database setup and diagnostics
- Building releases
- Simulating CI/CD workflows locally

[Scripts Documentation](scripts/README.md).

### GitHub Actions

See [GitHub Actions README](.github/workflows/README.md) for detailed instructions...

## Project Structure

- `/assets` - Source files for web assets (CSS/Sass, JS, potentially themes in `/assets/themes`) processed by build tools (esbuild, sass, tailwind). Compiled output goes to `/priv/static`.
- `/docker` - Docker configurations (e.g., for local testing with `act`)
- `/docs` - User documentation (guides, development notes, architecture)
- `/examples` - Example applications and code samples
- `/extensions` - IDE integrations and extensions (e.g., VS Code)
- `/lib` - Core Elixir code (`raxol/core`, `raxol/ui`, `raxol/terminal`, `raxol/view`, etc.)
- `/priv` - Non-source code assets (e.g., compiled static files in `priv/static`, terminal themes in `priv/themes`, plugins, repo seeds)
- `/scripts` - Helper scripts for development tasks

## License

MIT License - see [LICENSE](LICENSE.md) file for details.
