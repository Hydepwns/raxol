# Raxol

[![CI](https://github.com/Hydepwns/raxol/actions/workflows/ci-unified.yml/badge.svg?branch=master)](https://github.com/Hydepwns/raxol/actions/workflows/ci-unified.yml)
[![Security](https://github.com/Hydepwns/raxol/actions/workflows/security.yml/badge.svg?branch=master)](https://github.com/Hydepwns/raxol/actions/workflows/security.yml)
[![Coverage](https://img.shields.io/badge/coverage-98.7%25-brightgreen.svg)](https://codecov.io/gh/Hydepwns/raxol)
[![Performance](https://img.shields.io/badge/parser-3.3μs%2Fseq-brightgreen.svg)](bench/README.md)
[![Hex.pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/raxol)

A terminal application framework for Elixir.

Raxol started as a terminal interface for AGI -- the kind of cockpit UI you'd build into a Gundam. We needed something that could render fast, compose like React, survive process crashes via OTP supervision, and run the same app over SSH, in a browser, or on bare metal. Nothing in the Elixir ecosystem did that, so we built it.

It supports four UI paradigms (React, LiveView, HEEx, Raw), runs on all major platforms, and the same application code can render to a terminal or a Phoenix LiveView -- no rewrite needed.

## Quick Start

See the [Quickstart Tutorial](docs/getting-started/QUICKSTART.md), or just run the counter example:

```bash
git clone --recursive https://github.com/Hydepwns/raxol.git
cd raxol
mix deps.get
mix run examples/getting_started/counter.exs
```

Pick your framework:

```elixir
use Raxol.UI, framework: :react      # React-style components with TEA (init/update/view)
use Raxol.UI, framework: :liveview   # Phoenix LiveView patterns
use Raxol.UI, framework: :heex       # Phoenix templates
use Raxol.UI, framework: :raw        # Direct terminal control
```

A basic app uses TEA (The Elm Architecture) -- `init/update/view`:

```elixir
defmodule MyApp do
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context), do: %{count: 0}

  @impl true
  def update(message, model) do
    case message do
      :increment -> {%{model | count: model.count + 1}, []}
      _ -> {model, []}
    end
  end

  @impl true
  def view(model) do
    column style: %{padding: 1, gap: 1} do
      [
        text("Count: #{model.count}", style: [:bold]),
        button("Increment", on_click: :increment)
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []
end

Raxol.start_link(MyApp, [])
```

[More examples](examples/)

## Platform Support

Backend selection is automatic:

- **Unix/macOS** -- Native termbox2 NIF (~50us per frame)
- **Windows 10+** -- Pure Elixir driver via OTP 28+ raw mode (~500us per frame)

Windows uses VT100 terminal emulation, enabled by default. No extra setup.

## Packages

Available as focused packages or as the full framework:

- **[raxol_core](https://hex.pm/packages/raxol_core)** -- Buffer primitives (< 100KB, zero deps)
- **[raxol_liveview](https://hex.pm/packages/raxol_liveview)** -- Phoenix LiveView integration
- **[raxol_plugin](https://hex.pm/packages/raxol_plugin)** -- Plugin system
- **raxol** -- Everything

See the [Package Guide](docs/getting-started/PACKAGES.md) for details.

## Components-Only Mode

Import with `runtime: false` and you get the UI layer without the terminal runtime -- all the framework adapters, components (Button, Input, Table, Modal, etc.), state management, animations, and theming. No terminal emulator, no ANSI processing, no PTY management. Useful if you just want the component library for a web app.

## Architecture

The terminal layer handles VT100/ANSI compliance, Sixel graphics, mouse support, tab completion, and command history. The UI system gives you component composition, theming, and a 60 FPS animation engine. OTP supervision means a crash in one component doesn't take down the app.

The thing that makes Raxol different from Ratatui or Bubble Tea: a single app can render to a terminal AND a browser via the LiveView bridge. Deploy to SSH and web from one codebase. Erlang's built-in `:ssh` module means you can serve TUI apps over SSH with zero client requirements.

See [Architecture docs](docs/core/ARCHITECTURE.md) for internals.

## Performance

Parser operations run at 3.3us/sequence. See [Benchmark Docs](docs/bench/README.md).

## Documentation

**Getting Started** -- [Quickstart](docs/getting-started/QUICKSTART.md) | [Core Concepts](docs/getting-started/CORE_CONCEPTS.md) | [Migration Guide](docs/getting-started/MIGRATION_FROM_DIY.md)

**Cookbooks** -- [LiveView Integration](docs/cookbook/LIVEVIEW_INTEGRATION.md) | [Performance](docs/cookbook/PERFORMANCE_OPTIMIZATION.md) | [Theming](docs/cookbook/THEMING.md)

**Features** -- [VIM Navigation](docs/features/VIM_NAVIGATION.md) | [Command Parser](docs/features/COMMAND_PARSER.md) | [Fuzzy Search](docs/features/FUZZY_SEARCH.md) | [Virtual Filesystem](docs/features/FILESYSTEM.md) | [Cursor Effects](docs/features/CURSOR_EFFECTS.md) | [Overview](docs/features/README.md)

**API** -- [Buffer API](docs/core/BUFFER_API.md) | [Architecture](docs/core/ARCHITECTURE.md) | [Full API Reference](https://hexdocs.pm/raxol)

## Development Setup

```bash
git clone --recursive https://github.com/Hydepwns/raxol.git
cd raxol
mix deps.get
MIX_ENV=test mix compile
MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker
```

Already cloned without `--recursive`? Initialize the termbox2 submodule:

```bash
git submodule update --init --recursive
```

## VS Code Extension

Dev version in `editors/vscode/`:

```bash
cd editors/vscode && npm install && npm run compile && code --install-extension .
```

Gives you syntax highlighting, IntelliSense, component snippets, and live preview.

## Roadmap

What's next: Svelte framework support, WebGL-style terminal rendering, multi-session collaboration, a plugin marketplace, and mobile terminal clients. See [ROADMAP.md](ROADMAP.md).

## License

MIT -- see [LICENSE.md](LICENSE.md)
