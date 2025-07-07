---
title: Raxol Library Documentation
description: Documentation for using the Raxol TUI library in Elixir projects
date: 2025-01-27
author: Raxol Team
section: overview
tags: [documentation, overview, library, tui, elixir]
---

# 📚 Raxol Documentation

Welcome! This is your starting point for all things Raxol—a modern toolkit for building terminal user interfaces (TUIs) in Elixir. Raxol provides a comprehensive set of components, styling options, and event handling for creating interactive terminal applications.

## 🗂️ Key Sections

- [Architecture](ARCHITECTURE.md): System overview and design principles
- [Configuration](CONFIGURATION.md): Configuration management and settings
- [UI Components & Layout Guide](../examples/guides/03_components_and_layout/components/README.md): Built-in components and layout system
- [Examples](../examples/): Runnable demos and code snippets
- [CHANGELOG](../CHANGELOG.md): Version history and updates

## Core Subsystems

- **Core**: Application lifecycle and state management
- **Terminal**: Low-level terminal I/O and buffer management
- **UI**: Component system and layout management
- **Renderer**: View composition and rendering
- **Plugins**: Extensible plugin architecture
- **Style**: Rich text formatting and styling system

## Quick Start

```elixir
defmodule MyApp do
  use Raxol.Core.Runtime.Application

  def init(_opts), do: %{count: 0}

  def update(:increment, model), do: {%{model | count: model.count + 1}, []}
  def update(:decrement, model), do: {%{model | count: model.count - 1}, []}

  def view(model) do
    ~H"""
    <box border="single" padding="1">
      <text color="cyan" bold="true">Count: <%= model.count %></text>
      <row gap="1">
        <button label="-" on_click=":decrement" />
        <button label="+" on_click=":increment" />
      </row>
    </box>
    """
  end
end

# Start the application
{:ok, _pid} = Raxol.Core.start_application(MyApp)
```

## 🚦 Performance Requirements

Raxol is built for speed and reliability with strict performance standards:

- **Event processing**: < 1ms average
- **Screen updates**: < 2ms average
- **Concurrent operations**: < 5ms average

## 📦 Static Assets

Static assets (JavaScript, CSS, images) are located in `priv/static/@static/`.

- Add or update frontend assets in the `@static` folder
- Run asset pipeline from `priv/static/@static/`
- Reference static files with `/@static/` path prefix

## 🧭 How to Navigate

- **New to Raxol?** Start with the [Quick Start Guide](../examples/guides/01_getting_started/quick_start.md)
- **Architecture overview**: See [Architecture](ARCHITECTURE.md)
- **Configuration**: See [Configuration Guide](CONFIGURATION.md)
- **Components**: Explore [UI Components Guide](../examples/guides/03_components_and_layout/components/README.md)
- **Examples**: Check out [Examples](../examples/) for working code

## 📖 Additional Resources

- [API Reference](../examples/guides/02_core_concepts/api/README.md)
- [Plugin Development](../examples/guides/04_extending_raxol/plugin_development.md)
- [Testing Guide](../examples/guides/05_development_and_testing/testing.md)
- [Snippets](../examples/snippets/README.md)

Happy building!
