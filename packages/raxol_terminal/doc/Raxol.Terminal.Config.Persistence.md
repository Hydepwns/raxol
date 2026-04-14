# `Raxol.Terminal.Config.Persistence`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/config/persistence.ex#L1)

Handles persistence and migration of terminal configurations.

# `list_configs`

```elixir
@spec list_configs() :: {:ok, [String.t()]} | {:error, term()}
```

Lists all saved configurations.

# `load_config`

```elixir
@spec load_config(String.t()) :: {:ok, Raxol.Terminal.Config.t()} | {:error, term()}
```

Loads a configuration from persistent storage.

# `migrate_config`

```elixir
@spec migrate_config(Raxol.Terminal.Config.t()) ::
  {:ok, Raxol.Terminal.Config.t()} | {:error, term()}
```

Migrates a configuration to the latest version.

# `save_config`

```elixir
@spec save_config(Raxol.Terminal.Config.t(), String.t()) :: :ok | {:error, term()}
```

Saves a configuration to persistent storage.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
