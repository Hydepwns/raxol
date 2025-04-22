# Raxol

A terminal application toolkit for Elixir, providing components and a runtime for building interactive TUI applications.

> **Note:** Pre-release software. APIs may change before v1.0.

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
    {:raxol, "~> 0.1.0"} # Or use {:raxol, github: "Hydepwns/raxol"} for development
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

````elixir
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

# Start the application
{:ok, _pid} = Raxol.Runtime.start_link(app: MyApp)

# Keep the application running (e.g., in an IEx session or supervisor)
# ...

> **Note:** Raxol also supports defining views using `use Raxol.View` and nested component functions (e.g., `box do ... end`). See the examples in `/examples` and the [Getting Started Tutorial](docs/guides/quick_start.md) for more details on both approaches.

For a more comprehensive guide, please refer to the [Getting Started Tutorial](docs/guides/quick_start.md).

## Documentation

Detailed documentation can be found in the `/docs` directory or online (TODO: Add link):

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

Basic development commands:

```bash
# Ensure dependencies are installed (after setup)
# mix deps.get # Handled in setup guide
# mix compile # Handled in setup guide

# Run tests
mix test

# Run static analysis
mix credo
mix dialyzer

# Format code before committing
mix format # Or ./scripts/format_before_commit.sh
````

### GitHub Actions

See [GitHub Actions README](.github/workflows/README.md) for detailed instructions...

## Project Structure

- `/assets` - Static assets (e.g., images, fonts)
- `/docker` - Docker configurations (e.g., for local testing with `act`)
- `/docs` - User documentation
- `/examples` - Example applications and code samples
- `/extensions` - IDE integrations and extensions (e.g., VS Code)
- `/frontend` - Frontend JavaScript/TypeScript configurations and assets
- `/lib` - Core Elixir code
- `/pages` - Application pages or site content (Verify description)
- `/priv` - Non-source code assets (e.g., templates, static files for releases)
- `/scripts` - Helper scripts for development tasks
- `/themes` - Theme definitions for styling

## License

MIT License - see [LICENSE](LICENSE.md) file for details.
