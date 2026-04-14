# `Raxol.Terminal.Config.Validation`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/config/config_validation.ex#L1)

Validation logic for terminal configuration.

Ensures that configuration values are valid according to their schema.

# `validate_config`

Validates a complete terminal configuration.

## Parameters

* `config` - The configuration to validate

## Returns

`{:ok, validated_config}` or `{:error, reason}`

# `validate_update`

Validates configuration updates against the schema.

## Parameters

* `config` - The current configuration
* `updates` - The updates to validate

## Returns

`:ok` or `{:error, reason}`

# `validate_value`

Validates a specific configuration value against its schema.

## Parameters

* `path` - A list of keys representing the path to the configuration value
* `value` - The value to validate

## Returns

`{:ok, validated_value}` or `{:error, reason}`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
