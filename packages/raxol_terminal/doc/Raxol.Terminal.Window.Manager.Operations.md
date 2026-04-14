# `Raxol.Terminal.Window.Manager.Operations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/window/manager/operations.ex#L1)

Operations module for window management functionality.
Handles all the complex logic for window creation, updates, and hierarchy management.

# `window_id`

```elixir
@type window_id() :: String.t()
```

# `window_state`

```elixir
@type window_state() :: :active | :inactive | :minimized | :maximized
```

# `create_child_window`

```elixir
@spec create_child_window(window_id(), Raxol.Terminal.Config.t()) ::
  {:ok, Raxol.Terminal.Window.t()} | {:error, :not_found}
```

Creates a child window.

# `create_window_with_config`

```elixir
@spec create_window_with_config(Raxol.Terminal.Config.t()) ::
  {:ok, Raxol.Terminal.Window.t()} | {:error, term()}
```

Creates a window with configuration.

# `destroy_window_by_id`

```elixir
@spec destroy_window_by_id(window_id()) :: :ok | {:error, :not_found}
```

Destroys a window by ID.

# `get_active_window`

```elixir
@spec get_active_window() :: {:ok, Raxol.Terminal.Window.t()} | {:error, :not_found}
```

Gets the active window.

# `get_child_windows`

```elixir
@spec get_child_windows(window_id()) ::
  {:ok, [Raxol.Terminal.Window.t()]} | {:error, :not_found}
```

Gets child windows for a parent.

# `get_parent_window`

```elixir
@spec get_parent_window(window_id()) ::
  {:ok, Raxol.Terminal.Window.t()} | {:error, :no_parent}
```

Gets the parent window for a child.

# `get_window_by_id`

```elixir
@spec get_window_by_id(window_id()) ::
  {:ok, Raxol.Terminal.Window.t()} | {:error, :not_found}
```

Gets a window by ID with proper error handling.

# `list_all_windows`

```elixir
@spec list_all_windows() :: {:ok, [Raxol.Terminal.Window.t()]}
```

Lists all windows.

# `set_active_window`

```elixir
@spec set_active_window(window_id()) :: :ok | {:error, :not_found}
```

Sets the active window.

# `update_window_property`

```elixir
@spec update_window_property(window_id(), atom(), any()) ::
  {:ok, Raxol.Terminal.Window.t()} | {:error, :not_found}
```

Updates a window property.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
