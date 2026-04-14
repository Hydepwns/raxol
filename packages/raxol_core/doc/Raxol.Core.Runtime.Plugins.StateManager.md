# `Raxol.Core.Runtime.Plugins.StateManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/state_manager.ex#L274)

Namespaced alias for StateManager.

Provides the same functionality as StateManager but under the proper namespace
for consistency with the existing codebase structure.

# `cleanup`

# `get_plugin_metadata`

# `get_plugin_state`

# `get_plugin_state`

```elixir
@spec get_plugin_state(String.t(), term()) :: {:ok, term()}
```

Gets plugin state with both plugin_id and state parameters for compatibility.

# `initialize`

# `initialize_plugin_state`

# `list_plugin_states`

# `remove_plugin`

# `set_plugin_state`

# `set_plugin_state`

```elixir
@spec set_plugin_state(String.t(), term(), term()) :: {:ok, term()}
```

Sets plugin state with plugin_id and state parameters for compatibility.

# `update_plugin_state`

# `update_plugin_state`

```elixir
@spec update_plugin_state(String.t(), term(), (term() -&gt; term())) :: {:ok, term()}
```

Updates plugin state with additional state parameter for compatibility.

# `update_plugin_state_legacy`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
