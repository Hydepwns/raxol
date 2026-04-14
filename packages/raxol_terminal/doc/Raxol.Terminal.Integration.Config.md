# `Raxol.Terminal.Integration.Config`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/integration/integration_config.ex#L1)

Manages configuration for the terminal integration.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Integration.Config{
  behavior: map(),
  memory_limit: integer(),
  rendering: map()
}
```

# `apply_config_changes`

Applies configuration changes to the terminal state.

# `default_config`

Returns the default configuration.

# `get_config_value`

Gets a specific configuration value.

# `get_emulator_config`

Gets emulator configuration.

# `reset_config`

Resets the configuration to default values.

# `set_config_value`

Sets a specific configuration value.

# `update_buffer_manager`

Updates the buffer manager configuration.

# `update_config`

Updates the terminal configuration.

Merges the provided `opts` into the current configuration and validates
the result before applying.

# `update_renderer_config`

Updates the renderer configuration.

# `update_scroll_buffer`

Updates the scroll buffer configuration.

# `validate_config`

```elixir
@spec validate_config(map()) :: :ok | {:error, atom()}
```

Validates the configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
