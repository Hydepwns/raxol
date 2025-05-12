---
title: Dependency Manager API Reference
description: API documentation for Raxol's plugin dependency manager
date: 2025-06-10
author: Raxol Team
section: components
---

# Dependency Manager API Reference

## Overview

The Dependency Manager provides functions for checking plugin dependencies and resolving load order, with robust error reporting and support for optional dependencies and complex version constraints.

## Public API

### `check_dependencies/4`

```elixir
DependencyManager.check_dependencies(plugin_id, plugin_metadata, loaded_plugins, dependency_chain \\ [])
```

- **plugin_id**: String or atom identifying the plugin
- **plugin_metadata**: Map with at least `:dependencies` key
- **loaded_plugins**: Map of currently loaded plugins (id => metadata)
- **dependency_chain**: (optional) List of plugin IDs for error reporting

**Returns:**

- `:ok` — All dependencies satisfied
- `{:error, :missing_dependencies, [missing], chain}` — Required dependencies missing
- `{:error, :version_mismatch, [{id, version, requirement}], chain}` — Version mismatch (optional dependencies with version mismatches are ignored)
- `{:error, :circular_dependency, cycle, chain}` — Circular dependency detected (only true cycles are flagged)

### `resolve_load_order/1`

```elixir
DependencyManager.resolve_load_order(plugins)
```

- **plugins**: Map of plugin metadata, keyed by plugin ID

**Returns:**

- `{:ok, load_order}` — List of plugin IDs in correct load order (unique, no duplicates)
- `{:error, :circular_dependency, cycle, chain}` — Cycle detected

## Dependency Graph Structure

```elixir
%{
  "plugin_id" => [
    {"dependency_id", "version_requirement", %{optional: boolean()}},
    # ...
  ],
  # ...
}
```

## Error Tuple Formats

- `{:error, :missing_dependencies, [missing], chain}`
- `{:error, :version_mismatch, [{id, version, requirement}], chain}`
- `{:error, :circular_dependency, cycle, chain}`

**Note:** Optional dependencies with version mismatches are ignored and do not cause errors.

## Cycle Detection

- Only true cycles (mutually reachable nodes) are flagged as errors.
- Tarjan's algorithm is used for efficient cycle detection and unique load order.

**Example:**

```elixir
A → B → C
↑   ↓   ↓
└── D ← E
```

- Edges: A→B, B→C, C→E, E→D, D→A, B→D
- Tarjan's algorithm will find the cycle: [A, B, C, D, E]
- The load order will be unique and each plugin appears only once.

## Best Practices

- Use semantic versioning and clear version constraints
- Keep dependency chains shallow
- Use optional dependencies for non-critical features
- Always check return values and handle errors
