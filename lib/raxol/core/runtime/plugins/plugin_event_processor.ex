defmodule Raxol.Core.Runtime.Plugins.PluginEventProcessor do
  @moduledoc """
  Handles event processing through plugins.
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Processes an event through all enabled plugins in load order.
  """
  def process_event_through_plugins(
        event,
        plugins,
        metadata,
        plugin_states,
        load_order,
        command_table,
        plugin_config
      ) do
    # Process event through enabled plugins in load order
    Enum.reduce_while(load_order, {:ok, {metadata, plugin_states, command_table}}, fn plugin_id, acc ->
      case acc do
        {:ok, {current_metadata, current_states, current_table}} ->
          case process_plugin_event(
                 plugin_id,
                 event,
                 plugins,
                 current_metadata,
                 current_states,
                 current_table,
                 plugin_config
               ) do
            {:ok, {updated_metadata, updated_states, updated_table}} ->
              {:cont, {:ok, {updated_metadata, updated_states, updated_table}}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end

        {:error, _reason} = error ->
          {:halt, error}
      end
    end)
  end

  @doc """
  Processes an event for a specific plugin.
  """
  def process_plugin_event(
        plugin_id,
        event,
        plugins,
        metadata,
        plugin_states,
        command_table,
        plugin_config
      ) do
    case Map.get(plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin_module ->
        case Map.get(metadata, plugin_id) do
          %{enabled: true} ->
            # Plugin is enabled, process the event
            case Map.get(plugin_states, plugin_id) do
              nil ->
                {:error, :plugin_state_not_found}

              plugin_state ->
                try do
                  # Call the plugin's handle_event callback if it exists
                  if function_exported?(plugin_module, :handle_event, 2) do
                    case plugin_module.handle_event(event, plugin_state) do
                      {:ok, updated_plugin_state} ->
                        updated_states = Map.put(plugin_states, plugin_id, updated_plugin_state)
                        {:ok, {metadata, updated_states, command_table}}

                      {:error, reason} ->
                        Raxol.Core.Runtime.Log.warning_with_context(
                          "Plugin #{plugin_id} failed to handle event",
                          %{plugin_id: plugin_id, event: event, reason: reason, module: __MODULE__}
                        )
                        {:ok, {metadata, plugin_states, command_table}}

                      other ->
                        Raxol.Core.Runtime.Log.warning_with_context(
                          "Plugin #{plugin_id} returned unexpected value from handle_event",
                          %{plugin_id: plugin_id, event: event, value: other, module: __MODULE__}
                        )
                        {:ok, {metadata, plugin_states, command_table}}
                    end
                  else
                    # Plugin doesn't implement handle_event, continue
                    {:ok, {metadata, plugin_states, command_table}}
                  end
                rescue
                  e ->
                    Raxol.Core.Runtime.Log.error_with_stacktrace(
                      "Plugin #{plugin_id} crashed during event handling",
                      e,
                      nil,
                      %{plugin_id: plugin_id, event: event, module: __MODULE__}
                    )
                    {:ok, {metadata, plugin_states, command_table}}
                end
            end
          _ ->
            {:ok, {metadata, plugin_states, command_table}}
        end
      _ ->
        {:ok, {metadata, plugin_states, command_table}}
    end
  end
end
