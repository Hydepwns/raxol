# `Raxol.Core.Behaviours.StateManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/behaviours/state_manager.ex#L1)

Behaviour for state management systems.

Defines the callbacks that state manager implementations must provide
for managing application and component state.

# `plugin_config`

```elixir
@type plugin_config() :: map()
```

# `plugin_id`

```elixir
@type plugin_id() :: String.t()
```

# `plugin_module`

```elixir
@type plugin_module() :: module()
```

# `state`

```elixir
@type state() :: term()
```

# `state_key`

```elixir
@type state_key() :: term()
```

# `state_value`

```elixir
@type state_value() :: term()
```

# `cleanup`

```elixir
@callback cleanup(state()) :: :ok
```

Cleans up state management resources.

## Parameters
- state: Current state

## Returns
- :ok on successful cleanup

# `delete_state`

```elixir
@callback delete_state(state(), state_key()) :: {:ok, state()}
```

Removes a key from the state.

## Parameters
- state: Current state
- key: Key to remove

## Returns
- `{:ok, new_state}` on success

# `get_state`

```elixir
@callback get_state(state(), state_key()) :: {:ok, state_value()} | {:error, :not_found}
```

Gets a value from the state.

## Parameters
- state: Current state
- key: Key to retrieve

## Returns
- `{:ok, value}` if key exists
- `{:error, :not_found}` if key doesn't exist

# `init`

```elixir
@callback init() :: {:ok, state()} | {:error, term()}
```

Initializes state management system.

## Returns
- `{:ok, initial_state}` on success
- `{:error, reason}` on failure

# `initialize_plugin_state`

```elixir
@callback initialize_plugin_state(plugin_module(), plugin_config()) ::
  {:ok, state()} | {:error, term()}
```

Initializes plugin-specific state.

## Parameters
- plugin_module: The plugin module
- config: Plugin configuration

## Returns
- `{:ok, initial_plugin_state}` on success
- `{:error, reason}` on failure

# `set_state`

```elixir
@callback set_state(state(), state_key(), state_value()) ::
  {:ok, state()} | {:error, term()}
```

Sets a value in the state.

## Parameters
- state: Current state
- key: Key to set
- value: Value to set

## Returns
- `{:ok, new_state}` on success
- `{:error, reason}` on failure

# `update_plugin_state_legacy`

```elixir
@callback update_plugin_state_legacy(plugin_id(), state(), plugin_config()) ::
  {:ok, state()} | {:error, term()}
```

Updates plugin state (legacy interface).

## Parameters
- plugin_id: Plugin identifier
- state: Plugin state
- config: Plugin configuration

## Returns
- `{:ok, updated_state}` on success
- `{:error, reason}` on failure

# `update_state`

```elixir
@callback update_state(state(), state_key(), (state_value() -&gt; state_value())) ::
  {:ok, state()} | {:error, term()}
```

Updates state using a function.

## Parameters
- state: Current state
- key: Key to update
- update_fn: Function to apply to the current value

## Returns
- `{:ok, new_state}` on success
- `{:error, reason}` on failure

---

*Consult [api-reference.md](api-reference.md) for complete listing*
