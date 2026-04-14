# `Raxol.Core.Accessibility.Behaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/accessibility/behaviour.ex#L1)

Behaviour for accessibility implementations.

# `announce`

```elixir
@callback announce(message :: String.t(), opts :: keyword()) :: :ok
```

# `announce`

```elixir
@callback announce(
  message :: String.t(),
  opts :: keyword(),
  user_preferences_pid_or_name :: atom() | pid() | nil
) :: :ok
```

# `clear_announcements`

```elixir
@callback clear_announcements() :: :ok
```

# `disable`

```elixir
@callback disable(user_preferences_pid_or_name :: atom() | pid() | nil) :: :ok
```

# `enable`

```elixir
@callback enable(
  options :: keyword() | map(),
  user_preferences_pid_or_name :: atom() | pid() | nil
) :: :ok
```

# `enabled?`

```elixir
@callback enabled?() :: boolean()
```

# `get_component_hint`

```elixir
@callback get_component_hint(
  component_id :: atom(),
  hint_level :: :basic | :detailed
) :: String.t() | nil
```

# `get_component_style`

```elixir
@callback get_component_style(component_type :: atom()) :: map()
```

# `get_element_metadata`

```elixir
@callback get_element_metadata(element_id :: String.t()) :: map() | nil
```

# `get_focus_history`

```elixir
@callback get_focus_history() :: [String.t() | nil]
```

# `get_next_announcement`

```elixir
@callback get_next_announcement(user_preferences_pid_or_name :: atom() | pid() | nil) ::
  String.t() | nil
```

# `get_option`

```elixir
@callback get_option(key :: atom(), default :: any()) :: any()
```

# `register_component_style`

```elixir
@callback register_component_style(
  component_type :: atom(),
  style :: map()
) :: :ok
```

# `register_element_metadata`

```elixir
@callback register_element_metadata(
  element_id :: String.t(),
  metadata :: map()
) :: :ok
```

# `set_large_text`

```elixir
@callback set_large_text(
  enabled :: boolean(),
  user_preferences_pid_or_name :: atom() | pid() | nil
) :: :ok
```

# `set_option`

```elixir
@callback set_option(key :: atom(), value :: any()) :: :ok
```

# `unregister_component_style`

```elixir
@callback unregister_component_style(component_type :: atom()) :: :ok
```

# `unregister_element_metadata`

```elixir
@callback unregister_element_metadata(element_id :: String.t()) :: :ok
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
