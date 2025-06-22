defmodule Raxol.Core.Runtime.Plugins.PluginInitializer do
  @moduledoc """
  Handles initialization of plugins, including state setup and command registration.
  """

  alias Raxol.Core.Runtime.Plugins.PluginCommandManager
  require Raxol.Core.Runtime.Log

  @doc """
  Initializes all plugins in the given load order.
  """
  def initialize_plugins(
        plugins,
        metadata,
        config,
        states,
        load_order,
        command_table,
        _opts
      ) do
    table = PluginCommandManager.initialize_command_table(command_table, plugins)

    Enum.reduce_while(
      load_order,
      {:ok, {metadata, states, table}},
      &initialize_plugin(&1, &2, plugins, config)
    )
  end

  @doc """
  Initializes a single plugin.
  """
  def initialize_plugin(
        plugin_id,
        {:ok, {meta, sts, tbl}},
        plugins,
        plugin_config
      ) do
    case Map.get(plugins, plugin_id) do
      nil ->
        {:cont, {:ok, {meta, sts, tbl}}}

      plugin ->
        handle_plugin_init(plugin, plugin_id, meta, sts, tbl, plugin_config)
    end
  end

  @doc """
  Handles the initialization of a specific plugin.
  """
  def handle_plugin_init(plugin, plugin_id, meta, sts, tbl, plugin_config) do
    case plugin.init(Map.get(plugin_config, plugin_id, %{})) do
      {:ok, new_states} ->
        new_meta = Map.put(meta, plugin_id, %{status: :active})
        new_tbl = PluginCommandManager.update_command_table(tbl, plugin)
        {:cont, {:ok, {new_meta, Map.merge(sts, new_states), new_tbl}}}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to initialize plugin",
          reason,
          nil,
          %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
        )

        {:halt, {:error, reason}}
    end
  end
end
