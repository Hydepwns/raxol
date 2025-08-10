---
title: Raxol Plugin System Guide
description: Complete guide to developing and using plugins in Raxol applications
date: 2025-08-10
author: Raxol Team
section: documentation
tags: [plugins, extensions, development, guide]
---

# Raxol Plugin System Guide

## Overview

The Raxol plugin system enables you to extend the framework's functionality at runtime without modifying core code. Plugins can add new commands, hook into system events, provide custom UI components, and integrate with external services.

> **📚 Architecture Context**: See [ADR-0005: Runtime Plugin System Architecture](./adr/0005-runtime-plugin-system-architecture.md) for the complete architectural decision context, alternatives considered, and technical implementation details.

## Plugin Architecture

```
┌─────────────────────────────────────────────┐
│              Plugin Manager                  │
├─────────────────────────────────────────────┤
│  Lifecycle │ Registry │ Events │ Config     │
├─────────────────────────────────────────────┤
│                 Plugins                      │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│  │Plugin A │ │Plugin B │ │Plugin C │  ...  │
│  └─────────┘ └─────────┘ └─────────┘       │
└─────────────────────────────────────────────┘
```

## Creating a Plugin

### Basic Plugin Structure

```elixir
defmodule MyPlugin do
  use Raxol.Plugin
  
  @moduledoc """
  A sample plugin that adds custom functionality to Raxol.
  """

  # Plugin metadata
  def metadata do
    %{
      name: "My Plugin",
      version: "1.0.0",
      author: "Your Name",
      description: "Adds awesome features to Raxol",
      dependencies: []  # List of required plugins
    }
  end

  # Initialize plugin state
  def init(config) do
    state = %{
      config: config,
      started_at: DateTime.utc_now()
    }
    {:ok, state}
  end

  # Register commands
  def commands do
    [
      {"hello", &hello_command/2, "Say hello"},
      {"status", &status_command/2, "Show plugin status"}
    ]
  end

  # Handle lifecycle events
  def handle_event(:application_started, state) do
    IO.puts("Application started!")
    {:ok, state}
  end

  def handle_event({:terminal_input, input}, state) do
    # Process terminal input
    {:ok, state}
  end

  # Command implementations
  defp hello_command(args, state) do
    name = Enum.join(args, " ") || "World"
    {:ok, "Hello, #{name}!", state}
  end

  defp status_command(_args, state) do
    uptime = DateTime.diff(DateTime.utc_now(), state.started_at)
    status = """
    Plugin Status:
    - Uptime: #{uptime} seconds
    - Config: #{inspect(state.config)}
    """
    {:ok, status, state}
  end
end
```

### Advanced Plugin Features

#### 1. UI Components

Plugins can provide custom UI components:

```elixir
defmodule UIPlugin do
  use Raxol.Plugin

  def components do
    [
      {"status-bar", &render_status_bar/2},
      {"menu", &render_menu/2}
    ]
  end

  defp render_status_bar(props, _state) do
    {:row, [background: :blue, padding: 1],
      [
        {:text, [color: :white], props.left},
        {:spacer, []},
        {:text, [color: :yellow], props.right}
      ]
    }
  end

  defp render_menu(props, _state) do
    {:list, [border: :single],
      Enum.map(props.items, fn item ->
        {:button, [
          label: item.label,
          on_click: {:menu_select, item.id}
        ]}
      end)
    }
  end
end
```

#### 2. Event Hooks

Subscribe to and emit system events:

```elixir
defmodule EventPlugin do
  use Raxol.Plugin

  def subscriptions do
    [
      :terminal_resize,
      :user_connected,
      :command_executed,
      {:custom, :my_event}
    ]
  end

  def handle_event({:terminal_resize, %{width: w, height: h}}, state) do
    IO.puts("Terminal resized to #{w}x#{h}")
    
    # Emit custom event
    emit_event({:custom, :terminal_resized}, %{width: w, height: h})
    
    {:ok, state}
  end

  def handle_event({:command_executed, %{command: cmd, result: result}}, state) do
    # Log command execution
    state = update_in(state.command_history, &[{cmd, result} | &1])
    {:ok, state}
  end
end
```

#### 3. Background Tasks

Run periodic or long-running tasks:

```elixir
defmodule TaskPlugin do
  use Raxol.Plugin

  def init(config) do
    # Schedule periodic task
    schedule_task(:check_updates, 60_000)  # Every minute
    
    {:ok, %{config: config, last_check: nil}}
  end

  def handle_task(:check_updates, state) do
    # Perform update check
    case check_for_updates() do
      {:ok, updates} ->
        notify_user("Updates available: #{inspect(updates)}")
        {:ok, %{state | last_check: DateTime.utc_now()}}
      {:error, _} ->
        {:ok, state}
    end
  end

  defp schedule_task(task, interval) do
    Process.send_after(self(), {:plugin_task, task}, interval)
  end
end
```

