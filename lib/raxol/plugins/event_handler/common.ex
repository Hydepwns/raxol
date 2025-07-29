defmodule Raxol.Plugins.EventHandler.Common do
  @moduledoc """
  Common utilities and helper functions for event handling across plugins.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Plugins.Manager.Core

  @type event :: map()
  @type plugin :: map()
  @type manager :: Core.t()
  @type accumulator :: map()
  @type callback_name :: atom()
  @type result_handler_fun :: fun()

  @doc """
  Generic dispatcher that reduces over plugins and calls a specific handler function.
  """
  @spec dispatch_event(
          Core.t(),
          callback_name(),
          list(),
          non_neg_integer(),
          accumulator(),
          result_handler_fun()
        ) :: accumulator() | {:error, term()}
  def dispatch_event(
        manager,
        callback_name,
        args,
        required_arity,
        initial_acc,
        result_handler
      ) do
    Enum.reduce_while(manager.plugins, initial_acc, fn {_key, plugin}, acc ->
      handle_plugin_event(
        plugin,
        callback_name,
        args,
        required_arity,
        acc,
        result_handler
      )
    end)
  end

  @doc """
  Handles calling a specific callback on a plugin and processing the result.
  """
  @spec handle_plugin_event(
          plugin(),
          callback_name(),
          list(),
          non_neg_integer(),
          accumulator(),
          result_handler_fun()
        ) :: {:cont, accumulator()} | {:halt, accumulator()}
  def handle_plugin_event(
        plugin,
        callback_name,
        args,
        required_arity,
        acc,
        result_handler
      ) do
    cond do
      not is_map(plugin) ->
        log_invalid_plugin(plugin)
        {:cont, acc}

      not Map.get(plugin, :enabled, false) ->
        {:cont, acc}

      not has_required_callback?(plugin, callback_name, required_arity) ->
        {:cont, acc}

      true ->
        try do
          # Get the plugin from the manager
          plugin_instance = Core.get_plugin(acc.manager, plugin.name)
          # Prepend the plugin instance to the args
          full_args = [plugin_instance | args]
          result = apply(plugin.module, callback_name, full_args)
          result_handler.(acc, plugin, callback_name, result)
        rescue
          error ->
            log_plugin_crash(plugin, callback_name, error)
            {:cont, acc}
        end
    end
  end

  @doc """
  Updates the manager state with a new plugin state.
  """
  @spec update_manager_state(Core.t(), plugin(), map()) :: Core.t()
  def update_manager_state(manager, plugin, new_plugin_state) do
    plugin_name = normalize_plugin_key(plugin.name)

    %{
      manager
      | plugin_states:
          Map.put(manager.plugin_states, plugin_name, new_plugin_state)
    }
  end

  @doc """
  Updates a plugin instance in the manager.
  """
  @spec update_manager_plugin(Core.t(), plugin(), plugin()) :: Core.t()
  def update_manager_plugin(manager, _old_plugin, updated_plugin) do
    plugin_name = normalize_plugin_key(updated_plugin.name)
    
    %{
      manager
      | plugins: Map.put(manager.plugins, plugin_name, updated_plugin),
        loaded_plugins: Map.put(manager.loaded_plugins, plugin_name, updated_plugin)
    }
  end

  @doc """
  Extracts plugin state from a plugin struct.
  """
  @spec extract_plugin_state(plugin()) :: map()
  def extract_plugin_state(plugin) when is_map(plugin) do
    cond do
      Map.has_key?(plugin, :state) -> plugin.state
      Map.has_key?(plugin, :plugin_state) -> plugin.plugin_state
      true -> %{}
    end
  end

  def extract_plugin_state(_), do: %{}

  @doc """
  Logs an error from a plugin.
  """
  @spec log_plugin_error(plugin(), callback_name(), term()) :: :ok
  def log_plugin_error(plugin, callback_name, reason) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Plugin #{plugin.name} failed in #{callback_name}",
      %{
        plugin: plugin.name,
        callback: callback_name,
        reason: inspect(reason),
        module: __MODULE__
      }
    )
  end

  @doc """
  Logs an unexpected result from a plugin.
  """
  @spec log_unexpected_result(plugin(), callback_name(), term()) :: :ok
  def log_unexpected_result(plugin, callback_name, result) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Plugin #{plugin.name} returned unexpected result from #{callback_name}",
      %{
        plugin: plugin.name,
        callback: callback_name,
        result: inspect(result),
        module: __MODULE__
      }
    )
  end

  # Private helper functions

  defp has_required_callback?(plugin, callback_name, required_arity) do
    case plugin.module do
      nil ->
        false

      module when is_atom(module) ->
        function_exported?(module, callback_name, required_arity)

      _ ->
        false
    end
  end

  defp normalize_plugin_key(key) when is_binary(key), do: key
  defp normalize_plugin_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_plugin_key(key), do: inspect(key)

  defp log_invalid_plugin(plugin) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Invalid plugin structure encountered",
      %{
        plugin: inspect(plugin),
        module: __MODULE__
      }
    )
  end

  defp log_plugin_crash(plugin, callback_name, error) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Plugin #{plugin.name} crashed in #{callback_name}",
      error,
      nil,
      %{
        plugin: plugin.name,
        callback: callback_name,
        module: __MODULE__
      }
    )
  end
end
