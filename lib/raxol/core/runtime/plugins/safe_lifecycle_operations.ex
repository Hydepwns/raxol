defmodule Raxol.Core.Runtime.Plugins.SafeLifecycleOperations do
  @moduledoc """
  Enhanced version of LifecycleOperations with comprehensive error handling.

  This module demonstrates best practices for error handling using the
  centralized ErrorHandler and ErrorRecovery modules.
  """

  import Raxol.Core.ErrorHandler
  alias Raxol.Core.ErrorHandler
  alias Raxol.Core.ErrorRecovery
  alias Raxol.Core.Runtime.Log

  @doc """
  Safely loads a plugin with default config.
  """
  def safe_load_plugin(plugin_id, state) do
    safe_load_plugin(plugin_id, %{}, state)
  end

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
        Log.module_warning(
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
        {:ok,
         put_in(
           unquote(state).plugin_states[unquote(plugin_id)][:enabled],
           true
         )}
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

  @spec validate_plugin_id(String.t() | atom() | integer()) ::
          {:ok, any()} | {:error, any()}
  defp validate_plugin_id(plugin_id) when is_binary(plugin_id) do
    validate_plugin_id_length(String.length(plugin_id), plugin_id)
  end

  defp validate_plugin_id(plugin_id) when is_atom(plugin_id) do
    # Accept atoms as valid plugin IDs (module names)
    {:ok, plugin_id}
  end

  @spec validate_plugin_id(any()) :: {:ok, any()} | {:error, any()}
  defp validate_plugin_id(_) do
    {:error, "Plugin ID must be a string or atom"}
  end

  @spec validate_plugin_id_length(any(), String.t() | integer()) ::
          {:ok, any()} | {:error, any()}
  defp validate_plugin_id_length(0, _plugin_id) do
    error(:validation, "Plugin ID cannot be empty")
  end

  @spec validate_plugin_id_length(any(), String.t() | integer()) ::
          {:ok, any()} | {:error, any()}
  defp validate_plugin_id_length(_length, plugin_id) do
    {:ok, plugin_id}
  end

  @spec validate_config(map()) :: {:ok, any()} | {:error, any()}
  defp validate_config(config) when is_map(config), do: {:ok, config}
  @spec validate_config(any()) :: {:ok, any()} | {:error, any()}
  defp validate_config(_), do: {:error, "Config must be a map"}

  @spec check_plugin_not_loaded(String.t() | integer(), map()) :: any()
  defp check_plugin_not_loaded(plugin_id, state) do
    do_check_plugin_not_loaded(
      Map.has_key?(state.plugins, plugin_id),
      plugin_id
    )
  end

  @spec do_check_plugin_not_loaded(any(), String.t() | integer()) :: any()
  defp do_check_plugin_not_loaded(true, plugin_id) do
    {:error, "Plugin already loaded: #{plugin_id}"}
  end

  @spec do_check_plugin_not_loaded(any(), String.t() | integer()) :: any()
  defp do_check_plugin_not_loaded(false, plugin_id) do
    {:ok, plugin_id}
  end

  @spec do_load_plugin(String.t() | integer(), map(), map()) :: any()
  defp do_load_plugin(plugin_module, config, state)
       when is_atom(plugin_module) do
    # Call the plugin's init function safely
    case Raxol.Core.ErrorHandling.safe_call(fn -> plugin_module.init(config) end) do
      {:ok, {:ok, plugin_state}} ->
        # Extract plugin metadata from the state
        plugin_id = Map.get(plugin_state, :name, plugin_module |> to_string())

        new_state =
          Map.put(
            state,
            :plugins,
            Map.put(state.plugins, plugin_id, %{
              module: plugin_module,
              config: config,
              state: plugin_state,
              loaded_at: DateTime.utc_now()
            })
          )

        {:ok, new_state}

      {:ok, plugin_state} when is_map(plugin_state) ->
        # Handle case where init returns state directly without {:ok, state}
        plugin_id = Map.get(plugin_state, :name, plugin_module |> to_string())

        new_state =
          Map.put(
            state,
            :plugins,
            Map.put(state.plugins, plugin_id, %{
              module: plugin_module,
              config: config,
              state: plugin_state,
              loaded_at: DateTime.utc_now()
            })
          )

        {:ok, new_state}

      {:error, reason} ->
        {:error, "Plugin init crashed: #{inspect(reason)}"}

      {:ok, other} ->
        {:error, "Plugin init returned invalid response: #{inspect(other)}"}
    end
  end

  defp do_load_plugin(plugin_id, config, state) do
    # Handle string plugin_id by converting to module atom
    case load_plugin_module(plugin_id) do
      {:ok, module} ->
        do_load_plugin(module, config, state)

      {:error, reason} ->
        {:error, "Failed to load plugin module: #{reason}"}
    end
  end

  @spec load_plugin_module(String.t() | integer()) :: any()
  defp load_plugin_module(plugin_id) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           # Placeholder for actual module loading
           String.to_atom("Elixir.Plugin.#{plugin_id}")
         end) do
      {:ok, module} -> {:ok, module}
      {:error, _reason} -> {:error, "Module not found"}
    end
  end

  @spec stop_plugin_processes(any(), map()) :: any()
  defp stop_plugin_processes(plugin, _state) do
    # Stop any running processes for the plugin
    stop_plugin_process_if_exists(Map.get(plugin, :pid))
    :ok
  end

  @spec stop_plugin_process_if_exists(any()) :: any()
  defp stop_plugin_process_if_exists(nil), do: :ok

  @spec stop_plugin_process_if_exists(String.t() | integer()) :: any()
  defp stop_plugin_process_if_exists(pid) do
    Process.exit(pid, :shutdown)
  end

  @spec remove_plugin_from_state(String.t() | integer(), map()) :: any()
  defp remove_plugin_from_state(plugin_id, state) do
    %{
      state
      | plugins: Map.delete(state.plugins, plugin_id),
        plugin_states: Map.delete(state.plugin_states, plugin_id)
    }
  end

  @spec cleanup_plugin_resources(String.t() | integer()) :: any()
  defp cleanup_plugin_resources(plugin_id) do
    Log.info("Cleaning up resources for plugin: #{plugin_id}")
    # Clean up any resources (files, connections, etc.)
    :ok
  end

  @spec backup_plugin_state(String.t() | integer(), map()) :: any()
  defp backup_plugin_state(plugin_id, state) do
    %{
      plugin: Map.get(state.plugins, plugin_id),
      plugin_state: Map.get(state.plugin_states, plugin_id),
      metadata: Map.get(state.metadata, plugin_id)
    }
  end

  @spec restore_plugin_state(String.t() | integer(), any(), map()) :: any()
  defp restore_plugin_state(plugin_id, backup, state) do
    restored_state =
      state
      |> maybe_restore_plugin(plugin_id, backup.plugin)
      |> maybe_restore_plugin_state(plugin_id, backup.plugin_state)
      |> maybe_restore_metadata(plugin_id, backup.metadata)

    {:ok, restored_state}
  end

  @spec maybe_restore_plugin(map(), String.t() | integer(), any()) :: any()
  defp maybe_restore_plugin(state, _plugin_id, nil), do: state

  @spec maybe_restore_plugin(map(), String.t() | integer(), any()) :: any()
  defp maybe_restore_plugin(state, plugin_id, plugin) do
    put_in(state.plugins[plugin_id], plugin)
  end

  @spec maybe_restore_plugin_state(map(), String.t() | integer(), any()) ::
          any()
  defp maybe_restore_plugin_state(state, _plugin_id, nil), do: state

  @spec maybe_restore_plugin_state(map(), String.t() | integer(), map()) ::
          any()
  defp maybe_restore_plugin_state(state, plugin_id, plugin_state) do
    put_in(state.plugin_states[plugin_id], plugin_state)
  end

  @spec maybe_restore_metadata(map(), String.t() | integer(), any()) :: any()
  defp maybe_restore_metadata(state, _plugin_id, nil), do: state

  @spec maybe_restore_metadata(map(), String.t() | integer(), any()) :: any()
  defp maybe_restore_metadata(state, plugin_id, metadata) do
    put_in(state.metadata[plugin_id], metadata)
  end

  @spec validate_all_operations(any(), any()) :: {:ok, any()} | {:error, any()}
  defp validate_all_operations(_, operations) do
    errors =
      Enum.reduce(operations, [], fn op, acc ->
        case validate_operation(op) do
          {:ok, _} -> acc
          {:error, reason} -> [reason | acc]
        end
      end)

    handle_validation_errors(errors, operations)
  end

  @spec handle_validation_errors(any(), any()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_validation_errors([], operations), do: {:ok, operations}

  @spec handle_validation_errors([String.t()], any()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_validation_errors(errors, _operations) do
    error(:validation, "Invalid operations", %{errors: errors})
  end

  @spec validate_operation(any()) :: {:ok, any()} | {:error, any()}
  defp validate_operation({:load, plugin_id, _config})
       when is_binary(plugin_id),
       do: {:ok, :valid}

  @spec validate_operation(any()) :: {:ok, any()} | {:error, any()}
  defp validate_operation({:unload, plugin_id}) when is_binary(plugin_id),
    do: {:ok, :valid}

  @spec validate_operation(any()) :: {:ok, any()} | {:error, any()}
  defp validate_operation(_), do: {:error, "Invalid operation format"}

  @spec execute_with_rollback(any(), any(), map()) :: any()
  defp execute_with_rollback(operations, _original_operations, initial_state) do
    {final_state, _executed} =
      Enum.reduce_while(operations, {initial_state, []}, fn op, {state, done} ->
        case execute_operation(op, state) do
          {:ok, new_state} ->
            {:cont, {new_state, [op | done]}}

          {:error, reason} ->
            # Rollback executed operations
            Log.module_error(
              "Operation failed, rolling back: #{inspect(reason)}"
            )

            rollback_state = rollback_operations(done, initial_state)
            {:halt, {:error, reason, rollback_state}}
        end
      end)

    case final_state do
      {:error, _reason, _state} -> final_state
      _ -> {:ok, final_state}
    end
  end

  @spec execute_operation(any(), map()) :: any()
  defp execute_operation({:load, plugin_id, config}, state) do
    safe_load_plugin(plugin_id, config, state)
  end

  @spec execute_operation(any(), map()) :: any()
  defp execute_operation({:unload, plugin_id}, state) do
    safe_unload_plugin(plugin_id, state)
  end

  @spec rollback_operations(any(), map()) :: any()
  defp rollback_operations(operations, initial_state) do
    Enum.reduce(operations, initial_state, fn op, state ->
      case rollback_operation(op, state) do
        {:ok, new_state} -> new_state
        _ -> state
      end
    end)
  end

  @spec rollback_operation(any(), map()) :: any()
  defp rollback_operation({:load, plugin_id, _config}, state) do
    # Rollback load by unloading
    safe_unload_plugin(plugin_id, state)
  end

  @spec rollback_operation(any(), map()) :: any()
  defp rollback_operation({:unload, _plugin_id}, state) do
    # Rollback unload by reloading (if we have the backup)
    # This is simplified - in reality we'd need the original config
    {:ok, state}
  end

  @spec verify_state_consistency(map()) :: any()
  defp verify_state_consistency(state) do
    # Verify that the state is internally consistent
    inconsistencies =
      Enum.reduce(
        Map.get(state, :load_order, []),
        [],
        fn plugin_id, acc ->
          check_plugin_consistency(plugin_id, state, acc)
        end
      )

    handle_consistency_check(inconsistencies, state)
  end

  @spec check_plugin_consistency(String.t() | integer(), map(), any()) :: any()
  defp check_plugin_consistency(plugin_id, state, acc) do
    do_check_consistency(Map.has_key?(state.plugins, plugin_id), plugin_id, acc)
  end

  @spec do_check_consistency(any(), String.t() | integer(), any()) :: any()
  defp do_check_consistency(true, _plugin_id, acc), do: acc

  @spec do_check_consistency(any(), String.t() | integer(), any()) :: any()
  defp do_check_consistency(false, plugin_id, acc) do
    ["Plugin #{plugin_id} in load_order but not in plugins map" | acc]
  end

  @spec handle_consistency_check(any(), map()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_consistency_check([], state), do: {:ok, state}

  @spec handle_consistency_check(any(), map()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_consistency_check(inconsistencies, _state) do
    error(:validation, "State consistency check failed", %{
      inconsistencies: inconsistencies
    })
  end
end
