# `Raxol.Core.Runtime.Plugins.PluginsState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugins_state.ex#L1)

Defines the state struct for the plugin manager.

# `t`

```elixir
@type t() :: %Raxol.Core.Runtime.Plugins.PluginsState{
  command_registry_table: map(),
  file_event_timer: reference() | nil,
  file_watcher_pid: pid() | nil,
  file_watching_enabled?: boolean(),
  initialized: boolean(),
  lifecycle_helper_module: module(),
  load_order: [String.t()],
  metadata: %{required(String.t()) =&gt; map()},
  plugin_config: %{required(String.t()) =&gt; map()},
  plugin_id: String.t() | nil,
  plugin_path: String.t() | nil,
  plugin_states: %{required(String.t()) =&gt; map()},
  plugins: %{required(String.t()) =&gt; module()},
  plugins_dir: String.t() | nil,
  runtime_pid: pid() | nil
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
