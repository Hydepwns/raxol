# `Raxol.Terminal.Config`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/terminal_config.ex#L1)

Handles terminal settings and behavior, including:
- Terminal dimensions
- Color settings
- Input handling
- Terminal state management
- Configuration validation
- Configuration persistence

# `t`

```elixir
@type t() :: %Raxol.Terminal.Config{
  colors: map(),
  height: non_neg_integer(),
  input: map(),
  mode: map(),
  performance: map(),
  styles: map(),
  version: integer(),
  width: non_neg_integer()
}
```

# `get_colors`

Gets the current color settings.

## Parameters

* `config` - The current configuration

## Returns

A map containing the current color settings.

# `get_dimensions`

Gets the current terminal dimensions.

## Parameters

* `config` - The current configuration

## Returns

A tuple `{width, height}` with the current dimensions.

# `get_input`

Gets the current input handling settings.

## Parameters

* `config` - The current configuration

## Returns

A map containing the current input settings.

# `get_mode`

Gets the current terminal mode settings.

## Parameters

* `config` - The current configuration

## Returns

A map containing the current mode settings.

# `get_performance`

Gets the current performance settings.

## Parameters

* `config` - The current configuration

## Returns

A map containing the current performance settings.

# `get_styles`

Gets the current style settings.

## Parameters

* `config` - The current configuration

## Returns

A map containing the current style settings.

# `list_saved`

Lists all saved configurations.

# `load`

Loads a configuration from persistent storage.

# `merge_opts`

Merges a map of options with the current configuration.
Validates the options before merging.

## Parameters

* `config` - The current configuration
* `opts` - A map of options to merge

## Returns

The updated configuration with merged options.

# `new`

Creates a new terminal configuration with default values.

## Returns

A new `t:Raxol.Terminal.Config.t/0` struct with default values.

# `new`

Creates a new terminal configuration with custom dimensions.

## Parameters

* `width` - The terminal width in characters
* `height` - The terminal height in characters

## Returns

A new `t:Raxol.Terminal.Config.t/0` struct with the specified dimensions.

# `save`

Saves the configuration to persistent storage.

# `set_colors`

Updates the color settings.

## Parameters

* `config` - The current configuration
* `colors` - A map of color settings to update

## Returns

The updated configuration with new color settings.

# `set_dimensions`

Updates the terminal dimensions.

## Parameters

* `config` - The current configuration
* `width` - The new terminal width
* `height` - The new terminal height

## Returns

The updated configuration with new dimensions.

# `set_input`

Updates the input handling settings.

## Parameters

* `config` - The current configuration
* `input` - A map of input settings to update

## Returns

The updated configuration with new input settings.

# `set_mode`

Updates the terminal mode settings.

## Parameters

* `config` - The current configuration
* `mode` - A map of mode settings to update

## Returns

The updated configuration with new mode settings.

# `set_performance`

Updates the performance settings.

## Parameters

* `config` - The current configuration
* `performance` - A map of performance settings to update

## Returns

The updated configuration with new performance settings.

# `set_styles`

Updates the style settings.

## Parameters

* `config` - The current configuration
* `styles` - A map of style settings to update

## Returns

The updated configuration with new style settings.

# `update`

Updates the terminal configuration with validation.

# `validate_config`

Validates a configuration map.
Checks for required fields and valid values.

## Parameters

* `config` - The configuration to validate

## Returns

`:ok` if the configuration is valid, `{:error, reason}` otherwise.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
