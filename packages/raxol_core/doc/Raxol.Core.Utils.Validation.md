# `Raxol.Core.Utils.Validation`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/utils/validation.ex#L1)

Common validation utilities to reduce code duplication across the codebase.
Provides standardized validation functions for dimensions, configs, and common patterns.

# `validate_bounds`

```elixir
@spec validate_bounds(number(), number(), number()) ::
  {:ok, number()} | {:error, :out_of_bounds}
```

Validates that a value is within specified bounds.

# `validate_config`

```elixir
@spec validate_config(map(), [atom()]) ::
  {:ok, map()} | {:error, {:missing_keys, [atom()]}}
```

Validates a configuration map against required keys.

# `validate_coordinates`

```elixir
@spec validate_coordinates(integer(), integer()) ::
  {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, :invalid_coordinates}
```

Validates that coordinates are valid non-negative integers.

# `validate_dimension`

```elixir
@spec validate_dimension(integer(), non_neg_integer()) :: non_neg_integer()
```

Validates that a dimension is a positive integer, returning default if invalid.

# `validate_enum`

```elixir
@spec validate_enum(any(), list()) :: {:ok, any()} | {:error, :invalid_option}
```

Validates that a value is one of the allowed options.

# `validate_list_types`

```elixir
@spec validate_list_types(list(), atom()) :: {:ok, list()} | {:error, :invalid_types}
```

Validates that a list contains only specific types.

# `validate_string`

```elixir
@spec validate_string(binary(), Regex.t() | nil) ::
  {:ok, binary()} | {:error, :invalid_string}
```

Validates that a string is not empty and optionally matches a pattern.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
