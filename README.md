# Raxol

High-performance terminal emulator with VS Code integration.

> **Note:** Pre-release software. APIs may change before v1.0.

## Features

- **Terminal:** ANSI processing, platform detection, color/Unicode support
- **Components:** Widgets, visualization, flexible layouts
- **Plugins:** Notifications, clipboard, visualization tools
- **VS Code:** Extension for in-editor integration
- **Performance:** Double buffering, memory optimization, virtual scrolling, visualization caching (5,000-15,000x speedup)
- **Dashboard:** Flexible layout system with drag-and-drop widgets and persistence
- **Visualization:** Charts and TreeMaps with optimized rendering for large datasets

## Install

### Terminal

```bash
git clone https://github.com/Hydepwns/raxol.git
cd raxol
mix deps.get
mix compile
mix run --no-halt
```

### VS Code Extension

```bash
cd extensions/vscode
npm install
npm run build
# Press F5 in VS Code or run: code --install-extension raxol-*.vsix
# Or press Command + Shift + P -> Install from VSIX -> raxol-*.vsix
```

## Usage

```elixir
# Start terminal
{:ok, terminal} = Raxol.Runtime.start_link(width: 80, height: 24)

# Create widget
defmodule MyWidget do
  use Raxol.Component
  def render(assigns) do
    ~H"""
    <box title="Widget"><text>Content</text></box>
    """
  end
end

# Create a visualization
MyDashboard.add_chart("Sales", %{
  data: sales_data,
  type: :bar,
  options: %{show_labels: true}
})
```

## Development

```bash
mix test                  # Run tests
mix credo                 # Code quality
mix dialyzer              # Type checking
mix ecto.setup            # Setup database
./scripts/run-local-tests.sh  # Run tests locally without GitHub Actions
```

### Code Formatting

To ensure your code is properly formatted before committing, run the following script:

```bash
./scripts/format_before_commit.sh
```

This will run `mix format` on all Elixir files in the project, ensuring that your code passes the CI format check.

### GitHub Actions

To run GitHub Actions workflows locally for testing:

```bash
# Run with default settings (CI workflow)
./scripts/run-local-actions.sh

# Run a specific workflow (e.g., simplified dummy test)
./scripts/run-local-actions.sh -w dummy-test.yml -j test
```

See [GitHub Actions README](.github/workflows/README.md) for detailed instructions on:

- Running workflows locally with `act`
- Troubleshooting common issues
- Testing on different platforms
- Setting up custom Docker images for ARM Macs

## Project Structure

- `/examples` - Example applications and code samples
- `/extensions` - IDE integrations and extensions
- `/frontend` - JavaScript/TypeScript configurations and assets
- `/lib` - Core Elixir code
- `/priv` - Non-source code assets

## License

MIT License - see [LICENSE](LICENSE.md) file for details.
