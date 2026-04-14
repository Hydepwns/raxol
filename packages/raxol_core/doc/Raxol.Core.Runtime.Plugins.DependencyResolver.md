# `Raxol.Core.Runtime.Plugins.DependencyResolver`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/dependency_resolver.ex#L1)

Install-time and load-time dependency resolution for plugins.

Uses Kahn's algorithm for topological sort with cycle detection,
conflict checking, and capability matching.

# `reason`

```elixir
@type reason() ::
  {:cycle, [atom()]}
  | {:missing, plugin :: atom(), dependency :: atom()}
  | {:conflict, atom(), atom()}
  | {:unmet_capability, plugin :: atom(), capability :: atom()}
```

# `resolution`

```elixir
@type resolution() :: {:ok, load_order :: [atom()]} | {:error, reason()}
```

# `check_conflicts`

```elixir
@spec check_conflicts([Raxol.Core.Runtime.Plugins.Manifest.t()]) ::
  :ok | {:error, {:conflict, atom(), atom()}}
```

Checks for conflicts between manifests.

# `resolve`

```elixir
@spec resolve([Raxol.Core.Runtime.Plugins.Manifest.t()]) :: resolution()
```

Resolves load order for a set of manifests using topological sort.

Returns `{:ok, [plugin_id]}` in dependency order (dependencies first),
or `{:error, reason}` on failure.

# `resolve_incremental`

```elixir
@spec resolve_incremental(
  [Raxol.Core.Runtime.Plugins.Manifest.t()],
  already_loaded :: [atom()]
) ::
  resolution()
```

Resolves load order for new manifests given already-loaded plugin ids.

Treats `already_loaded` as satisfied dependencies that don't need ordering.

# `satisfy_capabilities`

```elixir
@spec satisfy_capabilities([Raxol.Core.Runtime.Plugins.Manifest.t()]) ::
  :ok | {:error, {:unmet_capability, atom(), atom()}}
```

Checks that all `requires` capabilities are satisfied by some plugin's `provides`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