## Plugin Lifecycle

### 1. Loading

```elixir
# Load from module
Raxol.Core.Runtime.Plugins.Manager.load_plugin_by_module(MyPlugin)

# Load from file
Raxol.Core.Runtime.Plugins.Manager.load_plugin_from_file("path/to/plugin.ex")

# Load from package
Raxol.Core.Runtime.Plugins.Manager.load_plugin({:hex, :my_plugin, "~> 1.0"})
```

### 2. Configuration

```elixir
# Configure plugin before loading
config = %{
  api_key: "secret",
  endpoint: "https://api.example.com",
  timeout: 5000
}

Raxol.Core.Runtime.Plugins.Manager.load_plugin_by_module(MyPlugin, config)
```

### 3. Lifecycle Callbacks

```elixir
defmodule LifecyclePlugin do
  use Raxol.Plugin

  # Called when plugin is loaded
  def init(config) do
    IO.puts("Plugin initializing...")
    {:ok, %{config: config}}
  end

  # Called when plugin is enabled
  def on_enable(state) do
    IO.puts("Plugin enabled!")
    start_services(state)
    {:ok, state}
  end

  # Called when plugin is disabled
  def on_disable(state) do
    IO.puts("Plugin disabled!")
    stop_services(state)
    {:ok, state}
  end

  # Called before plugin is unloaded
  def terminate(reason, state) do
    IO.puts("Plugin terminating: #{inspect(reason)}")
    cleanup(state)
    :ok
  end
end
```

## Command Registration

### Simple Commands

```elixir
def commands do
  [
    {"echo", &echo/2, "Echo input back"},
    {"time", &show_time/2, "Show current time"},
    {"calc", &calculator/2, "Simple calculator"}
  ]
end

defp echo(args, state) do
  {:ok, Enum.join(args, " "), state}
end

defp show_time(_args, state) do
  {:ok, DateTime.utc_now() |> to_string(), state}
end

defp calculator([expr], state) do
  try do
    result = Code.eval_string(expr)
    {:ok, "Result: #{inspect(result)}", state}
  rescue
    _ -> {:error, "Invalid expression", state}
  end
end
```

### Interactive Commands

```elixir
def commands do
  [
    {"setup", &setup_wizard/2, "Run setup wizard"}
  ]
end

defp setup_wizard(_args, state) do
  # Return interactive prompt
  {:prompt, 
    %{
      question: "Enter your API key:",
      type: :password,
      callback: &save_api_key/2
    },
    state
  }
end

defp save_api_key(api_key, state) do
  state = put_in(state.config.api_key, api_key)
  {:ok, "API key saved!", state}
end
```

## Integration Examples

### 1. Git Integration Plugin

```elixir
defmodule GitPlugin do
  use Raxol.Plugin

  def commands do
    [
      {"git-status", &git_status/2, "Show git status"},
      {"git-branch", &git_branch/2, "List branches"},
      {"git-commit", &git_commit/2, "Create commit"}
    ]
  end

  defp git_status(_args, state) do
    case System.cmd("git", ["status", "--porcelain"]) do
      {output, 0} ->
        formatted = format_git_status(output)
        {:ok, formatted, state}
      {error, _} ->
        {:error, "Git error: #{error}", state}
    end
  end

  defp format_git_status(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      case String.split(line, " ", parts: 2) do
        ["M", file] -> {:text, [color: :yellow], "Modified: #{file}"}
        ["A", file] -> {:text, [color: :green], "Added: #{file}"}
        ["D", file] -> {:text, [color: :red], "Deleted: #{file}"}
        ["??", file] -> {:text, [color: :gray], "Untracked: #{file}"}
        _ -> {:text, [], line}
      end
    end)
  end
end
```

### 2. HTTP Client Plugin

```elixir
defmodule HTTPPlugin do
  use Raxol.Plugin

  def init(_config) do
    {:ok, %{base_url: nil, headers: %{}}}
  end

  def commands do
    [
      {"http-get", &http_get/2, "Make GET request"},
      {"http-post", &http_post/2, "Make POST request"},
      {"http-base", &set_base_url/2, "Set base URL"}
    ]
  end

  defp http_get([url], state) do
    full_url = build_url(url, state)
    
    case HTTPoison.get(full_url, state.headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, format_response(body), state}
      {:ok, %{status_code: code}} ->
        {:error, "HTTP #{code}", state}
      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}", state}
    end
  end

  defp format_response(body) do
    case Jason.decode(body) do
      {:ok, json} -> 
        Jason.encode!(json, pretty: true)
      {:error, _} -> 
        body
    end
  end
end
```

### 3. Database Plugin

