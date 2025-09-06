defmodule Raxol.Core.Runtime.Plugins.Manager.Utility do
  @moduledoc """
  Utility functions and legacy compatibility helpers for the plugin manager.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Runtime.Plugins.Manager.Lifecycle

  @type plugin_id :: String.t()
  @type state :: map()

  @doc """
  Handles plugin operations with consistent error handling and state updates.
  """
  @spec handle_plugin_operation(
          {:ok, {map(), map(), term()}} | {:ok, map()} | {:error, term()},
          plugin_id(),
          state(),
          String.t()
        ) :: {:reply, :ok | {:error, term()}, state()}
  def handle_plugin_operation(operation, plugin_id, state, success_message) do
    case operation do
      {:ok, {updated_metadata, updated_states, updated_table}} ->
        updated_state = %{
          state
          | metadata: updated_metadata,
            plugin_states: updated_states,
            command_registry_table: updated_table
        }

        {:reply, :ok, updated_state}

      {:ok, mock_state} when is_map(mock_state) ->
        updated_state = %{
          state
          | plugins: Map.get(mock_state, :plugins, state.plugins),
            metadata: Map.get(mock_state, :metadata, state.metadata),
            plugin_states:
              Map.get(mock_state, :plugin_states, state.plugin_states),
            load_order: Map.get(mock_state, :load_order, state.load_order),
            plugin_config:
              Map.get(mock_state, :plugin_config, state.plugin_config)
        }

        {:reply, :ok, updated_state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to #{success_message} plugin #{plugin_id}",
          nil,
          nil,
          %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
        )

        {:reply, {:error, reason}, state}
    end
  end

  @doc """
  Handles application errors with recovery strategies.
  """
  @spec handle_error(term(), map()) :: {:ok, atom()}
  def handle_error(error, _context) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Application error occurred",
      error,
      nil,
      %{module: __MODULE__}
    )

    case error do
      %{type: :runtime_error} ->
        {:ok, :restart_components}

      %{type: :resource_error} ->
        {:ok, :reinitialize_resources}

      _ ->
        {:ok, :continue}
    end
  end

  @doc """
  Handles application cleanup operations.
  """
  @spec handle_cleanup(map()) :: {:ok, atom()} | {:error, atom()}
  def handle_cleanup(context) do
    Raxol.Core.Runtime.Log.info(
      "Performing application cleanup",
      %{module: __MODULE__, context: context}
    )

    with :ok <- cleanup_resources(context),
         :ok <- cleanup_plugins(context),
         :ok <- cleanup_state(context) do
      {:ok, :cleanup_complete}
    else
      error ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed during cleanup",
          error,
          nil,
          %{module: __MODULE__, context: context}
        )

        {:error, :cleanup_failed}
    end
  end

  @doc """
  Calls a plugin hook with proper error handling.
  """
  @spec call_plugin_hook(String.t(), atom(), list(), map()) ::
          {:ok, term()} | {:error, term()}
  def call_plugin_hook(plugin_name, hook_name, args, plugin_state) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           apply(plugin_state.module, hook_name, [plugin_state | args])
         end) do
      {:ok, result} ->
        {:ok, result}

      {:error, error} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Plugin hook #{hook_name} failed for #{plugin_name}",
          error,
          nil,
          %{module: __MODULE__, plugin: plugin_name, hook: hook_name}
        )

        {:error, error}
    end
  end

  @doc """
  Loads a plugin with legacy interface support.
  """
  @spec load_plugin(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def load_plugin(name, _config) do
    case Lifecycle.load_plugin(%{plugins: %{}}, name) do
      {:ok, state} ->
        case Map.get(state.plugins, name) do
          nil -> {:error, {:plugin_not_loaded, name}}
          plugin -> {:ok, plugin}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles an event through the plugin system.
  """
  @spec handle_event(state(), map()) :: {:ok, state()} | {:error, term()}
  def handle_event(state, event) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           updated_metadata = process_event_metadata(state.metadata, event)
           updated_states = process_event_states(state.plugin_states, event)

           updated_table =
             process_event_commands(state.command_registry_table, event)

           updated_state = %{
             state
             | metadata: updated_metadata,
               plugin_states: updated_states,
               command_registry_table: updated_table
           }

           {:ok, updated_state}
         end) do
      {:ok, result} ->
        result

      {:error, error} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to handle event in plugin manager",
          error,
          nil,
          %{module: __MODULE__, event: event}
        )

        {:error, error}
    end
  end

  defp cleanup_resources(_context), do: :ok
  defp cleanup_plugins(_context), do: :ok
  defp cleanup_state(_context), do: :ok

  defp process_event_metadata(metadata, _event), do: metadata
  defp process_event_states(states, _event), do: states
  defp process_event_commands(table, _event), do: table
end
