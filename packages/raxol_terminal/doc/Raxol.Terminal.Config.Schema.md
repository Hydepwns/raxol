# `Raxol.Terminal.Config.Schema`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/config/schema.ex#L1)

Schema definitions for terminal configuration.

Defines the structure and types for all terminal configuration options.

# `config_schema`

Defines the schema for terminal configuration.

This includes all possible configuration fields with their types,
default values, and descriptions.

# `default_config`

Returns the default configuration values.
This delegates to the Defaults module for actual values.

# `get_type`

Returns the type information for a specific configuration path.

## Parameters

* `path` - A list of keys representing the path to the configuration value

## Returns

A tuple with type information or nil if the path doesn't exist

# `schema`

# `test_schema`

Returns the schema in a format compatible with validation tests.
Each field is a map with a :type key.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
