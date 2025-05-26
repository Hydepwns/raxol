---
title: Plugin Development Guide
description: How to develop plugins for Raxol
date: 2025-04-27
author: Raxol Team
section: guides
tags: [plugins, development, guides, api]
---

# Raxol Plugin Development Guide

Create, manage, and integrate plugins within Raxol.

## Table of Contents

- [Introduction](#introduction)
- [Plugin Basics](#plugin-basics)
- [Plugin Lifecycle](#plugin-lifecycle)
- [Commands](#commands)
- [Dependencies](#dependencies)
- [Plugin Reloading](#plugin-reloading)
- [Core Plugins](#core-plugins)
- [Best Practices](#best-practices)
- [Example Plugin](#example-plugin)

## Introduction

### What are Raxol Plugins?

Self-contained Elixir modules extending Raxol functionality. They implement the `Raxol.Core.Runtime.Plugins.Plugin` behaviour and are managed by the `Raxol.Plugins.Manager.Core`. Plugins add commands, react to events, manage state, and interact with the Raxol ecosystem.

### Purpose of Plugins

- **Modularity:** Keep the Raxol core lean.
- **Extensibility:** Add capabilities without modifying core code.
- **Decoupling:** Isolate features for easier maintenance and testing.
- **Core Services:** Provide essentials like clipboard/notifications via dedicated plugins.

## Plugin Basics

### Directory Structure

The `Raxol.Plugins.Manager.Core` discovers plugins in:

1. **Core:** `lib/raxol/core/plugins/core/` (Built-in)
2. **Application:** `priv/plugins/` (Custom/Third-party)

It recursively searches these directories for `.ex` files.

### The `Plugin` Behaviour

Plugins implement the `Raxol.Core.Runtime.Plugins.Plugin` behaviour, defining callbacks for lifecycle, command registration, and handling.

```elixir
defmodule MyPlugin do
  @behaviour Raxol.Core.Runtime.Plugins.Plugin

  @impl true
  def init(config), do: {:ok, %{initial_state: :ok}}

  @impl true
  def terminate(reason, state), do: :ok

  @impl true
  def get_commands() do
    [%{namespace: :my_plugin, name: :do_something, arity: 1, description: "Action."}]
  end

  @impl true
  def handle_command({:my_plugin, :do_something}, args, state) do
    # Handle command...
    {:reply, :ok, state}
  end
  def handle_command(_command, _args, state), do: {:error, :unknown_command, state}
end
```

_(Note: `use Raxol.Core.Runtime.Plugins.Plugin` is a common shortcut macro that sets `@behaviour`.)_

### Plugin Metadata

Optionally, implement `Raxol.Core.Runtime.Plugins.PluginMetadataProvider` (usually in `<PluginModule>.Metadata`) to provide ID, version, and dependencies without fully loading the plugin.

```elixir
defmodule MyPlugin.Metadata do
  @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
  @impl true; def id(), do: :my_plugin
  @impl true; def version(), do: "0.1.0"
  @impl true; def dependencies(), do: [:core_clipboard]
end
```

## Plugin Lifecycle

The `Raxol.Plugins.Manager.Core` controls the plugin lifecycle, typically running callbacks in a dedicated process. Core events use `init/1` and `terminate/2`.

### Initialization (`init/1`)

Called after code loading and dependency initialization. Perform setup (start processes, allocate resources, set initial state).

```elixir
@impl true
def init(config) do
  initial_state = %{counter: 0, config: config}
  {:ok, initial_state}
end
```

- **Arguments:** `config` (plugin-specific configuration).
- **Returns:** `{:ok, initial_state}` on success, `{:error, reason}` on failure.

### Termination (`terminate/2`)

Called on shutdown, unload, or error. Release resources gracefully (stop processes, close files, etc.).

```elixir
@impl true
def terminate(reason, state) do
  Raxol.Core.Runtime.Log.info("Terminating. Reason: #{inspect(reason)}")
  :ok
end
```

- **Arguments:** `reason`, `state` (current state).
- **Return Value:** Ignored (usually `:ok`).

## Commands

Plugins often add commands invoked by the application or other plugins.

### Registering Commands (`get_commands/0`)

Declare commands by implementing `get_commands/0`, returning a list of command description maps.

```elixir
@impl true
def get_commands() do
  [
    %{namespace: :my_plugin, name: :inc, arity: 0, description: "Increment counter."},
    %{namespace: :my_plugin, name: :set, arity: 1, description: "Set value."}
  ]
end
```

- **Structure:** Each map needs `:namespace` (Atom), `:name` (Atom), `:arity` (Integer >= 0), `:description` (String).
- **Timing:** Called once during initialization _before_ `init/1`.

### Handling Commands (`handle_command/3`)

Executes command logic when dispatched by the `Raxol.Plugins.Manager.Core`.

```elixir
@impl true
def handle_command(command, args, state) do
  case {command.namespace, command.name} do
    {:my_plugin, :inc} ->
      new_state = Map.update!(state, :counter, &(&1 + 1))
      {:noreply, new_state}
    {:my_plugin, :set} ->
      case args do
        [value] -> {:reply, {:ok, value}, Map.put(state, :value, value)}
        _ -> {:reply, {:error, :invalid_arity}, state}
      end
    _ ->
      {:error, :unknown_command, state}
  end
end
```

- **Arguments:** `command` (map), `args` (list), `state`.
- **Returns:**
  - `{:reply, reply, new_state}`: Send reply, update state.
  - `{:noreply, new_state}`: Update state, no reply.
  - `{:stop, reason, reply, new_state}`: Reply, update, stop plugin.
  - `{:stop, reason, new_state}`: Update, stop plugin, no reply.
  - `{:error, reason, new_state}`: Indicate error, continue with new state.

### Namespacing and Arity

- **Namespacing (`:namespace`)**: Prevents command name collisions (e.g., `:clipboard.copy` vs `:files.copy`).
- **Arity (`:arity`)**: Ensures correct number of arguments are passed.

### The Command Registry

The `Raxol.Plugins.Manager.Core` uses `Raxol.Core.Runtime.Plugins.CommandRegistry` (ETS-backed) for efficient command storage and lookup.

## Dependencies

Plugins can require others to load first, with sophisticated version constraint handling and detailed dependency chain reporting.

### Declaring Dependencies

Use the optional `PluginMetadataProvider`'s `dependencies/0` callback.

```elixir
defmodule MyPlugin.Metadata do
  # ... id/version ...
  @impl true
  def dependencies() do
    [
      {:core_clipboard, ">= 1.0.0"},
      {:another_plugin, ">= 2.0.0 || >= 3.0.0"},
      :optional_plugin  # Simple dependency without version constraint
    ]
  end
end
```

- Returns a list of dependencies, each being either:
  - A tuple `{plugin_id, version_constraint}` for versioned dependencies
  - A simple `plugin_id` atom for unversioned dependencies
- Version constraints support:
  - Simple constraints: `">= 1.0.0"`, "~> 1.0", "== 1.0.0"
  - Complex constraints with OR operator: `">= 1.0.0 || >= 2.0.0"`
  - Both dependent and dependency plugins should provide metadata for reliable tracking
- **Optional dependencies with version mismatches are ignored and do not block plugin loading.**

### Dependency Resolution

`Raxol.Plugins.Manager.Core` determines init order:

1. Discover plugins
2. Extract metadata
3. Build dependency graph with version information
4. Use Tarjan's algorithm for cycle detection and topological sort
   - Only true cycles (mutually reachable nodes) are flagged as errors
   - The load order is unique (no duplicate plugin IDs)
5. Initialize in sorted order (`get_commands/0`, then `init/1`)

#### Cycle Detection Example

```elixir
A → B → C
↑   ↓   ↓
└── D ← E
```

- Edges: A→B, B→C, C→E, E→D, D→A, B→D
- Tarjan's algorithm will find the cycle: [A, B, C, D, E]
- Only true cycles are flagged as errors.

### Error Handling

The dependency system provides detailed error reporting:

- **Missing Dependencies:**

  ```elixir
  {:error, :missing_dependencies, ["missing_plugin"], ["my_plugin", "dependent_plugin"]}
  ```

- **Version Mismatches:**

  ```elixir
  {:error, :version_mismatch, [{"other_plugin", "1.0.0", ">= 2.0.0"}], ["my_plugin"]}
  ```

- **Circular Dependencies:**

  ```elixir
  {:error, :circular_dependency, ["plugin_a", "plugin_b", "plugin_a"], ["plugin_a", "plugin_b"]}
  ```

- **Note:** Optional dependencies with version mismatches are ignored and do not cause errors.

Each error includes a dependency chain showing the path that led to the error, making it easier to diagnose complex dependency issues.

### Optional Dependencies

Plugins can declare optional dependencies that won't prevent loading if missing or if the version does not match:

```elixir
defmodule MyPlugin.Metadata do
  @impl true
  def optional_dependencies() do
    [
      {:optional_feature, ">= 1.0.0"},
      :another_optional
    ]
  end
end
```

Optional dependencies follow the same version constraint rules as required dependencies, but version mismatches are ignored.

## Plugin Reloading

Reload plugins at runtime (development convenience).

### How Reloading Works

`Raxol.Plugins.Manager.Core` orchestrates:

1. Terminate old instance (`terminate/2`).
2. Unregister old commands.
3. Purge/delete old code (`Code.purge/1`, `Code.delete/1`).
4. Recompile source file.
5. Load new code.
6. Register new commands (`get_commands/0` on new version).
7. Initialize new instance (`init/1` on new version).

### Considerations

- **Development Only:** Not recommended for production.
- **State Lost:** Reloading does _not_ preserve state. `init/1` starts fresh.
- **Dependency Impact:** Can break dependent plugins if APIs change.
- **Resource Cleanup:** `terminate/2` must be robust to avoid leaks.
- **Purge Limitations:** `Code.purge/1` can fail, leaving inconsistent state.
- **Source Required:** Needs access to `.ex` source files at runtime.

## Core Plugins

Located in `lib/raxol/core/plugins/core/`.

### Overview

- **`ClipboardPlugin` (`:core_clipboard`):** System clipboard integration (`:clipboard_write`, `:clipboard_read`).
- **`NotificationPlugin` (`:core_notification`):** Desktop notifications (`:notify`).

_(More may be added.)_

## Best Practices

### State Management

- Keep state minimal.
- Use OTP (`GenServer`, `Agent`) for complex state/tasks; manage via `init/1`, `terminate/2`.
- Treat state as immutable; return new state maps.

### Error Handling

- Handle command errors gracefully (return error tuples, don't crash).
- Implement reliable resource cleanup in `terminate/2`.
- Use supervisor strategies for supervised processes within the plugin.

### Testing

- Unit test callbacks (`init/1`, `handle_command/3`, `terminate/2`).
- Mock external dependencies.
- Perform integration tests within a minimal Raxol environment.

### Documentation

- Document commands clearly (`:description`).
- Use `@moduledoc` for overview/config.
- Use `@doc` for helper functions.
- Provide accurate metadata if needed.

### Other

- Use clear command namespaces.
- Make plugins configurable via `init/1` config.
- Consider command idempotency.

## Example Plugin

A simple counter plugin.

### `CounterPlugin`

```elixir
# priv/plugins/counter_plugin.ex
defmodule CounterPlugin do
  @moduledoc "Simple counter plugin."
  use Raxol.Core.Runtime.Plugins.Plugin
  require Raxol.Core.Runtime.Log

  @impl true
  def init(_config), do: {:ok, %{count: 0}}

  @impl true
  def terminate(reason, state) do
    Raxol.Core.Runtime.Log.info("Counter terminating. Reason: #{inspect(reason)}, Count: #{state.count}")
    :ok
  end

  @impl true
  def get_commands() do
    [
      %{namespace: :counter, name: :increment, arity: 0, description: "Increments counter."},
      %{namespace: :counter, name: :get, arity: 0, description: "Gets counter value."}
    ]
  end

  @impl true
  def handle_command({:counter, :increment}, _args, state) do
    new_state = Map.update!(state, :count, &(&1 + 1))
    {:noreply, new_state}
  end
  def handle_command({:counter, :get}, _args, state) do
    {:reply, {:ok, state.count}, state}
  end
  def handle_command(_command, _args, state), do: {:error, :unknown_command, state}
end

# priv/plugins/counter_plugin/metadata.ex
# (Optional metadata)
defmodule CounterPlugin.Metadata do
  @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
  @impl true; def id(), do: :counter
  @impl true; def version(), do: "1.0.0"
  @impl true; def dependencies(), do: []
end
```

This example shows state (`%{count: 0}`), initialized in `init/1` and updated/passed through `handle_command/3`.
