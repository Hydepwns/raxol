defmodule Raxol.Core.Runtime.Plugins.Manager.Behaviour do
  @moduledoc """
  Defines the behaviour for plugin management functionality.
  This is used for mocking in tests.
  """

  @doc """
  Gets a plugin by its ID.
  """
  @callback get_plugin(plugin_id :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Unloads a plugin by its ID.
  """
  @callback unload_plugin(plugin_id :: String.t()) :: :ok | {:error, term()}

  @doc """
  Loads a plugin from a file path.
  """
  @callback load_plugin(plugin_path :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Starts the plugin manager with the given options.
  """
  @callback start_link(opts :: Keyword.t()) :: GenServer.on_start()
  # @callback initialize() :: :ok | {:error, term()}
  # @callback handle_cast({:handle_command, atom(), any()}, map()) :: {:noreply, map()}
  # Add other callbacks as needed for tests
end
