# `Raxol.Core.KeyboardShortcutsBehaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/keyboard_shortcuts_behaviour.ex#L1)

Behavior for KeyboardShortcuts implementation.

This defines the expected interface for keyboard shortcuts functionality
used by the UX refinement system.

# `cleanup`

```elixir
@callback cleanup() :: :ok | {:error, term()}
```

Clean up the keyboard shortcuts system.

# `get_available_shortcuts`

```elixir
@callback get_available_shortcuts() :: [map()]
```

Get available shortcuts for the current context.

# `get_shortcuts_for_context`

```elixir
@callback get_shortcuts_for_context(context :: atom() | nil) :: term()
```

Get shortcuts for a specific context.

# `handle_keyboard_event`

```elixir
@callback handle_keyboard_event(atom(), term()) :: :ok | {:error, term()}
```

Handle keyboard events.

# `init`

```elixir
@callback init() :: :ok | {:error, term()}
```

Initialize the keyboard shortcuts system.

# `register_shortcut`

```elixir
@callback register_shortcut(
  shortcut_key :: String.t(),
  name :: String.t(),
  callback :: function(),
  opts :: Keyword.t()
) :: :ok | {:error, term()}
```

Register a keyboard shortcut with callback.

# `set_context`

```elixir
@callback set_context(context :: atom()) :: :ok | {:error, term()}
```

Set the current shortcuts context.

# `show_shortcuts_help`

```elixir
@callback show_shortcuts_help(user_prefs :: term()) :: :ok | {:error, term()}
```

Show shortcuts help.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
