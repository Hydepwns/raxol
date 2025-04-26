# Raxol

[![Hex pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)
[![GitHub Actions CI](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml)

A terminal application toolkit for Elixir, providing components and a runtime for building interactive TUI applications.

> **Note:** Pre-release software. APIs may change before v2.0 as the codebase undergoes active refactoring and feature additions, particularly in the core runtime and terminal emulation layers.

<!-- TODO: Add a screenshot or GIF demo here -->

## Features

- **ANSI Terminal Emulation:** Robust handling of ANSI escape codes, colors, and Unicode characters.
- **Component Model:** Build UIs with reusable components inspired by web frameworks.
- **Layout System:** Flexible layouts for arranging components within the terminal window.
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

For detailed installation options and requirements, see the [Installation Guide](docs/installation/Installation.md).

## Getting Started

Here's a basic example of a Raxol application:

```elixir
defmodule MyApp do
  use Raxol.App

  @impl true
  def render(assigns) do
    ~H"""
    <box border="single">
      <text>Hello, Raxol!</text>
    </box>
    """
  end
end

# Start the application using the new Lifecycle module
Raxol.Core.Runtime.Lifecycle.start_application(MyApp)

# Keep the application running (e.g., in an IEx session or supervisor)
```

> **Note:** Use `Raxol.App` for the main application entry point and `Raxol.View` for reusable UI components. Raxol also supports nested component functions (e.g., `box do ... end`). See the examples in `/examples` and the [Getting Started Tutorial](docs/guides/quick_start.md) for more details on both approaches.

For a more comprehensive guide, please refer to the [Getting Started Tutorial](docs/guides/quick_start.md).

Explore the `/examples` directory for more detailed usage patterns and advanced features.

## Documentation

Detailed documentation can be found in the `/docs` directory or online (TODO: Add the hosted documentation link here):

- [Architecture Overview](docs/ARCHITECTURE.md) - Learn about the reorganized codebase structure
- [Using Raxol (Installation Guide)](docs/installation/Installation.md)
- [Getting Started Tutorial](docs/guides/quick_start.md)
- [UI Components & Layout](docs/guides/components.md)
- [Async Operations (Subscriptions & Commands)](docs/guides/async_operations.md)
- [Runtime Options](docs/guides/runtime_options.md)
- [Terminal Emulator Details](docs/terminal_emulator.md)
- [Development Environment Setup](docs/installation/DevelopmentSetup.md)
- [Cross-Platform Support](docs/installation/CrossPlatformSupport.md)
- [Version Management](docs/installation/VersionManagement.md)

## Development

To set up your development environment, please see the [Development Environment Setup](docs/installation/DevelopmentSetup.md) guide.

> **Note:** The project is currently undergoing significant refactoring based on the plan outlined in `docs/archive/REORGANIZATION_PLAN.md`. See `CHANGELOG.md` and `docs/planning/handoff_prompt.md` for recent changes.

Common development commands:

```bash
# Run the full test suite
mix test

# Run static analysis (Credo for style, Dialyzer for types)
mix credo
mix dialyzer

# Format code
mix format
```

We also provide a range of helper scripts for various development tasks, including:

- Running different test suites (integration, platform-specific, visualization, etc.)
- Performing code quality and pre-commit checks
- Managing database setup and diagnostics
- Building releases
- Simulating CI/CD workflows locally

For detailed information on all available scripts and their usage, please refer to the [Scripts Documentation](scripts/README.md).

### GitHub Actions

See [GitHub Actions README](.github/workflows/README.md) for detailed instructions...

## Project Structure

- `/assets` - Static assets (e.g., images, fonts)
- `/docker` - Docker configurations (e.g., for local testing with `act`)
- `/docs` - User documentation
- `/examples` - Example applications and code samples
- `/extensions` - IDE integrations and extensions (e.g., VS Code)
- `/frontend` - Frontend JavaScript/TypeScript configurations and assets
- `/lib` - Core Elixir code (includes `core/runtime`, `terminal`, `ui`, etc.)
- `/pages` - In-depth documentation/articles (e.g., for site generation)
- `/priv` - Non-source code assets (e.g., templates, static files for releases)
- `/scripts` - Helper scripts for development tasks
- `/themes` - Theme definitions for styling

## License

MIT License - see [LICENSE](LICENSE.md) file for details.
