# `RaxolPlugin`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol_plugin.ex#L1)

Plugin SDK for Raxol terminal applications.

Provides the tools to build, test, and manage Raxol plugins:

  * `Raxol.Plugin` - `use` macro with overridable callback defaults
  * `Raxol.Plugin.API` - Facade for loading/unloading/enabling plugins at runtime
  * `Raxol.Plugin.Manifest` - Cross-package manifest builder and validator
  * `Raxol.Plugin.Testing` - ExUnit helpers for plugin test suites
  * `mix raxol.gen.plugin` - Code generator for new plugins

## Quick start

    defmodule MyPlugin do
      use Raxol.Plugin

      @impl true
      def init(config), do: {:ok, %{config: config}}
    end

See `Raxol.Plugin` for the full callback list and defaults.

# `version`

```elixir
@spec version() :: String.t()
```

Returns the package version.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
