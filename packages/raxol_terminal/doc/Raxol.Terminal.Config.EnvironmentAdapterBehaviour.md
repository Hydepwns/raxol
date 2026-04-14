# `Raxol.Terminal.Config.EnvironmentAdapterBehaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/config/environment_adapter_behaviour.ex#L1)

Defines the behaviour for terminal environment configuration.

This behaviour is responsible for:
- Managing terminal environment variables
- Handling terminal configuration
- Providing environment-specific settings
- Adapting to different terminal environments

# `get_all_env`

```elixir
@callback get_all_env() :: {:ok, map()} | {:error, any()}
```

Gets all environment variables.

# `get_env`

```elixir
@callback get_env(key :: String.t()) :: {:ok, String.t()} | {:error, any()}
```

Gets the value of an environment variable.

# `get_terminal_config`

```elixir
@callback get_terminal_config() :: {:ok, map()} | {:error, any()}
```

Gets terminal-specific configuration.

# `get_terminal_type`

```elixir
@callback get_terminal_type() :: {:ok, String.t()} | {:error, any()}
```

Gets the current terminal type.

# `set_env`

```elixir
@callback set_env(key :: String.t(), value :: String.t()) :: :ok | {:error, any()}
```

Sets an environment variable.

# `supports_feature?`

```elixir
@callback supports_feature?(feature :: atom()) :: boolean()
```

Checks if a specific terminal feature is supported.

# `update_terminal_config`

```elixir
@callback update_terminal_config(config :: map()) :: :ok | {:error, any()}
```

Updates terminal configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
