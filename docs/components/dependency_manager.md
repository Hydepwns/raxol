# Dependency Manager Module Architecture

> **See Also:** <!-- TODO: Dependency Manager API Reference link removed: components/api/dependency_manager.md -->

## Overview

The Dependency Manager module is responsible for managing plugin dependencies and resolving load order. It has been refactored into a modular architecture to improve maintainability, testability, and separation of concerns.

## Module Structure

### Main Module: `Raxol.Core.Runtime.Plugins.DependencyManager`

The main module serves as the public API and delegates to specialized submodules. It provides a clean interface for:

- Checking plugin dependencies
- Resolving plugin load order
- Managing version constraints
- Detecting dependency cycles

### Submodules

#### 1. `DependencyManager.Core`

- **Responsibility**: Core dependency checking and load order resolution
- **Key Functions**:
  - `check_dependencies/4`: Verifies if a plugin's dependencies are satisfied
  - `resolve_load_order/1`: Determines the correct load order for plugins
- **Features**:
  - Dependency validation
  - Optional dependency handling (version mismatches for optional dependencies are ignored and do not block plugin loading)
  - Error reporting with dependency chains

#### 2. `DependencyManager.Version`

- **Responsibility**: Version parsing and constraint checking
- **Key Functions**:
  - `check_version/2`: Validates version compatibility
  - `parse_version_requirement/1`: Parses version requirement strings
- **Features**:
  - Complex version constraint parsing
  - OR condition support
  - Detailed error reporting

#### 3. `DependencyManager.Graph`

- **Responsibility**: Dependency graph building and analysis
- **Key Functions**:
  - `build_dependency_graph/1`: Creates a dependency graph from plugin metadata
  - `build_dependency_chain/2`: Constructs dependency chains for error reporting
  - `get_all_dependencies/3`: Retrieves all dependencies for a plugin
- **Features**:
  - Graph construction
  - Cycle detection
  - Dependency chain analysis

#### 4. `DependencyManager.Resolver`

- **Responsibility**: Load order resolution using Tarjan's algorithm
- **Key Functions**:
  - `tarjan_sort/1`: Performs topological sorting of the dependency graph
- **Features**:
  - Efficient cycle detection (only true cycles are flagged, not just any strongly connected component)
  - Strongly connected component identification
  - Topological ordering (load order is unique, no duplicate plugin IDs)
  - Detailed error chains for self-loops and mutual dependencies

## State Management

The Dependency Manager maintains the following state in the dependency graph:

```elixir
%{
  "plugin_id" => [
    {"dependency_id", "version_requirement", %{optional: boolean()}},
    # ... more dependencies
  ],
  # ... more plugins
}
```

## Error Handling

The module implements comprehensive error handling:

- Missing dependencies
- Version mismatches (optional dependencies with version mismatches are ignored)
- Circular dependencies (only true cycles are flagged)
- Invalid version formats
- Invalid requirement formats

Each error type includes detailed information for debugging:

```elixir
{:error, :missing_dependencies, ["missing_plugin"], ["plugin_a", "plugin_b"]}
{:error, :version_mismatch, [{"plugin", "1.0.0", ">= 2.0.0"}], ["plugin_a"]}
{:error, :circular_dependency, ["plugin_a", "plugin_b"], ["plugin_a", "plugin_b", "plugin_a"]}
```

## Cycle Detection Example (Tarjan's Algorithm)

Consider the following dependency graph:

```elixir
A → B → C
↑   ↓   ↓
└── D ← E
```

- Edges: A→B, B→C, C→E, E→D, D→A, B→D
- Tarjan's algorithm will find the cycle: [A, B, C, D, E]
- The load order will be unique and each plugin appears only once.
- Only true cycles (mutually reachable nodes) are flagged as errors.

## Usage Example

```elixir
# Check plugin dependencies
case DependencyManager.check_dependencies("my_plugin", metadata, loaded_plugins) do
  :ok ->
    # Dependencies satisfied
  {:error, :missing_dependencies, missing, chain} ->
    # Handle missing dependencies
  {:error, :version_mismatch, mismatches, chain} ->
    # Handle version mismatches
  {:error, :circular_dependency, cycle, chain} ->
    # Handle circular dependency
end

# Resolve load order
case DependencyManager.resolve_load_order(plugins) do
  {:ok, load_order} ->
    # Load plugins in order
  {:error, :circular_dependency, cycle, chain} ->
    # Handle circular dependency
end
```

## Best Practices

1. **Version Constraints**:

   - Use semantic versioning
   - Be specific with version requirements
   - Consider using version ranges for flexibility

2. **Dependency Management**:

   - Keep dependency chains shallow
   - Avoid circular dependencies
   - Use optional dependencies when appropriate

3. **Error Handling**:

   - Always check return values
   - Provide meaningful error messages
   - Log dependency issues appropriately

4. **Testing**:
   - Test all error cases
   - Verify version constraint handling
   - Test complex dependency scenarios
   - Verify cycle detection
