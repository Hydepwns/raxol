defmodule Raxol.Core.Runtime.Plugins.PluginReloader do
  @moduledoc """
  Handles reloading of plugins from disk.
  """

  alias Raxol.Core.Runtime.Plugins.PluginCommandManager

  require Raxol.Core.Runtime.Log

  @doc """
  Reloads a plugin from disk.
  """
  def reload_plugin_from_disk(
        plugin_id,
        plugin_module,
        plugin_path,
        plugin_state,
        command_table,
        metadata,
        _plugin_manager,
        _opts
      ) do
    try do
      with :ok <- reload_module(plugin_module),
           {:ok, updated_state} <-
             initialize_plugin_state(plugin_module, plugin_state),
           {:ok, updated_table} <-
             PluginCommandManager.update_command_table(
               command_table,
               plugin_module,
               updated_state
             ) do
        {:ok, updated_state, updated_table,
         update_metadata(metadata, plugin_id, plugin_path, updated_state)}
      else
        {:error, reason} -> handle_reload_error(reason, plugin_id)
      end
    rescue
      e -> handle_reload_exception(e, plugin_id)
    end
  end

  @doc """
  Reloads a module from disk.
  """
  def reload_module(plugin_module) do
    with :ok <- :code.purge(plugin_module),
         {:module, ^plugin_module} <- :code.load_file(plugin_module) do
      :ok
    end
  end

  @doc """
  Initializes plugin state.
  """
  def initialize_plugin_state(plugin_module, config) do
    plugin_module.init(config)
  end

  @doc """
  Updates metadata for a reloaded plugin.
  """
  def update_metadata(metadata, plugin_id, plugin_path, updated_state) do
    Map.put(metadata, plugin_id, %{
      path: plugin_path,
      state: updated_state,
      last_reload: System.system_time()
    })
  end

  @doc """
  Handles reload errors.
  """
  def handle_reload_error(reason, plugin_id) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Failed to reload plugin",
      reason,
      nil,
      %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
    )

    {:error, :reload_failed}
  end

  @doc """
  Handles reload exceptions.
  """
  def handle_reload_exception(e, plugin_id) do
    Raxol.Core.Runtime.Log.error(
      "Failed to reload plugin (exception)",
      %{module: __MODULE__, plugin_id: plugin_id, error: inspect(e)}
    )

    {:error, :reload_failed}
  end
end
