# `Raxol.Core.Runtime.Plugins.PluginInitializer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugin_initializer.ex#L1)

Handles initialization of plugins, including state setup and command registration.

# `handle_plugin_init`

Handles the initialization of a specific plugin.

# `initialize_plugin`

```elixir
@spec initialize_plugin(
  atom() | String.t(),
  {:ok, {map(), map(), map()}},
  map(),
  map()
) :: {:cont, {:ok, {map(), map(), map()}}} | {:halt, {:error, term()}}
```

Initializes a single plugin.

# `initialize_plugins`

```elixir
@spec initialize_plugins(
  map() | list(),
  map(),
  map() | nil,
  map(),
  list(),
  map() | atom() | reference(),
  keyword() | map() | nil
) :: {:ok, {map(), map(), map()}} | {:error, term()}
```

Initializes all plugins in the given load order.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
