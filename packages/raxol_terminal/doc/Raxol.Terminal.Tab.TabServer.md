# `Raxol.Terminal.Tab.TabServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/tab/tab_server.ex#L1)

Provides unified tab management functionality for the terminal emulator.
This module handles tab creation, switching, state management, and configuration.

# `tab_config`

```elixir
@type tab_config() :: %{
  optional(:name) =&gt; String.t(),
  optional(:icon) =&gt; String.t(),
  optional(:color) =&gt; String.t(),
  optional(:position) =&gt; non_neg_integer(),
  optional(:state) =&gt; tab_state()
}
```

# `tab_id`

```elixir
@type tab_id() :: non_neg_integer()
```

# `tab_state`

```elixir
@type tab_state() :: :active | :inactive | :hidden
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `cleanup`

```elixir
@spec cleanup() :: :ok
```

Cleans up resources.

# `close_tab`

```elixir
@spec close_tab(tab_id()) :: :ok | {:error, term()}
```

Closes a tab and its associated windows.

# `create_tab`

```elixir
@spec create_tab(map()) :: {:ok, tab_id()} | {:error, term()}
```

Creates a new tab with the given configuration.

# `get_active_tab`

```elixir
@spec get_active_tab() :: {:ok, tab_id()} | {:error, :no_active_tab}
```

Gets the active tab ID.

# `get_tab_state`

```elixir
@spec get_tab_state(tab_id()) :: {:ok, map()} | {:error, term()}
```

Gets the state of a specific tab.

# `get_tabs`

```elixir
@spec get_tabs() :: [tab_id()]
```

Gets the list of all tabs.

# `handle_manager_cast`

# `handle_manager_info`

# `move_tab`

```elixir
@spec move_tab(tab_id(), non_neg_integer()) :: :ok | {:error, term()}
```

Moves a tab to a new position.

# `set_active_tab`

```elixir
@spec set_active_tab(tab_id()) :: :ok | {:error, term()}
```

Sets the active tab.

# `start_link`

# `update_config`

```elixir
@spec update_config(map()) :: :ok
```

Updates the tab manager configuration.

# `update_tab_config`

```elixir
@spec update_tab_config(tab_id(), tab_config()) :: :ok | {:error, term()}
```

Updates the configuration of a specific tab.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
