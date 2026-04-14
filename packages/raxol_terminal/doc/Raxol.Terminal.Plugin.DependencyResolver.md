# `Raxol.Terminal.Plugin.DependencyResolver`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/plugin/dependency_resolver.ex#L1)

Handles plugin dependency resolution for the terminal emulator.
This module extracts the plugin dependency resolution logic from the main emulator.

# `calculate_in_degree`

```elixir
@spec calculate_in_degree(map(), [String.t()]) :: map()
```

Calculates the in-degree for each node in the dependency graph.

# `extract_plugin_dependencies`

```elixir
@spec extract_plugin_dependencies([map()]) :: map()
```

Extracts dependencies from a list of plugins.

# `resolve_plugin_dependencies`

```elixir
@spec resolve_plugin_dependencies(map()) :: [String.t()]
```

Resolves plugin dependencies and returns the load order.

# `topological_sort`

```elixir
@spec topological_sort(map()) :: {:ok, [String.t()]} | {:error, atom()}
```

Performs topological sorting on plugin dependencies.

# `topological_sort_helper`

```elixir
@spec topological_sort_helper(map(), map(), [String.t()], [String.t()]) :: [
  String.t()
]
```

Helper function for topological sorting using Kahn's algorithm.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
