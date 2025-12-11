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
    initial_state = {metadata, plugin_states, command_table}

    Enum.reduce_while(
      load_order,
      {:ok, initial_state},
      &process_single_plugin(&1, &2, event, plugins, plugin_config)
    )
  end

  @spec process_single_plugin(
          String.t() | integer(),
          any(),
          any(),
          any(),
          map()
        ) :: any()
  defp process_single_plugin(plugin_id, acc, event, plugins, plugin_config) do
    case acc do
      {:ok, {current_metadata, current_states, current_table}} ->
        handle_plugin_processing(
          plugin_id,
          event,
          plugins,
          current_metadata,
          current_states,
          current_table,
          plugin_config
        )

      {:error, _reason} = error ->
        {:halt, error}
    end
  end

  @spec handle_plugin_processing(
          any(),
          any(),
          any(),
          any(),
          map(),
          any(),
          map()
        ) ::
          {:cont, {:ok, any()}} | {:halt, {:error, any()}}
  defp handle_plugin_processing(
         plugin_id,
         event,
         plugins,
         metadata,
         states,
         table,
         config
       ) do
    case process_plugin_event(
           plugin_id,
           event,
           plugins,
           metadata,
           states,
           table,
           config
         ) do
      {:ok, result} -> {:cont, {:ok, result}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
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
        _plugin_config
      ) do
    with {:ok, plugin_module} <- get_plugin_module(plugins, plugin_id),
         {:ok, _} <- validate_plugin_enabled(metadata, plugin_id),
         {:ok, plugin_state} <- get_plugin_state(plugin_states, plugin_id) do
      execute_plugin_event_handler(
        plugin_module,
        plugin_id,
        event,
        plugin_state,
        metadata,
        plugin_states,
        command_table
      )
    else
      {:error, :plugin_disabled} ->
        {:ok, {metadata, plugin_states, command_table}}

      {:error, _} = error ->
        error
    end
  end

  @spec get_plugin_module(any(), String.t() | integer()) :: any() | nil
  defp get_plugin_module(plugins, plugin_id) do
    case Map.get(plugins, plugin_id) do
      nil -> {:error, :plugin_not_found}
      module -> {:ok, module}
    end
  end

  @spec validate_plugin_enabled(any(), String.t() | integer()) ::
          {:ok, any()} | {:error, any()}
  defp validate_plugin_enabled(metadata, plugin_id) do
    case Map.get(metadata, plugin_id) do
      %{enabled: true} -> {:ok, :enabled}
      _ -> {:error, :plugin_disabled}
    end
  end

  @spec get_plugin_state(map(), String.t() | integer()) :: any() | nil
  defp get_plugin_state(plugin_states, plugin_id) do
    case Map.get(plugin_states, plugin_id) do
      nil -> {:error, :plugin_state_not_found}
      state -> {:ok, state}
    end
  end

  @spec execute_plugin_event_handler(
          module(),
          String.t() | integer(),
          any(),
          map(),
          any(),
          map(),
          any()
        ) :: any()
  defp execute_plugin_event_handler(
         plugin_module,
         plugin_id,
         event,
         plugin_state,
         metadata,
         plugin_states,
         command_table
       ) do
    case function_exported?(plugin_module, :handle_event, 2) do
      true ->
        handle_plugin_event_call(
          plugin_module,
          plugin_id,
          event,
          plugin_state,
          metadata,
          plugin_states,
          command_table
        )

      false ->
        {:ok, {metadata, plugin_states, command_table}}
    end
  end

  @spec handle_plugin_event_call(
          module(),
          String.t() | integer(),
          any(),
          map(),
          any(),
          map(),
          any()
        ) :: {:ok, {any(), map(), any()}}
  defp handle_plugin_event_call(
         plugin_module,
         plugin_id,
         event,
         plugin_state,
         metadata,
         plugin_states,
         command_table
       ) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           plugin_module.handle_event(event, plugin_state)
         end) do
      {:ok, {:ok, updated_plugin_state}} ->
        updated_states =
          Map.put(plugin_states, plugin_id, updated_plugin_state)

        {:ok, {metadata, updated_states, command_table}}

      {:ok, {:error, reason}} ->
        log_plugin_error(plugin_id, event, reason)
        {:ok, {metadata, plugin_states, command_table}}

      {:ok, other} ->
        log_plugin_unexpected_return(plugin_id, event, other)
        {:ok, {metadata, plugin_states, command_table}}

      {:error, exception} ->
        log_plugin_crash(plugin_id, event, exception)
        {:ok, {metadata, plugin_states, command_table}}
    end
  end

  @spec log_plugin_error(String.t() | integer(), any(), any()) :: any()
  defp log_plugin_error(plugin_id, event, reason) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Plugin #{plugin_id} failed to handle event",
      %{
        plugin_id: plugin_id,
        event: event,
        reason: reason,
        module: __MODULE__
      }
    )
  end

  @spec log_plugin_unexpected_return(String.t() | integer(), any(), any()) ::
          any()
  defp log_plugin_unexpected_return(plugin_id, event, value) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Plugin #{plugin_id} returned unexpected value from handle_event",
      %{
        plugin_id: plugin_id,
        event: event,
        value: value,
        module: __MODULE__
      }
    )
  end

  @spec log_plugin_crash(String.t() | integer(), any(), any()) :: any()
  defp log_plugin_crash(plugin_id, event, exception) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Plugin #{plugin_id} crashed during event handling",
      exception,
      nil,
      %{plugin_id: plugin_id, event: event, module: __MODULE__}
    )
  end
end
