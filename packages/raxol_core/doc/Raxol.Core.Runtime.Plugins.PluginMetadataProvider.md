# `Raxol.Core.Runtime.Plugins.PluginMetadataProvider`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugin_metadata_provider.ex#L1)

Defines the behaviour for plugins that provide metadata like ID, version, and dependencies.

Plugins can optionally implement this behaviour to declare their metadata,
which the plugin manager uses for dependency resolution and management.

# `metadata`

```elixir
@type metadata() :: %{
  id: atom(),
  version: String.t(),
  dependencies: [{atom(), String.t()}]
}
```

Represents the metadata for a plugin.
- `id`: A unique atom identifying the plugin (e.g., `:my_plugin`).
- `version`: A string representing the plugin version (e.g., "0.1.0").
- `dependencies`: A list of tuples {plugin_id, version_requirement} that this plugin depends on.

# `get_metadata`

```elixir
@callback get_metadata() :: metadata()
```

Callback invoked by the plugin manager to retrieve the plugin's metadata.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
