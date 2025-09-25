defmodule Raxol.Core.Runtime.Plugins.PluginReloader.Behaviour do
  @moduledoc """
  Behaviour for plugin reloading operations.
  """

  @doc """
  Reloads a plugin by ID.
  """
  @callback reload_plugin_by_id(plugin_id_string :: String.t(), state :: term()) ::
              {:ok, term()} | {:error, term(), term()}

  @doc """
  Reloads a plugin.
  """
  @callback reload_plugin(plugin_id :: term(), state :: term()) ::
              {:ok, term()} | {:error, term(), term()}
end