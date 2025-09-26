defmodule Manager do
  @moduledoc """
  Plugin lifecycle manager - delegates to the core plugin manager.
  This module exists for backwards compatibility with tests that expect a bare "Manager" module.
  """

  alias Raxol.Core.Runtime.Plugins.PluginManager

  @doc "Start the plugin manager with options"
  defdelegate start_link(opts \\ []), to: PluginManager

  @doc "Initialize the plugin manager"
  defdelegate initialize(), to: PluginManager

  @doc "Load a plugin by module name with optional config"
  defdelegate load_plugin_by_module(module, config \\ %{}), to: PluginManager

  @doc "Enable a plugin by ID"
  defdelegate enable_plugin(plugin_id), to: PluginManager

  @doc "Disable a plugin by ID"
  defdelegate disable_plugin(plugin_id), to: PluginManager

  @doc "Reload a plugin by ID"
  defdelegate reload_plugin(plugin_id), to: PluginManager
end
