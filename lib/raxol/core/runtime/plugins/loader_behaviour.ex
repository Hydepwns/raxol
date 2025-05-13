defmodule Raxol.Core.Runtime.Plugins.Loader.Behaviour do
  @moduledoc """
  Defines the behaviour for plugin loading functionality.

  This behaviour is responsible for:
  - Loading plugin modules
  - Initializing plugins with configuration
  - Verifying plugin implementations
  - Managing plugin metadata
  """

  @doc """
  Loads a plugin module and verifies it implements the required behaviour.
  """
  @callback load_plugin_module(module :: module()) ::
              {:ok, module()} | {:error, any()}

  @doc """
  Initializes a plugin with the given configuration.
  """
  @callback initialize_plugin(module :: module(), config :: map()) ::
              {:ok, map()} | {:error, any()}

  @doc """
  Verifies if a module implements a specific behaviour.
  """
  @callback behaviour_implemented?(module :: module(), behaviour :: module()) ::
              boolean()

  @doc """
  Loads plugin metadata from a module.
  """
  @callback load_plugin_metadata(module :: module()) ::
              {:ok, map()} | {:error, any()}
end
