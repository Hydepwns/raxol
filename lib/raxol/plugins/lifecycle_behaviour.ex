defmodule Raxol.Plugins.LifecycleBehaviour do
  @moduledoc """
  Behaviour for plugin lifecycle management.

  Plugins can implement this behaviour to receive lifecycle events
  during loading, starting, stopping, and unloading phases.
  """

  @doc """
  Called when a plugin is starting up after initialization.

  This is called after the plugin has been initialized and loaded,
  but before it becomes fully active. The plugin can perform any
  startup tasks here, such as setting up connections, starting
  background processes, or registering event handlers.

  Returns `{:ok, updated_config}` or `{:error, reason}`.
  """
  @callback start(config :: map()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Called when a plugin is stopping before unloading.

  This is called before the plugin is unloaded, allowing it to
  perform cleanup tasks such as closing connections, stopping
  background processes, or unregistering event handlers.

  Returns `{:ok, updated_config}` or `{:error, reason}`.
  """
  @callback stop(config :: map()) :: {:ok, map()} | {:error, String.t()}
end
