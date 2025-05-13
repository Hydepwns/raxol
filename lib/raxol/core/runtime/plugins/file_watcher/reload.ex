defmodule Raxol.Core.Runtime.Plugins.FileWatcher.Reload do
  @moduledoc """
  Handles plugin reloading functionality.
  """

  require Logger

  @doc """
  Reloads a plugin after file changes.
  Returns :ok on success or {:error, reason} on failure.
  """
  def reload_plugin(plugin_id, path) do
    # Verify the plugin exists and is loaded
    case Raxol.Core.Runtime.Plugins.Manager.get_plugin(plugin_id) do
      {:ok, plugin} ->
        # Attempt to reload the plugin
        try do
          # First unload the plugin
          case Raxol.Core.Runtime.Plugins.Manager.unload_plugin(plugin_id) do
            :ok ->
              # Then reload it
              case Raxol.Core.Runtime.Plugins.Manager.load_plugin(path) do
                {:ok, _} ->
                  Logger.info(
                    "[#{__MODULE__}] Successfully reloaded plugin #{plugin_id}"
                  )

                  :ok

                {:error, reason} ->
                  Logger.error(
                    "[#{__MODULE__}] Failed to reload plugin #{plugin_id}: #{inspect(reason)}"
                  )

                  {:error, {:reload_failed, reason}}
              end

            {:error, reason} ->
              Logger.error(
                "[#{__MODULE__}] Failed to unload plugin #{plugin_id}: #{inspect(reason)}"
              )

              {:error, {:unload_failed, reason}}
          end
        rescue
          e ->
            Logger.error(
              "[#{__MODULE__}] Error during plugin reload #{plugin_id}: #{inspect(e)}"
            )

            {:error, {:reload_error, e}}
        end

      {:error, :not_found} ->
        Logger.error("[#{__MODULE__}] Plugin #{plugin_id} not found for reload")
        {:error, :plugin_not_found}
    end
  end
end
