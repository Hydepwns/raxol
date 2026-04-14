# `Raxol.Terminal.Config.Application`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/config/application.ex#L1)

Terminal configuration application.

This module handles applying configuration settings to the terminal,
ensuring all changes are properly propagated throughout the system.

# `apply_config`

Applies a configuration to the terminal.

This function takes a configuration and applies it to the current terminal
instance, updating the terminal state and behavior.

## Parameters

* `config` - The configuration to apply
* `terminal_pid` - The PID of the terminal process (optional)

## Returns

`{:ok, applied_config}` or `{:error, reason}`

# `apply_partial_config`

Applies a partial configuration update to the terminal.

This allows updating only specific parts of the configuration without
changing other settings.

## Parameters

* `partial_config` - The partial configuration to apply
* `terminal_pid` - The PID of the terminal process (optional)

## Returns

`{:ok, updated_config}` or `{:error, reason}`

# `get_current_config`

Gets the current terminal configuration.

## Parameters

* `terminal_pid` - The PID of the terminal process (optional)

## Returns

The current terminal configuration.

# `reset_config`

Resets terminal configuration to default values.

## Parameters

* `terminal_pid` - The PID of the terminal process (optional)
* `optimize` - Whether to optimize for detected capabilities (default: true)

## Returns

`{:ok, default_config}` or `{:error, reason}`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
