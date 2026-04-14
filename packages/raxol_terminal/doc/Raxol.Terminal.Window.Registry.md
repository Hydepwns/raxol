# `Raxol.Terminal.Window.Registry`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/window/registry.ex#L2)

Registry for managing multiple terminal windows.

# `window_id`

```elixir
@type window_id() :: String.t()
```

# `window_state`

```elixir
@type window_state() :: :active | :inactive | :minimized | :maximized
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get_active_window`

```elixir
@spec get_active_window() :: {:ok, Raxol.Terminal.Window.t()} | {:error, term()}
```

Gets the active window.

# `get_window`

```elixir
@spec get_window(window_id()) :: {:ok, Raxol.Terminal.Window.t()} | {:error, term()}
```

Gets a window by ID.

# `handle_manager_cast`

# `handle_manager_info`

# `list_windows`

```elixir
@spec list_windows() :: {:ok, [Raxol.Terminal.Window.t()]}
```

Lists all registered windows.

# `register_window`

```elixir
@spec register_window(map()) :: {:ok, window_id()} | {:error, term()}
```

Registers a new window.

# `set_active_window`

```elixir
@spec set_active_window(window_id()) :: :ok | {:error, term()}
```

Sets the active window.

# `start_link`

# `unregister_window`

```elixir
@spec unregister_window(window_id()) :: :ok | {:error, term()}
```

Unregisters a window.

# `update_window`

```elixir
@spec update_window(String.t(), map()) ::
  {:ok, Raxol.Terminal.Window.t()} | {:error, term()}
```

Updates a window's properties.

# `update_window_state`

```elixir
@spec update_window_state(window_id(), window_state()) :: :ok | {:error, term()}
```

Updates a window's state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
