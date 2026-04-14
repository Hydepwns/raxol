# `Raxol.Core.Runtime.Plugins.PluginSupervisor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugin_supervisor.ex#L1)

Supervisor for plugin tasks and processes.

This module provides isolation for plugin operations, ensuring that a plugin crash
doesn't destabilize the core application. All plugin operations that could fail
(initialization, event handling, cleanup) should run through this supervisor.

## Design

Uses `Task.Supervisor` for fire-and-forget and async plugin operations:
- Plugin initialization
- Event handling
- Scheduled tasks
- Cleanup operations

## Benefits

- **Crash Isolation**: Plugin crashes don't bring down the main application
- **Timeout Control**: Operations have configurable timeouts
- **Logging**: All crashes are logged with plugin context
- **Metrics**: Crash counts tracked for monitoring

## Usage

    # Start plugin initialization in isolation
    {:ok, result} = PluginSupervisor.run_plugin_task(:my_plugin, fn ->
      MyPlugin.init(%{})
    end)

    # Fire and forget (for side-effect operations)
    PluginSupervisor.async_plugin_task(:my_plugin, fn ->
      MyPlugin.on_event(event)
    end)

    # With custom timeout
    PluginSupervisor.run_plugin_task(:my_plugin, fn -> slow_op() end, timeout: 10_000)

# `async_plugin_task`

```elixir
@spec async_plugin_task(atom(), (-&gt; term())) :: :ok
```

Runs a plugin task asynchronously (fire and forget).

The task runs under the Task.Supervisor, so crashes are isolated.
Crashes are logged but don't return errors to the caller.

## Examples

    PluginSupervisor.async_plugin_task(:my_plugin, fn ->
      MyPlugin.handle_event(event)
    end)

# `call_plugin_callback`

```elixir
@spec call_plugin_callback(atom(), module(), atom(), list(), keyword()) ::
  {:ok, term()} | {:error, term()} | :not_exported
```

Safely invokes a plugin callback with isolation.

Handles the common pattern of calling a module function if it exists.

## Examples

    # Calls MyPlugin.on_load() if exported, returns {:ok, result} or {:error, reason}
    PluginSupervisor.call_plugin_callback(:my_plugin, MyPlugin, :on_load, [])

    # Calls MyPlugin.handle_event(event) with timeout
    PluginSupervisor.call_plugin_callback(:my_plugin, MyPlugin, :handle_event, [event], timeout: 1000)

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `run_plugin_task`

```elixir
@spec run_plugin_task(atom(), (-&gt; term()), keyword()) ::
  {:ok, term()} | {:error, term()}
```

Runs a plugin task synchronously with crash isolation.

Returns `{:ok, result}` on success, or `{:error, reason}` on failure.
The task runs under the Task.Supervisor, so crashes are isolated.

## Options

  * `:timeout` - Maximum time in milliseconds (default: 5000)

## Examples

    {:ok, state} = PluginSupervisor.run_plugin_task(:my_plugin, fn ->
      MyPlugin.init(%{config: "value"})
    end)

    {:error, {:crashed, %RuntimeError{}}} = PluginSupervisor.run_plugin_task(:bad_plugin, fn ->
      raise "oops"
    end)

# `run_plugin_tasks_concurrent`

```elixir
@spec run_plugin_tasks_concurrent(atom(), [(-&gt; term())], keyword()) :: [
  ok: term(),
  error: term()
]
```

Runs multiple plugin tasks concurrently with isolation.

Returns results in the same order as input functions.
Failed tasks return `{:error, reason}` in their position.

## Options

  * `:timeout` - Maximum time for all tasks (default: 5000)

## Examples

    results = PluginSupervisor.run_plugin_tasks_concurrent(:my_plugin, [
      fn -> fetch_data() end,
      fn -> process_config() end
    ])
    # => [{:ok, data}, {:ok, config}]

# `start_link`

# `stats`

```elixir
@spec stats() :: %{active_tasks: non_neg_integer(), supervisor_info: nil | keyword()}
```

Gets statistics about plugin task execution.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
