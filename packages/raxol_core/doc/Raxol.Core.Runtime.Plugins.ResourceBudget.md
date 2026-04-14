# `Raxol.Core.Runtime.Plugins.ResourceBudget`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/resource_budget.ex#L1)

Runtime resource monitoring per plugin.

Tracks actual resource usage against declared budgets from plugin manifests.
Runs on a configurable timer (default 5s) and takes action when plugins
exceed their budgets.

Actions (configurable per plugin):
- `:warn` -- log warning + emit telemetry event
- `:throttle` -- reduce event delivery rate to plugin
- `:kill` -- unload the plugin via PluginLifecycle

# `action`

```elixir
@type action() :: :warn | :throttle | :kill
```

# `budget`

```elixir
@type budget() :: %{
  max_memory_mb: number(),
  max_cpu_percent: number(),
  max_ets_tables: non_neg_integer(),
  max_processes: non_neg_integer()
}
```

# `usage`

```elixir
@type usage() :: %{
  memory_mb: number(),
  cpu_percent: number(),
  ets_tables: non_neg_integer(),
  processes: non_neg_integer()
}
```

# `check`

```elixir
@spec check(atom()) :: {:ok, usage()} | {:over_budget, usage(), budget()}
```

Checks resource usage for a specific plugin against its budget.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `monitor_all`

```elixir
@spec monitor_all() :: [{atom(), :ok | :over_budget}]
```

Checks all monitored plugins and returns their status.

# `set_action`

```elixir
@spec set_action(atom(), action()) :: :ok
```

Sets the enforcement action for a plugin.

# `start_link`

# `throttled?`

```elixir
@spec throttled?(atom()) :: boolean()
```

Returns whether a plugin is currently throttled.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
