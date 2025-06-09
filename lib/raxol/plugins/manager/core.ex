defmodule Raxol.Plugins.Manager.Core do
  @moduledoc """
  Core functionality for the plugin manager.
  Handles basic plugin management operations and state.
  """

  require Raxol.Core.Runtime.Log

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
          config: map()
        }

  defstruct [
    :plugins,
    :plugin_states,
    :plugin_config,
    :metadata,
    :event_handler,
    api_version: "1.0.0",
    loaded_plugins: %{},
    config: %{}
  ]

  @doc """
  Creates a new plugin manager with default configuration.
  """
  def new(_opts \\ []) do
    %__MODULE__{
      plugins: %{},
      plugin_states: %{},
      plugin_config: Raxol.Plugins.PluginConfig.new(),
      metadata: %{},
      event_handler: nil,
      api_version: "1.0.0",
      loaded_plugins: %{},
      config: %{}
    }
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
  def get_plugin(%__MODULE__{} = manager, name) when is_binary(name) do
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
  def update_plugins(%__MODULE__{} = manager, plugins) when is_map(plugins) do
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
  def load_plugin(%__MODULE__{} = manager, module) when is_atom(module) do
    Raxol.Plugins.Lifecycle.load_plugin(manager, module)
  end

  @doc """
  Loads a plugin module with specific configuration and initializes it.
  Delegates to Raxol.Plugins.Lifecycle.load_plugin/3.
  """
  def load_plugin(%__MODULE__{} = manager, module, config)
      when is_atom(module) and is_map(config) do
    Raxol.Plugins.Lifecycle.load_plugin(manager, module, config)
  end
end
