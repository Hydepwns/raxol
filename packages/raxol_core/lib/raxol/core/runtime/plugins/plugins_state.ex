defmodule Raxol.Core.Runtime.Plugins.PluginsState do
  @moduledoc """
  Defines the state struct for the plugin manager.
  """

  defstruct [
    :runtime_pid,
    :lifecycle_helper_module,
    :plugin_id,
    :plugin_path,
    :plugins,
    :metadata,
    :plugin_states,
    :load_order,
    :command_registry_table,
    :plugin_config,
    :initialized,
    :plugins_dir,
    :file_watcher_pid,
    :file_watching_enabled?,
    :file_event_timer
  ]

  @type t :: %__MODULE__{
          runtime_pid: pid() | nil,
          lifecycle_helper_module: module(),
          plugin_id: String.t() | nil,
          plugin_path: String.t() | nil,
          plugins: %{String.t() => module()},
          metadata: %{String.t() => map()},
          plugin_states: %{String.t() => map()},
          load_order: [String.t()],
          command_registry_table: map(),
          plugin_config: %{String.t() => map()},
          initialized: boolean(),
          plugins_dir: String.t() | nil,
          file_watcher_pid: pid() | nil,
          file_watching_enabled?: boolean(),
          file_event_timer: reference() | nil
        }
end
