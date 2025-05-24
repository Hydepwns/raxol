---
title: Quick Start Guide
description: Create your first Raxol application
date: 2025-04-27
author: Raxol Team
section: guides
tags: [quick start, guide, tutorial, application, components]
---

# Quick Start Guide: Your First Raxol App

This guide walks you through creating a simple stateful counter application using Raxol.

## Prerequisites

Before you start, ensure you have:

1. **Elixir installed:** Raxol requires Elixir. You can find installation instructions on the [official Elixir website](https://elixir-lang.org/install.html).
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
    {:raxol, "~> 0.1.0"}
    # Or {:raxol, github: "Hydepwns/raxol"} for the latest code
  ]
end
```

Then, fetch the dependency:

```bash
mix deps.get
```

## 2. Create Your Application Module

Create a new Elixir file, for example, `lib/my_raxol_app/application.ex`, and define your application module. This module will use `Raxol.Core.Runtime.Application` and implement the `render/1` callback to define the user interface.

Raxol offers two primary ways to define your UI within the `render/1` function:

**Method 1: Using the HEEx Sigil (`~H`)**

This approach uses a syntax similar to HTML and is often convenient for static structures or when integrating with HEEx templates.

```elixir
# lib/my_raxol_app/application.ex
defmodule MyRaxolApp.Application do
  use Raxol.Core.Runtime.Application

  # The render/1 callback defines the UI.
  # It receives assigns (data) and must return rendered content.
  @impl true
  def render(assigns) do
    ~H"""
    <box border="single" padding="1">
      <text color="cyan" bold="true">Hello from HEEx!</text>
    </box>
    """
  end
end
```

- `use Raxol.Core.Runtime.Application`: Imports necessary functions and defines the behaviour for a Raxol application.
- `@impl true def render(assigns)`: Implements the required callback to define the UI structure.
- `~H""" ... """`: The HEEx sigil defines the component-based UI using HTML-like tags.

**Method 2: Using `Raxol.View` and Component Functions**

This approach uses standard Elixir function calls for components, often providing more flexibility for programmatically building complex UIs. Many examples in the `/examples` directory use this method.

```elixir
# lib/my_raxol_app/application_view.ex
defmodule MyRaxolApp.ApplicationView do
  use Raxol.Core.Runtime.Application
  use Raxol.View # Use Raxol.View for this approach
  import Raxol.View.Elements # Optional: Import elements for cleaner calls

  @impl true
  def render(assigns) do
    # Use the view macro and nested component functions
    view do
      box border: :single, padding: 1 do
        text content: "Hello from Raxol.View!", color: :cyan, attributes: [:bold]
      end
    end
  end
end

```

- `use Raxol.View`: Required to enable the `view` macro and component function syntax.
- `import Raxol.View.Elements`: Allows calling components like `box` and `text` directly, otherwise you might need `Raxol.View.Elements.box(...)`.
- `view do ... end`: A macro block containing nested component function calls (e.g., `box(...)`, `text(...)`). Note that attributes are passed as keyword lists or maps.

Choose the method that best suits your needs or project style. Both achieve the same goal of defining the UI.

## 2.5 Adding State and Interactivity (init, update)

Static UIs are useful, but most terminal applications need to manage state and respond to user input. Raxol handles this using the `init/1` and `update/2` callbacks, inspired by the Elm Architecture.

**1. Initialize State with `init/1`**

The `init/1` callback is called once when the application starts. It should return the initial state of your application.

**2. Handle Messages with `update/2`**

The `update/2` callback is triggered when a message is sent to your application (e.g., from a button click or a subscription). It receives the message and the current state, and returns the _new_ state. Optionally, it can also return a `Command` for executing background tasks (see `examples/advanced/commands.exs`).

**3. Render State in `render/1`**

The `render/1` callback receives the current state (as `assigns`) and uses it to draw the UI.

**Example: A Simple Counter**

Let's modify our application to be a counter. We'll use the `Raxol.View` method here for illustration.

```elixir
# lib/my_raxol_app/counter.ex
defmodule MyRaxolApp.Counter do
  use Raxol.Core.Runtime.Application
  use Raxol.View
  import Raxol.View.Elements

  # 1. Define the initial state
  @impl true
  def init(_context), do: %{count: 0}

  # 2. Handle messages to update the state
  @impl true
  def update(model, message) do
    case message do
      :increment ->
        %{model | count: model.count + 1}
      _ ->
        model # Return the unchanged model for other messages
    end
  end

  # 3. Render the UI based on the current state
  @impl true
  def render(assigns) do
    view do
      box border: :single, padding: 1 do
        # Display the current count from assigns (state)
        text content: "Count: \#{assigns.count}"
        # Add a button that sends the :increment message when clicked
        button label: "Increment", on_click: :increment
      end
    end
  end
end
```

- `init/1` returns the initial state `%{count: 0}`.
- `update/2` handles the `:increment` message by returning a new state map with the count increased.
- `render/1` now uses `assigns.count` to display the value and includes a `<button>` component.
- The `button` has an `on_click: :increment` attribute. When clicked, Raxol sends the `:increment` message to the `update/2` function.

**Subscriptions (`subscribe/1`)**

For handling external events like timers or keyboard events not tied to specific components, you can implement the `subscribe/1` callback. It returns subscriptions that send messages to `update/2`. See `examples/basic/subscriptions.exs` for details.

## 3. Start the Application

To run your application, you can start it directly in `iex` using the new `Lifecycle` module:

```elixir
<iex> Raxol.Core.Runtime.Lifecycle.start_application(MyRaxolApp.Counter)
# {:ok, #PID<0.xxx.0>}
```

For long-running applications, you'll typically add the `Raxol.Core.Runtime.Application` to your application's supervision tree (e.g., in `lib/my_raxol_app/application.ex` if you used `mix new --sup`):

```elixir
defmodule MyRaxolApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Other children...
      {Raxol.Core.Runtime.Application, app: MyRaxolApp.Counter} # Use the module defined previously
    ]

    opts = [strategy: :one_for_one, name: MyRaxolApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Make sure `MyRaxolApp.Application` is listed in your `mix.exs` `application/0` function.

## Next Steps

Congratulations! You've built and run your first Raxol application.

- Check out the `/examples` directory in the Raxol repository for more advanced use cases.
