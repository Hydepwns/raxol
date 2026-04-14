# `Raxol.Terminal.Plugin.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/plugin/terminal_plugin_manager.ex#L1)

Manages terminal plugins with advanced features:
- Plugin loading and unloading
- Plugin lifecycle management
- Plugin API and hooks
- Plugin configuration and state management

# `hook`

```elixir
@type hook() :: %{name: String.t(), callback: function(), priority: integer()}
```

# `plugin`

```elixir
@type plugin() :: %{
  name: String.t(),
  version: String.t(),
  description: String.t(),
  author: String.t(),
  hooks: [String.t()],
  config: map(),
  state: map()
}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Plugin.Manager{
  config: map(),
  hooks: %{required(String.t()) =&gt; [hook()]},
  metrics: %{
    plugin_loads: integer(),
    plugin_unloads: integer(),
    hook_calls: integer(),
    config_updates: integer()
  },
  plugins: %{required(String.t()) =&gt; plugin()}
}
```

# `call_hook`

```elixir
@spec call_hook(t(), String.t(), [term()]) :: {:ok, [term()], t()} | {:error, term()}
```

Calls a hook with the given arguments.

# `get_metrics`

```elixir
@spec get_metrics(t()) :: map()
```

Gets the current plugin metrics.

# `load_plugin`

```elixir
@spec load_plugin(t(), plugin()) :: {:ok, t()} | {:error, term()}
```

Loads a plugin into the manager.

# `new`

```elixir
@spec new(keyword()) :: t()
```

Creates a new plugin manager with the given options.

# `unload_plugin`

```elixir
@spec unload_plugin(t(), String.t()) :: {:ok, t()} | {:error, term()}
```

Unloads a plugin from the manager.

# `update_plugin_config`

```elixir
@spec update_plugin_config(t(), String.t(), map()) :: {:ok, t()} | {:error, term()}
```

Updates the configuration for a plugin.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
