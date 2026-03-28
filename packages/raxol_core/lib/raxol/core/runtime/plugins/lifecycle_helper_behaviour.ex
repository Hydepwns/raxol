defmodule Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour do
  @moduledoc """
  Behavior for plugin lifecycle management.
  """

  @doc """
  Initializes a plugin's lifecycle.
  """
  @callback init_lifecycle(plugin_id :: String.t(), opts :: keyword()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Starts a plugin's lifecycle.
  """
  @callback start_lifecycle(plugin_id :: String.t(), state :: term()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Stops a plugin's lifecycle.
  """
  @callback stop_lifecycle(plugin_id :: String.t(), state :: term()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Terminates a plugin's lifecycle.
  """
  @callback terminate_lifecycle(plugin_id :: String.t(), state :: term()) :: :ok
end
