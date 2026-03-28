defmodule Raxol.Core.Runtime.Plugins.LoaderBehaviour do
  @moduledoc """
  Behavior for plugin loading functionality.
  """

  @doc """
  Loads a plugin from a given path or configuration.
  """
  @callback load_plugin(plugin_spec :: term(), opts :: keyword()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Unloads a plugin.
  """
  @callback unload_plugin(plugin_id :: String.t()) :: :ok | {:error, term()}

  @doc """
  Lists available plugins.
  """
  @callback list_available_plugins(opts :: keyword()) :: list(String.t())

  @doc """
  Validates a plugin before loading.
  """
  @callback validate_plugin(plugin_spec :: term()) :: :ok | {:error, term()}
end
