---
title: Quick Start Guide
description: Create your first Raxol application
date: 2025-07-26 # Or use a dynamic date if possible
author: DROO AMOR
section: guides
tags: [quick start, guide, tutorial, Raxol.App]
---

# Quick Start Guide: Your First Raxol App

This guide walks you through creating a simple "Hello, World!" terminal application using Raxol.

## Prerequisites

Before you start, ensure you have:

1.  **Elixir installed:** Raxol requires Elixir. You can find installation instructions on the [official Elixir website](https://elixir-lang.org/install.html).
2.  **A new Mix project (optional):** If you don't have a project, create one:
    ```bash
    mix new my_raxol_app
    cd my_raxol_app
    ```

## 1. Add Raxol Dependency

First, add `raxol` to your project's dependencies. Open your `mix.exs` file and update the `deps` function:

```elixir
def deps do
  [
    {:raxol, "~> 0.1.0"}
    # Or {:raxol, github: "Hydepwns/raxol"} for the latest code
  ]
end
```

Then, fetch the dependency:

```bash
mix deps.get
```

For more details, see the [Installation Guide](../installation/Installation.md).

## 2. Create Your Application Module

Create a new Elixir file, for example, `lib/my_raxol_app/application.ex`, and define your application module. This module will use `Raxol.App` and implement the `render/1` callback.

```elixir
defmodule MyRaxolApp.Application do
  use Raxol.App

  # The render/1 callback defines the UI.
  # It receives assigns (data) and must return rendered content.
  @impl true
  def render(assigns) do
    ~H"""
    <box border="single" padding="1">
      <text color="cyan" bold="true">Hello, Raxol!</text>
    </box>
    """
  end
end
```

- `use Raxol.App`: Imports necessary functions and defines the behaviour for a Raxol application.
- `@impl true def render(assigns)`: Implements the required callback to define the UI structure.
- `~H""" ... """`: This is a HEEx sigil used to define the component-based UI. Here, we have a `<box>` containing a `<text>` element.

## 3. Start the Application

To run your application, you need to start the Raxol runtime, passing your application module.

You can do this directly in an IEx session or as part of your application's supervision tree.

**Running in IEx:**

Start an IEx session within your project:

```bash
iex -S mix
```

Inside IEx, start the runtime:

```elixir
iex> {:ok, _pid} = Raxol.Runtime.start_link(app: MyRaxolApp.Application)
```

Your terminal should clear and display the box with "Hello, Raxol!". Press `Ctrl+C` twice to exit IEx and stop the application.

**Adding to a Supervisor (More Robust):**

For long-running applications, you'll typically add the `Raxol.Runtime` to your application's supervision tree (e.g., in `lib/my_raxol_app/application.ex` if you used `mix new --sup`):

```elixir
defmodule MyRaxolApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Raxol Runtime
      {Raxol.Runtime, app: MyRaxolApp.Application} # Use the module defined in step 2
      # ... other children
    ]

    opts = [strategy: :one_for_one, name: MyRaxolApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Make sure `MyRaxolApp.Application` is listed in your `mix.exs` `application/0` function.

## Next Steps

Congratulations! You've built and run your first Raxol application.

- Explore the different built-in [Components](docs/components/README.md) (Planned).
- Learn about [Core Concepts](docs/concepts/README.md) like state management and event handling (Planned).
- Check out the `/examples` directory in the Raxol repository for more advanced use cases.
