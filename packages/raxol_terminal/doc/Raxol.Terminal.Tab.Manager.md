# `Raxol.Terminal.Tab.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/tab/tab_manager.ex#L1)

Manages terminal tabs and their associated sessions.
This module handles:
- Creation, deletion, and switching of terminal tabs
- Tab state and configuration management
- Tab stop management for terminal operations

# `t`

```elixir
@type t() :: %Raxol.Terminal.Tab.Manager{
  active_tab: tab_id() | nil,
  default_tab_width: pos_integer(),
  next_tab_id: non_neg_integer(),
  tab_stops: MapSet.t(),
  tabs: %{required(tab_id()) =&gt; tab_config()}
}
```

# `tab_config`

```elixir
@type tab_config() :: %{
  title: String.t(),
  working_directory: String.t(),
  command: String.t() | nil,
  state: tab_state(),
  window_id: String.t() | nil
}
```

# `tab_id`

```elixir
@type tab_id() :: String.t()
```

# `tab_state`

```elixir
@type tab_state() :: :active | :inactive | :hidden
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear_all_tab_stops`

```elixir
@spec clear_all_tab_stops(t()) :: t()
```

Clears all tab stops.

# `clear_tab_stop`

```elixir
@spec clear_tab_stop(t(), pos_integer()) :: t()
```

Clears a tab stop at the specified position.

# `create_tab`

```elixir
@spec create_tab(t(), map()) :: {:ok, tab_id(), t()}
```

Creates a new tab with the given configuration.

## Parameters

* `manager` - The tab manager instance
* `config` - The tab configuration (optional)

## Returns

`{:ok, tab_id, updated_manager}` on success
`{:error, reason}` on failure

# `delete_tab`

```elixir
@spec delete_tab(t(), tab_id()) :: {:ok, t()} | {:error, :tab_not_found}
```

Deletes a tab by its ID.

## Parameters

* `manager` - The tab manager instance
* `tab_id` - The ID of the tab to delete

## Returns

`{:ok, updated_manager}` on success
`{:error, :tab_not_found}` if the tab doesn't exist

# `get_active_tab`

```elixir
@spec get_active_tab(t()) :: tab_id() | nil
```

Gets the active tab ID.

## Parameters

* `manager` - The tab manager instance

## Returns

The active tab ID or nil if no tab is active

# `get_next_tab_stop`

```elixir
@spec get_next_tab_stop(t()) :: pos_integer()
```

Gets the next tab stop position from the current position.

# `get_next_tab_stop`

```elixir
@spec get_next_tab_stop(t(), non_neg_integer()) :: pos_integer()
```

Gets the next tab stop position from a specific current position.

# `get_tab_config`

```elixir
@spec get_tab_config(t(), tab_id()) :: {:ok, tab_config()} | {:error, :tab_not_found}
```

Gets the configuration for a specific tab.

## Parameters

* `manager` - The tab manager instance
* `tab_id` - The ID of the tab

## Returns

`{:ok, config}` on success
`{:error, :tab_not_found}` if the tab doesn't exist

# `handle_manager_cast`

# `handle_manager_info`

# `list_tabs`

```elixir
@spec list_tabs(t()) :: %{required(tab_id()) =&gt; tab_config()}
```

Lists all tabs.

## Parameters

* `manager` - The tab manager instance

## Returns

A map of tab IDs to tab configurations

# `new`

```elixir
@spec new() :: t()
```

Creates a new tab manager instance.

# `set_horizontal_tab`

```elixir
@spec set_horizontal_tab(t()) :: t()
```

Sets a horizontal tab stop at the current cursor position.

# `set_horizontal_tab`

```elixir
@spec set_horizontal_tab(t(), non_neg_integer()) :: t()
```

Sets a horizontal tab stop at the specified position.

# `start_link`

# `switch_tab`

```elixir
@spec switch_tab(t(), tab_id()) :: {:ok, t()} | {:error, :tab_not_found}
```

Switches to a different tab.

## Parameters

* `manager` - The tab manager instance
* `tab_id` - The ID of the tab to switch to

## Returns

`{:ok, updated_manager}` on success
`{:error, :tab_not_found}` if the tab doesn't exist

# `update_tab_config`

```elixir
@spec update_tab_config(t(), tab_id(), map()) :: {:ok, t()} | {:error, :tab_not_found}
```

Updates the configuration for a specific tab.

## Parameters

* `manager` - The tab manager instance
* `tab_id` - The ID of the tab
* `updates` - The configuration updates to apply

## Returns

`{:ok, updated_manager}` on success
`{:error, :tab_not_found}` if the tab doesn't exist

---

*Consult [api-reference.md](api-reference.md) for complete listing*