```elixir
defmodule DatabasePlugin do
  use Raxol.Plugin

  def init(config) do
    # Connect to database
    {:ok, conn} = Postgrex.start_link(config.database)
    {:ok, %{conn: conn, config: config}}
  end

  def commands do
    [
      {"db-query", &run_query/2, "Run SQL query"},
      {"db-tables", &list_tables/2, "List tables"},
      {"db-schema", &show_schema/2, "Show table schema"}
    ]
  end

  defp run_query([query], state) do
    case Postgrex.query(state.conn, query, []) do
      {:ok, result} ->
        {:ok, format_query_result(result), state}
      {:error, error} ->
        {:error, "Query error: #{inspect(error)}", state}
    end
  end

  defp format_query_result(%{columns: columns, rows: rows}) do
    # Format as table
    {:table, 
      [
        headers: columns,
        rows: rows,
        border: :single
      ]
    }
  end

  def terminate(_reason, state) do
    # Close database connection
    GenServer.stop(state.conn)
    :ok
  end
end
```

## Plugin Distribution

### 1. As Hex Package

Create a mix project for your plugin:

```elixir
# mix.exs
defmodule MyRaxolPlugin.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_raxol_plugin,
      version: "1.0.0",
      elixir: "~> 1.17",
      deps: deps(),
      description: "My awesome Raxol plugin",
      package: package()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:raxol, "~> 0.9.0"},
      # Other dependencies
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/user/my_raxol_plugin"}
    ]
  end
end
```

### 2. Plugin Registry

Register your plugin in the Raxol plugin registry:

```elixir
# In your plugin module
def registry_metadata do
  %{
    name: "my-plugin",
    category: :productivity,
    tags: ["git", "development"],
    homepage: "https://github.com/user/my-plugin"
  }
end
```

## Best Practices

### 1. Error Handling

Always handle errors gracefully:

```elixir
def handle_command(command, args, state) do
  try do
    execute_command(command, args, state)
  rescue
    error ->
      Logger.error("Plugin error: #{inspect(error)}")
      {:error, "Command failed", state}
  catch
    :exit, reason ->
      {:error, "Process exited: #{inspect(reason)}", state}
  end
end
```

### 2. State Management

Keep plugin state minimal and serializable:

```elixir
def export_state(state) do
  # Convert to serializable format
  %{
    config: state.config,
    stats: state.stats,
    # Don't include PIDs, refs, or functions
  }
end

def import_state(data, config) do
  # Reconstruct state from serialized data
  %{
    config: Map.merge(config, data.config),
    stats: data.stats,
    # Reinitialize runtime values
    conn: connect_to_service(config)
  }
end
```

### 3. Performance

Avoid blocking operations:

```elixir
def handle_command("slow-operation", args, state) do
  # Spawn async task
  Task.async(fn ->
    perform_slow_operation(args)
  end)
  
  {:ok, "Operation started in background", state}
end

def handle_info({ref, result}, state) when is_reference(ref) do
  # Handle async result
  notify_user("Operation completed: #{inspect(result)}")
  {:ok, state}
end
```

### 4. Testing

Write comprehensive tests for your plugin:

```elixir
defmodule MyPluginTest do
  use ExUnit.Case
  alias MyPlugin

  setup do
    {:ok, state} = MyPlugin.init(%{test: true})
    %{state: state}
  end

  test "hello command", %{state: state} do
    assert {:ok, "Hello, World!", _} = 
      MyPlugin.hello_command([], state)
    
    assert {:ok, "Hello, Alice!", _} = 
      MyPlugin.hello_command(["Alice"], state)
  end

  test "handles errors gracefully", %{state: state} do
    assert {:error, _, _} = 
      MyPlugin.dangerous_command(["invalid"], state)
  end
end
```

## Security Considerations

1. **Validate all input** from users and external sources
2. **Sandbox operations** that interact with the file system
3. **Use timeouts** for external API calls
4. **Limit resource usage** (memory, CPU, network)
5. **Audit command execution** for sensitive operations
6. **Encrypt sensitive configuration** data

## Debugging Plugins

Enable debug mode for detailed logging:

```elixir
# In your plugin
require Logger

def init(config) do
  if config[:debug] do
    Logger.configure(level: :debug)
  end
  
  Logger.debug("Plugin initializing with config: #{inspect(config)}")
  {:ok, %{config: config}}
end

# In Raxol config
config :raxol,
  plugin_debug: true,
  plugin_log_level: :debug
```

## Next Steps

- Explore [plugin development guide](./examples/guides/04_extending_raxol/plugin_development.md)
- Read the [Plugin API Reference](https://hexdocs.pm/raxol/Raxol.Plugin.html)
- Join the [plugin developer community](https://github.com/Hydepwns/raxol/discussions/categories/plugins)
- Submit your plugin to the [Raxol Plugin Registry](https://raxol-plugins.org)