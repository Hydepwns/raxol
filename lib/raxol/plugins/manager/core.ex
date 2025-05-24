defmodule Raxol.Plugins.Manager.Core do
  @moduledoc """
  Core functionality for the plugin manager.
  Handles basic plugin management operations and state.
  """

  require Logger

  alias Raxol.Plugins.{
    Plugin,
    PluginConfig,
    PluginDependency,
    CellProcessor,
    EventHandler,
    Lifecycle
  }

  @type t :: %__MODULE__{
          plugins: %{String.t() => Plugin.t()},
          config: PluginConfig.t(),
          api_version: String.t()
        }

  defstruct [
    :plugins,
    :config,
    :api_version
  ]

  @doc """
  Creates a new plugin manager with default configuration.
  """
  def new(_config \\ %{}) do
    # Initialize with a default PluginConfig
    initial_config = PluginConfig.new()

    %__MODULE__{
      plugins: %{},
      config: initial_config,
      # Set a default API version
      api_version: "1.0"
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
  Updates the plugins map in the manager.
  """
  def update_plugins(%__MODULE__{} = manager, plugins) when is_map(plugins) do
    %{manager | plugins: plugins}
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
    Lifecycle.load_plugin(manager, module)
  end
end
