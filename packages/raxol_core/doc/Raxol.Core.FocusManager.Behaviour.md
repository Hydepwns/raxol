# `Raxol.Core.FocusManager.Behaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/focus_manager_behaviour.ex#L1)

Defines the behaviour for focus management services.

# `disable_component`

```elixir
@callback disable_component(component_id :: String.t()) :: :ok
```

Disables a focusable component.

# `enable_component`

```elixir
@callback enable_component(component_id :: String.t()) :: :ok
```

Enables a previously disabled focusable component.

# `focus_next`

```elixir
@callback focus_next(opts :: Keyword.t()) :: :ok
```

Moves focus to the next focusable element.

# `focus_previous`

```elixir
@callback focus_previous(opts :: Keyword.t()) :: :ok
```

Moves focus to the previous focusable element.

# `get_current_focus`

```elixir
@callback get_current_focus() :: String.t() | nil
```

Alias for get_focused_element/0.

# `get_focus_history`

```elixir
@callback get_focus_history() :: [String.t() | nil]
```

Gets the focus history.

# `get_focused_element`

```elixir
@callback get_focused_element() :: String.t() | nil
```

Gets the ID of the currently focused element.

# `get_next_focusable`

```elixir
@callback get_next_focusable(current_focus_id :: String.t() | nil) :: String.t() | nil
```

Gets the next focusable element after the given one.

# `get_previous_focusable`

```elixir
@callback get_previous_focusable(current_focus_id :: String.t() | nil) :: String.t() | nil
```

Gets the previous focusable element before the given one.

# `has_focus?`

```elixir
@callback has_focus?(component_id :: String.t()) :: boolean()
```

Checks if a component has focus.

# `register_focus_change_handler`

```elixir
@callback register_focus_change_handler(
  handler_fun :: (String.t() | nil, String.t() | nil -&gt; any())
) :: :ok
```

Registers a handler function to be called when focus changes.
The handler function should accept two arguments: `old_focus` and `new_focus`.

# `register_focusable`

```elixir
@callback register_focusable(
  component_id :: String.t(),
  tab_index :: integer(),
  opts :: Keyword.t()
) :: :ok
```

Registers a focusable component.

# `return_to_previous`

```elixir
@callback return_to_previous() :: :ok
```

Returns to the previously focused element.

# `set_focus`

```elixir
@callback set_focus(component_id :: String.t()) :: :ok
```

Sets focus to a specific component.

# `set_initial_focus`

```elixir
@callback set_initial_focus(component_id :: String.t()) :: :ok
```

Sets the initial focus to a specific component.

# `unregister_focus_change_handler`

```elixir
@callback unregister_focus_change_handler(
  handler_fun :: (String.t() | nil, String.t() | nil -&gt; any())
) ::
  :ok
```

Unregisters a focus change handler function.

# `unregister_focusable`

```elixir
@callback unregister_focusable(component_id :: String.t()) :: :ok
```

Unregisters a focusable component.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
