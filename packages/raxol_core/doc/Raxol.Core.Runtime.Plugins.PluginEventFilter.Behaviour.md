# `Raxol.Core.Runtime.Plugins.PluginEventFilter.Behaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugin_event_filter_behaviour.ex#L1)

Behavior for plugin event filtering.

# `filter_event`

```elixir
@callback filter_event(event :: term(), plugin_state :: term()) ::
  {:ok, term()} | :halt | {:error, term()}
```

Filters an event through the plugin system.
Returns {:ok, event} for modified/passed-through events,
:halt to stop event propagation, or {:error, reason} on error.

# `init_filter`

```elixir
@callback init_filter(opts :: keyword()) :: {:ok, term()} | {:error, term()}
```

Initializes the event filter for a plugin.

# `terminate_filter`

```elixir
@callback terminate_filter(state :: term()) :: :ok
```

Terminates the event filter for a plugin.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
