defmodule Raxol.Core.Runtime.Plugins.FileWatcher.Reload do
  @moduledoc """
  Handles plugin reloading functionality.
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Reloads a plugin after file changes.
  Returns :ok on success or {:error, reason} on failure.
  """
  def reload_plugin(plugin_id, path) do
    # Verify the plugin exists and is loaded
    case Raxol.Core.Runtime.Plugins.Manager.get_plugin(plugin_id) do
      {:ok, _plugin} ->
        # Attempt to reload the plugin
        try do
          # First unload the plugin
          # unload_plugin uses GenServer.cast and always returns :ok
          Raxol.Core.Runtime.Plugins.Manager.unload_plugin(plugin_id)

          # Give it a moment to unload
          Process.sleep(10)

          # Then reload it
          case Raxol.Core.Runtime.Plugins.Manager.load_plugin(
                 plugin_id,
                 %{}
               ) do
            {:ok, _} ->
              Raxol.Core.Runtime.Log.info(
                "[#{__MODULE__}] Successfully reloaded plugin #{plugin_id}"
              )

              :ok

            {:error, reason} ->
              Raxol.Core.Runtime.Log.error_with_stacktrace(
                "[#{__MODULE__}] Failed to reload plugin #{plugin_id}",
                reason,
                nil,
                %{
                  module: __MODULE__,
                  plugin_id: plugin_id,
                  path: path,
                  reason: reason
                }
              )

              {:error, {:reload_failed, reason}}
          end
        rescue
          e ->
            Raxol.Core.Runtime.Log.error_with_stacktrace(
              "[#{__MODULE__}] Error during plugin reload #{plugin_id}",
              e,
              __STACKTRACE__,
              %{module: __MODULE__, plugin_id: plugin_id, path: path}
            )

            {:error, {:reload_error, e}}
        end

      {:error, :not_found} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "[#{__MODULE__}] Plugin #{plugin_id} not found for reload",
          nil,
          nil,
          %{module: __MODULE__, plugin_id: plugin_id, path: path}
        )

        {:error, :plugin_not_found}
    end
  end
end
