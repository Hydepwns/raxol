---
title: Quick Start Guide
description: Create your first Raxol application
date: 2025-04-27
author: Raxol Team
section: guides
tags: [quick start, guide, tutorial, application, components]
---

# Quick Start Guide: Your First Raxol App

This guide walks you through creating a simple stateful counter application using Raxol, a modern, feature-rich toolkit for building sophisticated terminal user interfaces (TUIs) in Elixir. You'll learn how to use Raxol's comprehensive set of components, styling options, and event handling to create an interactive terminal application with rich text formatting and dynamic UI updates.

## Prerequisites

Before you start, ensure you have:

1. **Elixir installed:** Raxol requires Elixir 1.14 or later. You can find installation instructions on the [official Elixir website](https://elixir-lang.org/install.html).
2. **A new Mix project (optional):** If you don't have a project, create one:

   ```bash
   mix new my_raxol_app
   cd my_raxol_app
   ```

## 1. Add Raxol Dependency

First, add `raxol` to your project's dependencies. Open your `mix.exs` file and update the `deps` function:

```elixir
def deps do
  [
    {:raxol, "~> 0.4.2"}
  ]
end
```

Then, fetch the dependency:

```bash
mix deps.get
```

## 2. Create Your Application Module

Create a new Elixir file, for example, `lib/my_raxol_app/application.ex`, and define your application module. This module will use `Raxol.Core.Runtime.Application` and implement the required callbacks to define the user interface.

Raxol offers two primary ways to define your UI:

### Method 1: Using the HEEx Sigil (`~H`)

This approach uses a syntax similar to HTML and is often convenient for static structures or when integrating with HEEx templates.

```elixir
defmodule MyRaxolApp.Application do
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context), do: %{count: 0}

  @impl true
  def update(:increment, state), do: %{state | count: state.count + 1}
  def update(_, state), do: state

  @impl true
  def render(assigns) do
    ~H"""
    <box border="single" padding="1">
      <text color="cyan" bold="true">Count: <%= @count %></text>
      <button label="Increment" on_click=":increment"/>
    </box>
    """
  end
end
```

### Method 2: Using `Raxol.View` and Component Functions

This approach uses standard Elixir function calls for components, providing more flexibility for programmatically building complex UIs.

```elixir
defmodule MyRaxolApp.Application do
  use Raxol.Core.Runtime.Application
  use Raxol.View
  import Raxol.View.Elements

  @impl true
  def init(_context), do: %{count: 0}

  @impl true
  def update(:increment, state), do: %{state | count: state.count + 1}
  def update(_, state), do: state

  @impl true
  def render(assigns) do
    view do
      box border: :single, padding: 1 do
        text content: "Count: #{assigns.count}", color: :cyan, attributes: [:bold]
        button label: "Increment", on_click: :increment
      end
    end
  end
end
```

## 3. Understanding the Callbacks

Raxol applications use a set of callbacks to manage state and handle user interactions:

- `init/1`: Called when the application starts, returns the initial state
- `update/2`: Handles messages (like button clicks) and updates the state
- `render/1`: Defines the UI based on the current state
- `handle_event/3`: (Optional) Handles raw input events like keyboard or mouse

## 4. Start the Application

To run your application, you can start it directly in `iex`:

```elixir
iex> Raxol.Core.Runtime.Lifecycle.start_application(MyRaxolApp.Application)
{:ok, #PID<0.xxx.0>}
```

For long-running applications, add it to your supervision tree:

```elixir
defmodule MyRaxolApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Raxol.Core.Runtime.Application, app: MyRaxolApp.Application}
    ]

    opts = [strategy: :one_for_one, name: MyRaxolApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Make sure `MyRaxolApp.Application` is listed in your `application/0` function in `mix.exs`:

```elixir
def application do
  [
    extra_applications: [:logger],
    mod: {MyRaxolApp.Application, []}
  ]
end
```

## Next Steps

Congratulations! You've built and run your first Raxol application. Here's what you can explore next:

- [Components & Layout](03_components_and_layout/components/README.md) - Learn about available components and layout options
- [Examples](../) - Check out sample applications and use cases
- [Installation Guide](install.md) - Learn about platform-specific considerations
