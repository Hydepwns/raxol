defmodule Raxol.Core.Runtime.Plugins.PluginMetadataProvider.Behaviour do
  @moduledoc """
  Defines the behaviour for plugin metadata providers.

  This behaviour is responsible for:
  - Providing plugin metadata (ID, version, dependencies)
  - Validating plugin metadata
  - Managing plugin metadata lifecycle
  """

  @type version_constraint :: String.t()
  @type dependency :: {String.t(), version_constraint()} | String.t()
  @type metadata :: %{
    id: String.t(),
    version: String.t(),
    name: String.t(),
    description: String.t(),
    author: String.t(),
    dependencies: list(dependency()),
    optional_dependencies: list(dependency()),
    config_schema: map() | nil,
    behaviours: list(module())
  }

  @doc """
  Gets the metadata for a plugin.
  """
  @callback get_metadata(module :: module()) :: {:ok, metadata()} | {:error, any()}

  @doc """
  Validates plugin metadata.
  """
  @callback validate_metadata(metadata :: metadata()) :: :ok | {:error, any()}

  @doc """
  Gets the plugin ID from metadata.
  """
  @callback get_plugin_id(metadata :: metadata()) :: {:ok, String.t()} | {:error, any()}

  @doc """
  Gets the plugin version from metadata.
  """
  @callback get_plugin_version(metadata :: metadata()) :: {:ok, String.t()} | {:error, any()}

  @doc """
  Gets the plugin dependencies from metadata.
  Returns a list of dependencies, each being either:
  - A tuple {plugin_id, version_constraint} for versioned dependencies
  - A simple plugin_id string for unversioned dependencies
  """
  @callback get_plugin_dependencies(metadata :: metadata()) :: {:ok, list(dependency())} | {:error, any()}

  @doc """
  Gets the plugin optional dependencies from metadata.
  Returns a list of dependencies, each being either:
  - A tuple {plugin_id, version_constraint} for versioned dependencies
  - A simple plugin_id string for unversioned dependencies
  """
  @callback get_plugin_optional_dependencies(metadata :: metadata()) :: {:ok, list(dependency())} | {:error, any()}

  @doc """
  Gets the plugin config schema from metadata.
  """
  @callback get_plugin_config_schema(metadata :: metadata()) :: {:ok, map() | nil} | {:error, any()}

  @doc """
  Gets the plugin behaviours from metadata.
  """
  @callback get_plugin_behaviours(metadata :: metadata()) :: {:ok, list(module())} | {:error, any()}
end
