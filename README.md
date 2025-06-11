# Raxol

[![Hex pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![GitHub Actions CI](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml)

**Raxol** is a modern toolkit for building interactive terminal (TUI) applications in Elixir.
It offers a powerful component system, a flexible runtime, and a robust plugin architecture—making it easy to create beautiful, responsive terminal UIs.

> **Note:** Raxol is in active development (pre-release).
> APIs will change as we improve the toolkit.

## ✨ Features

- **Component Model:** Build UIs from reusable, stateful components with full lifecycle support
- **Declarative View DSL:** Compose layouts with expressive macros (`panel`, `row`, `column`, `text`, etc.)
- **Advanced Terminal Features:** Full ANSI/Sixel support, scrollback, and efficient buffer management
- **Plugin System:** Extend Raxol with hot-reloadable plugins and robust error handling
- **Performance Optimized:** Event processing < 1ms, screen updates < 2ms, concurrent ops < 5ms
- **Comprehensive Testing:** 1528 tests with event-based synchronization and performance benchmarks
- **Modern Architecture:** Layered design with clear separation of concerns and modular subsystems

## 🚀 Get Started

Add Raxol to your `mix.exs`:

```elixir
def deps do
  [
    {:raxol, "~> 0.4.0"}
  ]
end
```

## 📚 Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Component Guide](examples/guides/03_components_and_layout/components/README.md)
- [Plugin Development](examples/guides/04_extending_raxol/plugin_development.md)
- [Testing Guide](examples/guides/05_development_and_testing/testing.md)
- [Migration Guide](docs/MIGRATION_GUIDE.md)

## 🛠️ Example: A Simple Counter App

```elixir
# Starts ExUnit and runs the app
defmodule ExampleApp do
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

ExampleApp.start()
```

## 🗂️ Key Links

- [Changelog](CHANGELOG.md)
- [Migration Guide](docs/MIGRATION_GUIDE.md)
- [Examples](examples/)
- [Subsystem Docs](docs/README.md)

## 📦 Static Assets

All static assets (JavaScript, CSS, images, etc.) are in `priv/static/@static`.

- Use `/@static/` as the path prefix in templates and code.
- The asset pipeline (npm, bundlers, etc.) should be run from `priv/static/@static`.

## 🚦 Performance Requirements

- **Event processing:** < 1ms average, < 2ms (95th percentile)
- **Screen updates:** < 2ms average, < 5ms (95th percentile)
- **Concurrent operations:** < 5ms average, < 10ms (95th percentile)

## 🧭 How to Navigate

- New to Raxol? Start with the [Getting Started Guide](examples/guides/01_getting_started/).
- For a high-level overview, see [Architecture](docs/ARCHITECTURE.md).
- Explore the links above for in-depth guides and references.

---
