# `Raxol.Plugin.Manifest`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/plugin/manifest.ex#L1)

Cross-package-safe manifest builder for Raxol plugins.

Wraps the core `Raxol.Core.Runtime.Plugins.Manifest` struct as a plain
map so that consumers in separate packages do not need a compile-time
dependency on the struct definition.

## Usage

    manifest = Raxol.Plugin.Manifest.new(
      id: :my_plugin,
      name: "My Plugin",
      version: "1.0.0",
      module: MyPlugin
    )

    case Raxol.Plugin.Manifest.validate(manifest) do
      :ok -> IO.puts("valid")
      {:error, errors} -> IO.inspect(errors)
    end

# `t`

```elixir
@type t() :: %{
  id: atom(),
  name: String.t(),
  version: String.t(),
  author: String.t(),
  api_version: String.t(),
  description: String.t(),
  module: module(),
  depends_on: [{atom(), String.t()}],
  conflicts_with: [atom()],
  provides: [atom()],
  requires: [atom()],
  resource_budget: map()
}
```

# `default_budget`

```elixir
@spec default_budget() :: map()
```

Returns the default resource budget.

# `new`

```elixir
@spec new(keyword()) :: t()
```

Builds a manifest map from keyword options.

Returns a plain map (not a struct) for cross-package compatibility.

## Required keys

  * `:id` - Plugin identifier (atom)
  * `:name` - Human-readable name
  * `:version` - Semver version string
  * `:module` - Plugin module

## Optional keys

  * `:author` - Author name (default: `""`)
  * `:api_version` - API version (default: `"1.0"`)
  * `:description` - Description (default: `""`)
  * `:depends_on` - Dependencies as `[{atom, version_string}]` (default: `[]`)
  * `:conflicts_with` - Conflicting plugin IDs (default: `[]`)
  * `:provides` - Capabilities provided (default: `[]`)
  * `:requires` - Capabilities required (default: `[]`)
  * `:resource_budget` - Resource limits map (default: standard budget)

# `supported_api_versions`

```elixir
@spec supported_api_versions() :: [String.t()]
```

Returns the list of supported API versions.

# `validate`

```elixir
@spec validate(t()) :: :ok | {:error, [String.t()]}
```

Validates a manifest map for completeness and correctness.

Returns `:ok` or `{:error, [String.t()]}` with a list of validation errors.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
