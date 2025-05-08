defmodule Raxol.Core.Runtime.Plugins.LoaderBehaviour do
  @moduledoc """
  Behaviour for a plugin loader.

  This behaviour defines the contract for modules that discover, load metadata for,
  and load the code of plugins.
  """

  @doc """
  Discovers plugins in the given directories.
  """
  @callback discover_plugins(plugin_dirs :: list(String.t())) ::
              {:ok, list(%{module: module(), path: String.t(), id: atom()})}
              | {:error, any()}

  @doc """
  Loads the metadata for a given plugin module.

  The metadata is typically obtained by calling a specific function
  on the plugin module (e.g., `metadata/0` if it implements
  `PluginMetadataProvider`).
  """
  @callback load_plugin_metadata(module :: module()) ::
              {:ok, module()} | {:error, any()}

  @doc """
  Loads the actual code/module for a given plugin.
  """
  @callback load_plugin_module(module :: module()) ::
              {:ok, module()} | {:error, any()}
end
