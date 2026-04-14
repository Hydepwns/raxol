# `Raxol.Core.Runtime.Plugins.Manifest`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/manifest.ex#L1)

Declarative plugin metadata struct.

Replaces ad-hoc metadata maps with a typed struct consumed by
the validator, dependency resolver, and mission profile system.

Plugins declare a `manifest/0` function returning a map, which
`from_module/1` normalizes into this struct.

# `resource_budget`

```elixir
@type resource_budget() :: %{
  max_memory_mb: number(),
  max_cpu_percent: number(),
  max_ets_tables: non_neg_integer(),
  max_processes: non_neg_integer()
}
```

# `t`

```elixir
@type t() :: %Raxol.Core.Runtime.Plugins.Manifest{
  api_version: String.t(),
  author: String.t(),
  conflicts_with: [atom()],
  depends_on: [{atom(), String.t()}],
  description: String.t(),
  id: atom(),
  module: module(),
  name: String.t(),
  provides: [atom()],
  requires: [atom()],
  resource_budget: resource_budget(),
  version: String.t()
}
```

# `compatible?`

```elixir
@spec compatible?(t(), t()) :: boolean()
```

Checks whether two manifests are compatible (no conflicts).

# `default_budget`

```elixir
@spec default_budget() :: resource_budget()
```

Returns the default resource budget for plugins.

# `from_module`

```elixir
@spec from_module(module()) :: {:ok, t()} | {:error, term()}
```

Builds a Manifest from a module that implements `manifest/0`.

Returns `{:error, :no_manifest}` if the module doesn't export it.

# `validate`

```elixir
@spec validate(t()) :: :ok | {:error, [String.t()]}
```

Validates a manifest struct for completeness and correctness.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
