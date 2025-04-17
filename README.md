# Raxol

High-performance terminal emulator with VS Code integration.

> **Note:** Pre-release software. APIs may change before v1.0.

## Features

- **Terminal:** ANSI processing, platform detection, color/Unicode support
- **Components:** Widgets, visualization, flexible layouts
- **Plugins:** Notifications, clipboard, visualization tools
- **VS Code:** Extension for in-editor integration
- **Performance:** Double buffering, memory optimization, virtual scrolling

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
```

## Development

```bash
mix test                  # Run tests
mix credo                 # Code quality
mix dialyzer              # Type checking
mix ecto.setup            # Setup database
```

## Project Structure

- `/examples` - Example applications and code samples
- `/extensions` - IDE integrations and extensions
- `/frontend` - JavaScript/TypeScript configurations and assets
- `/lib` - Core Elixir code
- `/priv` - Non-source code assets

## License

MIT License - see [LICENSE](LICENSE) file for details.
