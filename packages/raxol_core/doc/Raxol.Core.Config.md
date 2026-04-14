# `Raxol.Core.Config`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/config/config.ex#L2)

Pure functional configuration management for Raxol.

This module provides purely functional operations on configuration data.
All functions take config as input and return new config as output - no processes,
no side effects except where explicitly documented.

## Design

Following Rich Hickey's principle: "State is not a service."

Configuration is just data - maps with namespaced sections. There's no need
to serialize read operations through a GenServer mailbox when the data is
immutable between updates.

## Usage

    # Create default config
    config = Config.new()

    # Get/set values
    width = Config.get(config, :terminal, :width)
    config = Config.put(config, :terminal, :width, 120)

    # Merge configs (file load, runtime override)
    config = Config.merge(config, loaded_config)

    # Get entire namespace
    terminal_config = Config.get_namespace(config, :terminal)

## Runtime Storage

For runtime access, use `Raxol.Core.Config.Store` which backs this data
with ETS for fast concurrent reads. This module is the pure functional core.

# `key`

```elixir
@type key() :: atom()
```

# `namespace`

```elixir
@type namespace() ::
  :terminal | :plugins | :performance | :security | :ui | :benchmark
```

# `t`

```elixir
@type t() :: %{
  version: String.t(),
  terminal: map(),
  plugins: map(),
  performance: map(),
  security: map(),
  ui: map(),
  benchmark: map()
}
```

# `value`

```elixir
@type value() :: any()
```

# `from_json`

```elixir
@spec from_json(String.t()) :: {:ok, t()} | {:error, any()}
```

Decodes JSON string to config.

## Examples

    {:ok, config} = Config.from_json(json_string)

# `from_map`

```elixir
@spec from_map(map()) :: t()
```

Creates a config from a map, filling in defaults for missing keys.

# `get`

```elixir
@spec get(t(), namespace(), key(), value()) :: value()
```

Gets a value from config at namespace/key path.

Returns default if namespace or key doesn't exist.

## Examples

    Config.get(config, :terminal, :width)
    Config.get(config, :terminal, :missing, 0)

# `get_namespace`

```elixir
@spec get_namespace(t(), namespace()) :: map()
```

Gets an entire namespace from config.

## Examples

    terminal = Config.get_namespace(config, :terminal)
    # => %{width: 80, height: 24, ...}

# `merge`

```elixir
@spec merge(t(), map()) :: t()
```

Deep merges override config into base config.

Override values take precedence. Nested maps are merged recursively.

## Examples

    base = Config.new()
    override = %{terminal: %{width: 120}}
    config = Config.merge(base, override)
    # config.terminal.width => 120
    # config.terminal.height => 24 (preserved from base)

# `new`

```elixir
@spec new() :: t()
```

Creates a new config with default values for all namespaces.

## Examples

    config = Config.new()
    config.terminal.width  # => 80

# `put`

```elixir
@spec put(t(), namespace(), key(), value()) :: t()
```

Puts a value into config at namespace/key path.

Returns new config (original is unchanged).

## Examples

    config = Config.put(config, :terminal, :width, 120)

# `put_namespace`

```elixir
@spec put_namespace(t(), namespace(), map()) :: t()
```

Puts an entire namespace into config.

## Examples

    config = Config.put_namespace(config, :terminal, %{width: 120, height: 40})

# `reset_namespace`

```elixir
@spec reset_namespace(t(), namespace()) :: t()
```

Resets a namespace to its default values.

## Examples

    config = Config.reset_namespace(config, :terminal)

# `to_json`

```elixir
@spec to_json(t()) :: {:ok, String.t()} | {:error, any()}
```

Encodes config to JSON string.

## Examples

    {:ok, json} = Config.to_json(config)

# `validate_namespace`

```elixir
@spec validate_namespace(namespace(), map()) :: :ok | {:error, [String.t()]}
```

Validates entire namespace config.

Returns `:ok` or `{:error, [errors]}`.

# `validate_value`

```elixir
@spec validate_value(namespace(), key(), value()) :: :ok | {:error, String.t()}
```

Validates config value for a given namespace and key.

Returns `:ok` or `{:error, reason}`.

## Examples

    Config.validate_value(:terminal, :width, 80)   # => :ok
    Config.validate_value(:terminal, :width, -1)   # => {:error, "width must be positive"}

---

*Consult [api-reference.md](api-reference.md) for complete listing*
