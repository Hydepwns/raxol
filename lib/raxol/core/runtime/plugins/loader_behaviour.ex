defmodule Raxol.Core.Runtime.Plugins.LoaderBehaviour do
  @moduledoc """
  Behaviour defining the interface for plugin loading operations.
  """

  @callback load_plugin(plugin_path :: String.t()) ::
              {:ok, term()} | {:error, term()}
  @callback unload_plugin(plugin :: term()) :: :ok | {:error, term()}
  @callback reload_plugin(plugin :: term()) :: {:ok, term()} | {:error, term()}
  @callback get_loaded_plugins() :: [term()]
  @callback is_plugin_loaded?(plugin :: term()) :: boolean()
end
