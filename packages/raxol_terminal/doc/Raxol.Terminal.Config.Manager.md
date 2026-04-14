# `Raxol.Terminal.Config.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/config/terminal_config_manager.ex#L1)

Manages terminal configuration including settings, preferences, and environment variables.
This module is responsible for handling configuration operations and state.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear_environment`

```elixir
@spec clear_environment(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
```

Clears all environment variables.
Returns the updated emulator.

# `get_all_environment`

```elixir
@spec get_all_environment(Raxol.Terminal.Emulator.t()) :: %{
  required(String.t()) =&gt; String.t()
}
```

Gets all environment variables.
Returns the map of environment variables.

# `get_environment`

```elixir
@spec get_environment(Raxol.Terminal.Emulator.t(), String.t()) :: String.t() | nil
```

Gets an environment variable.
Returns the environment variable value or nil.

# `get_preference`

```elixir
@spec get_preference(Raxol.Terminal.Emulator.t(), atom()) :: any()
```

Gets a preference value.
Returns the preference value or nil.

# `get_setting`

```elixir
@spec get_setting(Raxol.Terminal.Emulator.t(), atom()) :: any()
```

Gets a configuration setting.
Returns the setting value or nil.

# `handle_manager_cast`

# `handle_manager_info`

# `new`

```elixir
@spec new() :: Raxol.Terminal.Config.t()
```

Creates a new config manager.

# `reset_config_manager`

```elixir
@spec reset_config_manager(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
```

Resets the config manager to its initial state.
Returns the updated emulator.

# `set_environment`

```elixir
@spec set_environment(Raxol.Terminal.Emulator.t(), String.t(), String.t()) ::
  Raxol.Terminal.Emulator.t()
```

Sets an environment variable.
Returns the updated emulator.

# `set_environment_variables`

```elixir
@spec set_environment_variables(Raxol.Terminal.Emulator.t(), %{
  required(String.t()) =&gt; String.t()
}) ::
  Raxol.Terminal.Emulator.t()
```

Sets multiple environment variables.
Returns the updated emulator.

# `set_preference`

```elixir
@spec set_preference(Raxol.Terminal.Emulator.t(), atom(), any()) ::
  Raxol.Terminal.Emulator.t()
```

Sets a preference value.
Returns the updated emulator.

# `set_setting`

```elixir
@spec set_setting(Raxol.Terminal.Emulator.t(), atom(), any()) ::
  Raxol.Terminal.Emulator.t()
```

Sets a configuration setting.
Returns the updated emulator.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
