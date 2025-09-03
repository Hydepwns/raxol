defmodule Raxol.Core.Runtime.Plugins.EventFilter do
  @moduledoc """
  Handles event filtering for plugins.
  This module is responsible for:
  - Filtering events through registered plugin filters
  - Managing event modifications
  - Handling event halting
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Filters an event through registered plugin filters.
  Returns the filtered event or :halt if the event should be stopped.
  """
  def filter_event(plugin_manager_state, event) do
    Raxol.Core.Runtime.Log.debug(
      "[#{__MODULE__}] filter_event called for: #{inspect(event.type)}"
    )

    # Get all enabled plugins in load order
    enabled_plugins = get_enabled_plugins(plugin_manager_state)

    # Apply filters in load order
    Enum.reduce_while(enabled_plugins, event, fn plugin_id, current_event ->
      case apply_plugin_filter(plugin_id, current_event, plugin_manager_state) do
        {:ok, modified_event} ->
          {:cont, modified_event}

        :halt ->
          {:halt, :halt}

        {:error, reason} ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "[#{__MODULE__}] Plugin #{plugin_id} filter error: #{inspect(reason)}",
            %{plugin_id: plugin_id, reason: reason, module: __MODULE__}
          )

          {:cont, current_event}
      end
    end)
  end

  # --- Private Helpers ---

  # Get list of enabled plugins in load order
  defp get_enabled_plugins(state) do
    state.load_order
    |> Enum.filter(fn plugin_id ->
      case Map.get(state.metadata, plugin_id) do
        %{enabled: true} -> true
        _ -> false
      end
    end)
  end

  # Apply a single plugin's filter to the event
  defp apply_plugin_filter(plugin_id, event, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin_module ->
        case Raxol.Core.ErrorHandling.safe_call(fn ->
          # Call the plugin's filter_event callback if it exists
          if function_exported?(plugin_module, :filter_event, 2) do
            plugin_module.filter_event(
              event,
              Map.get(state.plugin_states, plugin_id)
            )
          else
            # Plugin doesn't implement filtering, pass event through unchanged
            {:ok, event}
          end
        end) do
          {:ok, result} -> result
          {:error, e} ->
            Raxol.Core.Runtime.Log.error_with_stacktrace(
              "[#{__MODULE__}] Plugin #{plugin_id} filter crashed",
              e,
              nil,
              %{plugin_id: plugin_id, event: event, module: __MODULE__}
            )

            {:error, :filter_crashed}
        end
    end
  end
end
