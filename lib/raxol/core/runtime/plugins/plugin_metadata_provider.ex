defmodule Raxol.Core.Runtime.Plugins.PluginMetadataProvider do
  @moduledoc """
  Defines the behaviour for plugins that provide metadata like ID, version, and dependencies.

  Plugins can optionally implement this behaviour to declare their metadata,
  which the `PluginManager` uses for dependency resolution and management.
  """

  @typedoc """
  Represents the metadata for a plugin.
  - `id`: A unique atom identifying the plugin (e.g., `:my_plugin`).
  - `version`: A string representing the plugin version (e.g., "0.1.0").
  - `dependencies`: A list of tuples {plugin_id, version_requirement} that this plugin depends on.
  """
  @type metadata :: %{
          id: atom(),
          version: String.t(),
          dependencies: list({atom(), String.t()})
        }

  @doc """
  Callback invoked by the `PluginManager` to retrieve the plugin's metadata.
  """
  @callback get_metadata() :: metadata()
end
