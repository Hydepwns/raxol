# Raxol

A terminal application toolkit for Elixir, providing components and a runtime for building interactive TUI applications.

> **Note:** Pre-release software. APIs may change before v1.0.

## Features

- **ANSI Terminal Emulation:** Robust handling of ANSI escape codes, colors, and Unicode characters.
- **Component Model:** Build UIs with reusable components inspired by web frameworks.
- **Layout System:** Flexible layouts for arranging components within the terminal window.
- **Performance:** Optimized rendering pipeline with double buffering and efficient updates.
- **Extensibility:** (Add details about plugins or extension points if applicable)

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

For detailed installation options and requirements, see the [Installation Guide](docs/installation.md).

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

# Start the application
{:ok, _pid} = Raxol.Runtime.start_link(app: MyApp)

# Keep the application running (e.g., in an IEx session or supervisor)
# ...
```

For a more comprehensive guide, please refer to the [Getting Started Tutorial](docs/getting_started.md).

## Documentation

Detailed documentation can be found in the `/docs` directory:

- [Installation Guide](docs/installation.md)
- [Getting Started Tutorial](docs/getting_started.md)
- [Terminal Emulator Details](docs/terminal_emulator.md)
- [Core Concepts](docs/concepts/README.md) (Planned)
- [Components](docs/components/README.md) (Planned)
- (Add link to ExDoc API reference when available)

## Development

```bash
# Ensure dependencies are installed
mix deps.get
mix compile

# Run tests
mix test

# Run static analysis
mix credo
mix dialyzer

# Run tests locally without GitHub Actions (if applicable)
# ./scripts/run-local-tests.sh

# Format code before committing
mix format # Or ./scripts/format_before_commit.sh
```

### GitHub Actions

(Keep existing GitHub Actions section if still relevant)
See [GitHub Actions README](.github/workflows/README.md) for detailed instructions...

## Project Structure

(Keep existing Project Structure section, review later if needed)

- `/examples` - Example applications and code samples
- `/extensions` - IDE integrations and extensions (Review if still accurate)
- `/frontend` - JavaScript/TypeScript configurations and assets (Review if still accurate)
- `/lib` - Core Elixir code
- `/priv` - Non-source code assets
- `/docs` - User documentation

## License

MIT License - see [LICENSE](LICENSE.md) file for details.
