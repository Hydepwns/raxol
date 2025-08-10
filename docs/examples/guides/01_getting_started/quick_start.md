---
title: Quick Start Guide
description: Create your first Raxol application
date: 2025-04-27
author: Raxol Team
section: guides
tags: [quick start, guide, tutorial, application, components]
---

# Quick Start Guide: Your First Raxol App

This guide walks you through creating your first application using Raxol, a full-stack terminal application framework for Elixir. You'll build a TodoApp that showcases Raxol's component system, state management, and ability to run both in the terminal and through a web browser.

_Raxol 0.9.0 is a comprehensive framework that goes beyond terminal UI—it includes web interfaces, plugins, and enterprise features. This guide will introduce you to all these capabilities!_

## Prerequisites

Before you start, ensure you have:

1. **Development environment set up:** We recommend using the [Nix development environment](../../DEVELOPMENT.md) for the best experience. This provides all necessary dependencies automatically.

2. **Elixir installed (if not using Nix):** Raxol requires Elixir 1.17.1 or later. You can find installation instructions on the [official Elixir website](https://elixir-lang.org/install.html).

3. **A new Mix project (optional):** If you don't have a project, create one:

   ```bash
   mix new my_raxol_app
   cd my_raxol_app
   ```

## 1. Add Raxol Dependency

First, add `raxol` to your project's dependencies. Open your `mix.exs` file and update the `deps` function:

```elixir
def deps do
  [
    {:raxol, "~> 0.9.0"}
  ]
end
```

Then, fetch the dependency:

```bash
mix deps.get
```

## 2. Create a TodoApp Component

Let's create a fully-featured TodoApp that demonstrates Raxol's component system. Create `lib/my_raxol_app/todo_app.ex`:

```elixir
defmodule MyRaxolApp.TodoApp do
  use Raxol.UI.Components.Base.Component

  # Initialize with empty todo list and input
  def init(_props) do
    %{
      todos: [],
      input: "",
      filter: :all  # :all, :active, :completed
    }
  end

  # Handle state updates
  def update({:add_todo}, state) do
    if String.trim(state.input) != "" do
      new_todo = %{
        id: generate_id(),
        text: state.input,
        completed: false,
        created_at: DateTime.utc_now()
      }
      %{state | todos: [new_todo | state.todos], input: ""}
    else
      state
    end
  end

  def update({:toggle_todo, id}, state) do
    todos = Enum.map(state.todos, fn todo ->
      if todo.id == id do
        %{todo | completed: !todo.completed}
      else
        todo
      end
    end)
    %{state | todos: todos}
  end

  def update({:delete_todo, id}, state) do
    %{state | todos: Enum.filter(state.todos, &(&1.id != id))}
  end

  def update({:update_input, value}, state) do
    %{state | input: value}
  end

  def update({:set_filter, filter}, state) do
    %{state | filter: filter}
  end

  def update({:clear_completed}, state) do
    %{state | todos: Enum.filter(state.todos, &(!&1.completed))}
  end

  # Render the UI
  def render(state, _context) do
    filtered_todos = filter_todos(state.todos, state.filter)
    stats = calculate_stats(state.todos)

    {:box, [border: :double, padding: 1],
      [
        # Header
        {:center, [],
          {:text, [color: :cyan, bold: true, size: :large], "✓ Raxol Todo"}
        },
        
        # Input field
        {:box, [padding_top: 1],
          {:input, [
            value: state.input,
            placeholder: "What needs to be done?",
            on_change: {:update_input},
            on_submit: {:add_todo},
            width: :fill
          ]}
        },
        
        # Filter tabs
        {:row, [padding_top: 1, spacing: 2],
          [
            render_filter_button("All", :all, state.filter),
            render_filter_button("Active", :active, state.filter),
            render_filter_button("Completed", :completed, state.filter)
          ]
        },
        
        # Todo list
        {:box, [padding_top: 1, height: 15, scrollable: true],
          if length(filtered_todos) > 0 do
            {:list, [spacing: 1],
              Enum.map(filtered_todos, &render_todo/1)
            }
          else
            {:center, [padding: 3],
              {:text, [color: :gray], "No todos to display"}
            }
          end
        },
        
        # Footer stats
        {:row, [padding_top: 1, justify: :space_between],
          [
            {:text, [color: :gray], "#{stats.active} active"},
            if stats.completed > 0 do
              {:button, [
                label: "Clear completed",
                on_click: {:clear_completed},
                style: :secondary
              ]}
            else
              {:text, [], ""}
            end
          ]
        }
      ]
    }
  end

  # Handle events
  def handle_event({:change, {:update_input}, value}, state, _context) do
    {update({:update_input, value}, state), []}
  end

  def handle_event({:submit, {:add_todo}}, state, _context) do
    {update({:add_todo}, state), []}
  end

  def handle_event({:click, {:toggle_todo, id}}, state, _context) do
    {update({:toggle_todo, id}, state), []}
  end

  def handle_event({:click, {:delete_todo, id}}, state, _context) do
    {update({:delete_todo, id}, state), []}
  end

  def handle_event({:click, {:set_filter, filter}}, state, _context) do
    {update({:set_filter, filter}, state), []}
  end

  def handle_event({:click, {:clear_completed}}, state, _context) do
    {update({:clear_completed}, state), []}
  end

  # Private helpers
  defp render_todo(todo) do
    {:row, [spacing: 1],
      [
        {:checkbox, [
          checked: todo.completed,
          on_change: {:toggle_todo, todo.id}
        ]},
        {:text, [
          strikethrough: todo.completed,
          color: if(todo.completed, do: :gray, else: :white)
        ], todo.text},
        {:button, [
          label: "×",
          on_click: {:delete_todo, todo.id},
          style: :danger,
          size: :small
        ]}
      ]
    }
  end

  defp render_filter_button(label, filter, current_filter) do
    {:button, [
      label: label,
      on_click: {:set_filter, filter},
      style: if(filter == current_filter, do: :primary, else: :secondary)
    ]}
  end

  defp filter_todos(todos, :all), do: todos
  defp filter_todos(todos, :active), do: Enum.filter(todos, &(!&1.completed))
  defp filter_todos(todos, :completed), do: Enum.filter(todos, &(&1.completed))

  defp calculate_stats(todos) do
    %{
      total: length(todos),
      active: Enum.count(todos, &(!&1.completed)),
      completed: Enum.count(todos, &(&1.completed))
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
```

## 3. Running Your App in the Terminal

Create a main application module that uses the TodoApp component. Create `lib/my_raxol_app/application.ex`:

```elixir
defmodule MyRaxolApp.Application do
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context) do
    # Initialize with the TodoApp component
    %{component: MyRaxolApp.TodoApp}
  end

  @impl true
  def render(assigns) do
    # Render the TodoApp component
    {:component, MyRaxolApp.TodoApp, %{}}
  end
end
```

Now start your application in the terminal:

```bash
# In your project directory
iex -S mix

# In the IEx shell
iex> Raxol.Core.Runtime.Lifecycle.start_application(MyRaxolApp.Application)
{:ok, #PID<0.xxx.0>}
```

You should see your TodoApp running in the terminal! Use keyboard navigation:
- `Tab` to move between elements
- `Enter` to add todos or click buttons
- `Space` to toggle checkboxes
- Arrow keys to navigate the list

## 4. Access Your App via Web Browser

One of Raxol's most powerful features is the ability to access your terminal application through a web browser. Let's set that up:

### Step 1: Configure Phoenix

Update your `config/config.exs`:

```elixir
config :my_raxol_app, MyRaxolAppWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "your-secret-key-base",
  render_errors: [view: MyRaxolAppWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: MyRaxolApp.PubSub,
  live_view: [signing_salt: "your-signing-salt"]

config :raxol,
  terminal: [
    scrollback_lines: 1000,
    default_width: 80,
    default_height: 24
  ]
```

### Step 2: Add Web Dependencies

Update your `mix.exs`:

```elixir
defp deps do
  [
    {:raxol, "~> 0.9.0"},
    {:phoenix, "~> 1.7"},
    {:phoenix_live_view, "~> 0.20"},
    {:plug_cowboy, "~> 2.5"}
  ]
end
```

### Step 3: Start the Web Server

```bash
# Start Phoenix server
mix phx.server

# Visit http://localhost:4000
```

Your TodoApp is now accessible via web browser with:
- Real-time synchronization
- Multiple user support
- Persistent sessions
- Full keyboard and mouse support

## 5. Adding a Plugin

Let's create a simple plugin that adds todo statistics. Create `lib/my_raxol_app/stats_plugin.ex`:

```elixir
defmodule MyRaxolApp.StatsPlugin do
  use Raxol.Plugin

  def init(config) do
    {:ok, %{config: config, start_time: DateTime.utc_now()}}
  end

  def commands do
    [
      {"stats", &show_stats/2, "Show todo statistics"},
      {"export", &export_todos/2, "Export todos to JSON"}
    ]
  end

  defp show_stats(_args, state) do
    # Access the TodoApp state
    {:ok, app_state} = Raxol.Core.Runtime.get_app_state()
    todos = app_state.todos
    
    stats = """
    Todo Statistics:
    ----------------
    Total todos: #{length(todos)}
    Completed: #{Enum.count(todos, & &1.completed)}
    Active: #{Enum.count(todos, & !&1.completed)}
    Session started: #{state.start_time}
    """
    
    {:ok, stats, state}
  end

  defp export_todos(_args, state) do
    {:ok, app_state} = Raxol.Core.Runtime.get_app_state()
    json = Jason.encode!(app_state.todos, pretty: true)
    File.write!("todos_export.json", json)
    
    {:ok, "Todos exported to todos_export.json", state}
  end
end

# Load the plugin
Raxol.Core.Runtime.Plugins.Manager.load_plugin_by_module(MyRaxolApp.StatsPlugin)
```

Now you can use `:stats` and `:export` commands in your terminal!

## 6. Key Concepts Covered

In this guide, you've learned:

1. **Component System**: How to build reusable UI components with state management
2. **Event Handling**: Processing user input and updating state
3. **Terminal Rendering**: Running applications in the terminal with rich UI
4. **Web Interface**: Accessing terminal apps through a web browser
5. **Plugin System**: Extending functionality with custom commands

## Next Steps

Congratulations! You've built a full-featured application using Raxol. Here's what to explore next:

### Learn More
- [Component Reference](../03_component_reference/) - Detailed documentation for all UI components
- [Web Interface Guide](../../WEB_INTERFACE_GUIDE.md) - Deep dive into web capabilities
- [Plugin Development](../04_extending_raxol/plugin_development.md) - Advanced plugin features
- [Enterprise Features](../06_enterprise/) - Authentication, monitoring, and deployment

### Example Applications
- **Dashboard App**: Real-time metrics and monitoring
- **Collaborative Editor**: Multi-user text editing
- **System Monitor**: Server resource tracking
- **Git UI**: Terminal-based git interface

### Join the Community
- [GitHub Discussions](https://github.com/Hydepwns/raxol/discussions)
- [Issue Tracker](https://github.com/Hydepwns/raxol/issues)
- [Development Guide](../../DEVELOPMENT.md)

## Summary

Raxol is more than a terminal UI toolkit—it's a comprehensive framework for building modern applications that work seamlessly in both terminal and web environments. With its component-based architecture, real-time web capabilities, and extensible plugin system, you can build everything from simple CLIs to complex enterprise applications.

Happy coding with Raxol! 🚀
