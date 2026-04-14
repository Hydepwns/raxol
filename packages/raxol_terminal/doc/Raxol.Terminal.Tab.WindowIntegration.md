# `Raxol.Terminal.Tab.WindowIntegration`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/tab/window_integration.ex#L1)

Integration module for managing tabs and their associated windows.

# `t`

```elixir
@type t() :: %{tabs: map()}
```

# `create_window_for_tab`

```elixir
@spec create_window_for_tab(t(), String.t(), map()) ::
  {:ok, String.t(), t(), map()} | {:error, term()}
```

Creates a window for an existing tab (3-arity version).

# `create_window_for_tab`

```elixir
@spec create_window_for_tab(t(), String.t(), map(), map()) ::
  {:ok, String.t(), t(), map()} | {:error, term()}
```

Creates a window for an existing tab.

# `destroy_window_for_tab`

```elixir
@spec destroy_window_for_tab(t(), String.t(), map()) ::
  {:ok, t(), map()} | {:error, term()}
```

Destroys the window for an existing tab.

# `get_window_for_tab`

```elixir
@spec get_window_for_tab(t(), String.t()) :: {:ok, String.t()} | {:error, term()}
```

Gets the window ID for an existing tab.

# `switch_to_tab`

```elixir
@spec switch_to_tab(t(), map(), String.t()) ::
  {:ok, map(), map()} | {:error, :tab_not_found}
```

Switches to an existing tab and its window.

# `update_window_for_tab`

```elixir
@spec update_window_for_tab(t(), String.t(), map(), map()) ::
  {:ok, t(), map()} | {:error, term()}
```

Updates the window configuration for an existing tab.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
