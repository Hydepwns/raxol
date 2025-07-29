defmodule Raxol.Core.Runtime.Plugins.SafeLifecycleOperations do
  @moduledoc """
  Enhanced version of LifecycleOperations with comprehensive error handling.

  This module demonstrates best practices for error handling using the
  centralized ErrorHandler and ErrorRecovery modules.
  """

  import Raxol.Core.ErrorHandler
  alias Raxol.Core.ErrorHandler
  alias Raxol.Core.ErrorRecovery
  require Logger

  @doc """
  Safely loads a plugin with comprehensive error handling and recovery.
  """
  def safe_load_plugin(plugin_id, config, state) do
    operation_context = %{
      plugin_id: plugin_id,
      operation: :load_plugin,
      state_keys: Map.keys(state)
    }

    with_error_handling(:load_plugin, context: operation_context, retry: 2) do
      # Validate inputs first
      with {:ok, _} <- validate_plugin_id(plugin_id),
           {:ok, _} <- validate_config(config),
           {:ok, _} <- check_plugin_not_loaded(plugin_id, state) do
        # Use circuit breaker for external plugin loading
        ErrorRecovery.with_circuit_breaker("plugin_loader_#{plugin_id}", fn ->
          do_load_plugin(plugin_id, config, state)
        end)
      end
    end
  end

  @doc """
  Safely unloads a plugin with proper cleanup.
  """
  def safe_unload_plugin(plugin_id, state) do
    operation_context = %{
      plugin_id: plugin_id,
      operation: :unload_plugin
    }

    ErrorRecovery.with_cleanup(
      fn ->
        # Main unload operation
        with_error_handling(:unload_plugin, context: operation_context) do
          case Map.get(state.plugins, plugin_id) do
            nil ->
              error(:not_found, "Plugin not found: #{plugin_id}")

            plugin ->
              # Stop plugin processes
              stop_plugin_processes(plugin, state)

              # Remove from state
              {:ok, remove_plugin_from_state(plugin_id, state)}
          end
        end
      end,
      fn _result ->
        # Cleanup function - always runs
        cleanup_plugin_resources(plugin_id)
      end
    )
  end

  @doc """
  Safely reloads a plugin with fallback to previous version.
  """
  def safe_reload_plugin(plugin_id, state) do
    # Backup current plugin state
    backup = backup_plugin_state(plugin_id, state)

    ErrorRecovery.with_fallback(
      fn ->
        # Try to reload
        with {:ok, new_state} <- safe_unload_plugin(plugin_id, state),
             {:ok, final_state} <- safe_load_plugin(plugin_id, %{}, new_state) do
          {:ok, final_state}
        end
      end,
      fn ->
        # Fallback - restore from backup
        Logger.warning(
          "Plugin reload failed, restoring from backup: #{plugin_id}"
        )

        restore_plugin_state(plugin_id, backup, state)
      end
    )
  end

  @doc """
  Enables a plugin with graceful degradation.
  """
  defmacro safe_enable_plugin(plugin_id, state) do
    quote do
      ErrorRecovery.degrade_gracefully unquote(plugin_id) do
        # Full feature - enable with all capabilities
        {:ok, put_in(unquote(state).plugin_states[unquote(plugin_id)][:enabled], true)}
      else
        # Degraded mode - enable with limited capabilities
        {:ok, unquote(state)}
      end
    end
  end

  @doc """
  Batch operations with transaction-like behavior.
  """
  def safe_batch_operation(operations, initial_state) do
    steps = [
      {:step, :validate_operations, &validate_all_operations(&1, operations)},
      {:step, :execute_operations,
       &execute_with_rollback(&1, operations, initial_state)},
      {:step, :verify_consistency, &verify_state_consistency/1}
    ]

    ErrorHandler.execute_pipeline(steps)
  end

  # Private helper functions

  defp validate_plugin_id(plugin_id) when is_binary(plugin_id) do
    if String.length(plugin_id) > 0 do
      {:ok, plugin_id}
    else
      error(:validation, "Plugin ID cannot be empty")
    end
  end

  defp validate_plugin_id(_) do
    error(:validation, "Plugin ID must be a string")
  end

  defp validate_config(config) when is_map(config), do: {:ok, config}
  defp validate_config(_), do: error(:validation, "Config must be a map")

  defp check_plugin_not_loaded(plugin_id, state) do
    if Map.has_key?(state.plugins, plugin_id) do
      error(:validation, "Plugin already loaded: #{plugin_id}")
    else
      {:ok, plugin_id}
    end
  end

  defp do_load_plugin(plugin_id, config, state) do
    # Simulate actual plugin loading
    case load_plugin_module(plugin_id) do
      {:ok, module} ->
        new_state =
          Map.put(
            state,
            :plugins,
            Map.put(state.plugins, plugin_id, %{
              module: module,
              config: config,
              loaded_at: DateTime.utc_now()
            })
          )

        {:ok, new_state}

      {:error, reason} ->
        error(:runtime, "Failed to load plugin module: #{reason}", %{
          plugin_id: plugin_id
        })
    end
  end

  defp load_plugin_module(plugin_id) do
    # Placeholder for actual module loading
    {:ok, String.to_atom("Elixir.Plugin.#{plugin_id}")}
  rescue
    _ -> {:error, "Module not found"}
  end

  defp stop_plugin_processes(plugin, _state) do
    # Stop any running processes for the plugin
    if pid = Map.get(plugin, :pid) do
      Process.exit(pid, :shutdown)
    end

    :ok
  end

  defp remove_plugin_from_state(plugin_id, state) do
    %{
      state
      | plugins: Map.delete(state.plugins, plugin_id),
        plugin_states: Map.delete(state.plugin_states, plugin_id)
    }
  end

  defp cleanup_plugin_resources(plugin_id) do
    Logger.info("Cleaning up resources for plugin: #{plugin_id}")
    # Clean up any resources (files, connections, etc.)
    :ok
  end

  defp backup_plugin_state(plugin_id, state) do
    %{
      plugin: Map.get(state.plugins, plugin_id),
      plugin_state: Map.get(state.plugin_states, plugin_id),
      metadata: Map.get(state.metadata, plugin_id)
    }
  end

  defp restore_plugin_state(plugin_id, backup, state) do
    restored_state = state

    restored_state =
      if backup.plugin do
        put_in(restored_state.plugins[plugin_id], backup.plugin)
      else
        restored_state
      end

    restored_state =
      if backup.plugin_state do
        put_in(restored_state.plugin_states[plugin_id], backup.plugin_state)
      else
        restored_state
      end

    restored_state =
      if backup.metadata do
        put_in(restored_state.metadata[plugin_id], backup.metadata)
      else
        restored_state
      end

    {:ok, restored_state}
  end


  defp validate_all_operations(_, operations) do
    errors =
      Enum.reduce(operations, [], fn op, acc ->
        case validate_operation(op) do
          {:ok, _} -> acc
          {:error, reason} -> [reason | acc]
        end
      end)

    if Enum.empty?(errors) do
      {:ok, operations}
    else
      error(:validation, "Invalid operations", %{errors: errors})
    end
  end

  defp validate_operation({:load, plugin_id, _config})
       when is_binary(plugin_id),
       do: {:ok, :valid}

  defp validate_operation({:unload, plugin_id}) when is_binary(plugin_id),
    do: {:ok, :valid}

  defp validate_operation(_), do: {:error, "Invalid operation format"}

  defp execute_with_rollback(operations, _original_operations, initial_state) do
    {final_state, _executed} =
      Enum.reduce_while(operations, {initial_state, []}, fn op, {state, done} ->
        case execute_operation(op, state) do
          {:ok, new_state} ->
            {:cont, {new_state, [op | done]}}

          {:error, reason} ->
            # Rollback executed operations
            Logger.error("Operation failed, rolling back: #{inspect(reason)}")
            rollback_state = rollback_operations(done, initial_state)
            {:halt, {:error, reason, rollback_state}}
        end
      end)

    case final_state do
      {:error, _reason, _state} -> final_state
      _ -> {:ok, final_state}
    end
  end

  defp execute_operation({:load, plugin_id, config}, state) do
    safe_load_plugin(plugin_id, config, state)
  end

  defp execute_operation({:unload, plugin_id}, state) do
    safe_unload_plugin(plugin_id, state)
  end

  defp rollback_operations(operations, initial_state) do
    Enum.reduce(operations, initial_state, fn op, state ->
      case rollback_operation(op, state) do
        {:ok, new_state} -> new_state
        _ -> state
      end
    end)
  end

  defp rollback_operation({:load, plugin_id, _config}, state) do
    # Rollback load by unloading
    safe_unload_plugin(plugin_id, state)
  end

  defp rollback_operation({:unload, _plugin_id}, state) do
    # Rollback unload by reloading (if we have the backup)
    # This is simplified - in reality we'd need the original config
    {:ok, state}
  end

  defp verify_state_consistency(state) do
    # Verify that the state is internally consistent
    inconsistencies = []

    # Check that all plugins in load_order exist in plugins map
    inconsistencies =
      Enum.reduce(
        Map.get(state, :load_order, []),
        inconsistencies,
        fn plugin_id, acc ->
          if Map.has_key?(state.plugins, plugin_id) do
            acc
          else
            ["Plugin #{plugin_id} in load_order but not in plugins map" | acc]
          end
        end
      )

    if Enum.empty?(inconsistencies) do
      {:ok, state}
    else
      error(:validation, "State consistency check failed", %{
        inconsistencies: inconsistencies
      })
    end
  end
end
