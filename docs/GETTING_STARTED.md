---
title: Getting Started with Raxol
description: Quick start guide for building terminal applications with Raxol
date: 2025-08-10
author: Raxol Team
section: documentation
tags: [getting-started, tutorial, guide, quickstart]
---

# Getting Started with Raxol

Welcome to Raxol! This guide will help you get up and running with the most advanced terminal framework in Elixir in just 5 minutes.

## Table of Contents
- [Installation](#installation)
- [Your First Terminal App](#your-first-terminal-app)
- [Understanding Components](#understanding-components)
- [Adding Interactivity](#adding-interactivity)
- [Working with State](#working-with-state)
- [Next Steps](#next-steps)

## Installation

### Prerequisites
- Elixir 1.15.7 or later
- Erlang/OTP 26.0 or later
- Node.js 20+ (for web interface)

### Add Raxol to Your Project

Add Raxol to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:raxol, "~> 0.9.0"}
  ]
end
```

Then fetch the dependency:

```bash
mix deps.get
mix deps.compile
```

## Your First Terminal App

Let's create a simple "Hello, Terminal!" application:

### 1. Create a New Project

```bash
mix new my_terminal_app
cd my_terminal_app
```

### 2. Create Your First Component

Create `lib/my_terminal_app/hello_component.ex`:

```elixir
defmodule MyTerminalApp.HelloComponent do
  use Raxol.Component
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box padding={2} border="rounded" borderColor="green">
      <Text color="cyan" bold>
        Hello, <%= @name %>!
      </Text>
      <Text color="gray" marginTop={1}>
        Welcome to Raxol - The Terminal Framework
      </Text>
    </Box>
    """
  end
end
```

### 3. Create the Main Application

Create `lib/my_terminal_app/app.ex`:

```elixir
defmodule MyTerminalApp.App do
  use Raxol.Application
  
  @impl true
  def mount(_params, socket) do
    {:ok, assign(socket, name: "Terminal Developer")}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Screen>
      <MyTerminalApp.HelloComponent name={@name} />
    </Screen>
    """
  end
end
```

### 4. Run Your Application

```bash
mix raxol.run --app MyTerminalApp.App
```

Congratulations! You've created your first Raxol terminal application!

## Understanding Components

Raxol uses a component-based architecture similar to React or Phoenix LiveView. Components are the building blocks of your terminal UI.

### Basic Component Structure

```elixir
defmodule MyComponent do
  use Raxol.Component
  
  prop :title, :string, required: true
  prop :count, :integer, default: 0
  
  @impl true
  def mount(socket) do
    {:ok, assign(socket, internal_state: "initialized")}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box>
      <Text><%= @title %>: <%= @count %></Text>
    </Box>
    """
  end
end
```

### Built-in Components

Raxol provides a rich set of pre-built components:
- **Layout**: `<Box>`, `<Grid>`, `<Stack>`, `<Spacer>`
- **Text**: `<Text>`, `<Heading>`, `<Code>`, `<Link>`
- **Input**: `<TextInput>`, `<TextArea>`, `<Select>`, `<Checkbox>`, `<RadioGroup>`
- **Display**: `<Table>`, `<List>`, `<ProgressBar>`, `<Spinner>`, `<Chart>`

## Adding Interactivity

Make your applications interactive with event handling:

### Counter Example

```elixir
defmodule Counter do
  use Raxol.Component
  
  @impl true
  def mount(socket) do
    {:ok, assign(socket, count: 0)}
  end
  
  @impl true
  def handle_event("increment", _params, socket) do
    {:noreply, update(socket, :count, &(&1 + 1))}
  end
  
  @impl true
  def handle_event("decrement", _params, socket) do
    {:noreply, update(socket, :count, &(&1 - 1))}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box>
      <Text size="large">Count: <%= @count %></Text>
      <Stack direction="horizontal" spacing={2}>
        <Button onClick="increment" variant="primary">
          Increment
        </Button>
        <Button onClick="decrement" variant="secondary">
          Decrement
        </Button>
      </Stack>
    </Box>
    """
  end
end
```

### Keyboard Shortcuts

Register keyboard shortcuts with `register_shortcuts/2`:

```elixir
def mount(socket) do
  {:ok,
   socket
   |> assign(message: "Press a key...")
   |> register_shortcuts([
     {"ctrl+s", "save"},
     {"ctrl+q", "quit"}
   ])}
end
```

## Working with State

Raxol provides powerful state management capabilities:

### Local Component State

```elixir
defmodule TodoList do
  use Raxol.Component
  
  @impl true
  def mount(socket) do
    {:ok, assign(socket, todos: [], input: "")}
  end
  
  @impl true
  def handle_event("add_todo", %{"value" => text}, socket) do
    todo = %{id: System.unique_integer(), text: text, done: false}
    {:noreply, socket |> update(:todos, &[todo | &1]) |> assign(input: "")}
  end
  
  @impl true
  def handle_event("toggle_todo", %{"id" => id}, socket) do
    # Toggle todo completion state
    # Implementation details...
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box>
      <Heading>Todo List</Heading>
      <TextInput value={@input} onSubmit="add_todo" placeholder="Add a todo..." />
      <!-- Todo list rendering... -->
    </Box>
    """
  end
end
```

### Global State with PubSub

```elixir
defmodule GlobalStateExample do
  use Raxol.Component
  
  @impl true
  def mount(socket) do
    Raxol.PubSub.subscribe("user:updated")
    {:ok, assign(socket, user: nil)}
  end
  
  @impl true
  def handle_info({:user_updated, user}, socket) do
    {:noreply, assign(socket, user: user)}
  end
  
  @impl true
  def handle_event("update_user", %{"name" => name}, socket) do
    user = %{name: name, updated_at: DateTime.utc_now()}
    Raxol.PubSub.broadcast("user:updated", {:user_updated, user})
    {:noreply, socket}
  end
  
  # render implementation...
end
```

## Next Steps

Now that you've learned the basics, explore these advanced topics:

### Learn More
- [Component API Reference](./API_REFERENCE.md)
- [Plugin Development](./PLUGIN_SYSTEM_GUIDE.md)
- [Web Interface](./WEB_INTERFACE_GUIDE.md)
- [Architecture Documentation](./ARCHITECTURE.md)

### Interactive Examples
```bash
mix raxol.examples showcase  # Component showcase
mix raxol.examples todo      # Todo application
mix raxol.examples dashboard # Dashboard demo
```

### Development Tools
- Enable hot reloading with `config :raxol, hot_reload: true`
- Press `F12` to open DevTools (component inspector, state viewer, profiler)

### Community
- [GitHub Discussions](https://github.com/hydepwns/raxol/discussions)
- [Discord Server](https://discord.gg/raxol)
- [Twitter](https://twitter.com/raxol_terminal)

## Troubleshooting

**Terminal rendering issues**: Set `export TERM=xterm-256color`  
**Components not updating**: Ensure handlers return `{:noreply, socket}`  
**Performance issues**: Use `Raxol.Profile.start()` to identify bottlenecks

See [Troubleshooting Guide](./TROUBLESHOOTING.md) for detailed help.

---

**You're ready to build amazing terminal applications with Raxol!**

Remember: The terminal is your canvas, and Raxol is your paintbrush. Create something beautiful!