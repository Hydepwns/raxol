defmodule Raxol.Plugins.Manager.Core do
  @moduledoc """
  Core functionality for the plugin manager.
  Handles basic plugin management operations and state.
  """

  require Raxol.Core.Runtime.Log
  import Raxol.Guards

  alias Raxol.Plugins.{
    Plugin,
    PluginConfig
  }

  @type t :: %__MODULE__{
          plugins: %{String.t() => Plugin.t()},
          plugin_states: %{String.t() => any()},
          plugin_config: PluginConfig.t(),
          metadata: map(),
          event_handler: function() | nil,
          api_version: String.t(),
          loaded_plugins: %{String.t() => Plugin.t()},
          config: map(),
          load_order: [atom()]
        }

  defstruct [
    :plugins,
    :plugin_states,
    :plugin_config,
    :metadata,
    :event_handler,
    api_version: "1.0.0",
    loaded_plugins: %{},
    config: %{},
    load_order: []
  ]

  @doc """
  Creates a new plugin manager with default configuration.
  """
  def new(_opts \\ []) do
    plugin_config = Raxol.Plugins.PluginConfig.new()

    manager = %__MODULE__{
      plugins: %{},
      plugin_states: %{},
      plugin_config: plugin_config,
      metadata: %{},
      event_handler: nil,
      api_version: "1.0.0",
      loaded_plugins: %{},
      config: plugin_config
    }

    {:ok, manager}
  end

  @doc """
  Gets a list of all loaded plugins.
  """
  def list_plugins(%__MODULE__{} = manager) do
    Map.values(manager.plugins)
  end

  @doc """
  Gets a plugin by name.
  """
  def get_plugin(%__MODULE__{} = manager, name) when binary?(name) do
    Map.get(manager.plugins, name)
  end

  @doc """
  Gets the current API version of the plugin manager.
  """
  def get_api_version(%__MODULE__{} = manager) do
    manager.api_version
  end

  @doc """
  Returns a map of loaded plugin names to plugin structs (for test compatibility).
  """
  def loaded_plugins(%__MODULE__{} = manager) do
    manager.loaded_plugins
  end

  @doc """
  Updates the plugins map in the manager and keeps loaded_plugins in sync.
  """
  def update_plugins(%__MODULE__{} = manager, plugins) when map?(plugins) do
    %{manager | plugins: plugins, loaded_plugins: plugins}
  end

  @doc """
  Updates the configuration in the manager.
  """
  def update_config(%__MODULE__{} = manager, config) do
    %{manager | config: config}
  end

  @doc """
  Loads a plugin module and initializes it. Delegates to Raxol.Plugins.Lifecycle.load_plugin/3.
  """
  def load_plugin(%__MODULE__{} = manager, module) when atom?(module) do
    Raxol.Plugins.Lifecycle.load_plugin(manager, module)
  end

  @doc """
  Loads a plugin module with specific configuration and initializes it.
  Delegates to Raxol.Plugins.Lifecycle.load_plugin/3.
  """
  def load_plugin(%__MODULE__{} = manager, module, config)
      when atom?(module) and map?(config) do
    Raxol.Plugins.Lifecycle.load_plugin(manager, module, config)
  end

  @doc """
  Unloads a plugin by name and cleans up its resources.
  Delegates to Raxol.Plugins.Lifecycle.unload_plugin/2.
  """
  def unload_plugin(%__MODULE__{} = manager, plugin_name)
      when binary?(plugin_name) do
    Raxol.Plugins.Lifecycle.unload_plugin(manager, plugin_name)
  end
end
