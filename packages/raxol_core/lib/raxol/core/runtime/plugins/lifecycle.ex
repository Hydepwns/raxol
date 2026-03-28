defmodule Raxol.Core.Runtime.Plugins.Lifecycle do
  @moduledoc """
  Defines the behaviour for plugin lifecycle management.

  Plugins that implement this behaviour will have their lifecycle events
  called during plugin loading and unloading.
  """

  @doc """
  Called when the plugin is started after initialization.

  Should return `{:ok, updated_config}` or `{:error, reason}`.
  The `updated_config` will be stored in the plugin's configuration.
  """
  @callback start(config :: map()) :: {:ok, map()} | {:error, any()}

  @doc """
  Called when the plugin is stopped before cleanup.

  Should return `{:ok, updated_config}` or `{:error, reason}`.
  The `updated_config` will be stored in the plugin's configuration.
  """
  @callback stop(config :: map()) :: {:ok, map()} | {:error, any()}
end
