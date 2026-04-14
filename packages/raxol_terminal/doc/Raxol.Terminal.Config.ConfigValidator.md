# `Raxol.Terminal.Config.ConfigValidator`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/config/config_validator.ex#L1)

Validates terminal configuration settings.

# `validation_result`

```elixir
@type validation_result() :: :ok | {:error, String.t()}
```

# `validate_config`

```elixir
@spec validate_config(Raxol.Terminal.Config.t()) :: validation_result()
```

Validates a complete configuration.

# `validate_update`

```elixir
@spec validate_update(Raxol.Terminal.Config.t(), map()) :: validation_result()
```

Validates a configuration update.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
