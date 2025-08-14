defmodule Raxol.Plugins.Manager.Hooks do
  @moduledoc """
  Handles plugin hook execution.
  Provides functions for running various plugin hooks and collecting their results.
  """

  
  require Raxol.Core.Runtime.Log

  alias Raxol.Plugins.Manager.Core

  @doc """
  Runs render-related hooks for all enabled plugins.
  Collects any direct output commands (e.g., escape sequences) returned by plugins.
  Returns {:ok, updated_manager, list_of_output_commands}
  """
  def run_render_hooks(%Core{} = manager) do
    Enum.reduce(manager.plugins, {:ok, manager, []}, &run_plugin_render_hook/2)
  end

  defp run_plugin_render_hook({_name, plugin}, {:ok, acc_manager, acc_commands}) do
    if plugin.enabled do
      module = plugin.__struct__

      if function_exported?(module, :handle_render, 1) do
        handle_render_hook(module, plugin, acc_manager, acc_commands)
      else
        {:ok, acc_manager, acc_commands}
      end
    else
      {:ok, acc_manager, acc_commands}
    end
  end

  defp handle_render_hook(module, plugin, acc_manager, acc_commands) do
    case module.handle_render(plugin) do
      {:ok, updated_plugin, command} when not is_nil(command) ->
        updated_manager =
          Core.update_plugins(
            acc_manager,
            Map.put(acc_manager.plugins, plugin.name, updated_plugin)
          )

        {:ok, updated_manager, [command | acc_commands]}

      {:ok, updated_plugin} ->
        updated_manager =
          Core.update_plugins(
            acc_manager,
            Map.put(acc_manager.plugins, plugin.name, updated_plugin)
          )

        {:ok, updated_manager, acc_commands}

      command when is_binary(command) ->
        {:ok, acc_manager, [command | acc_commands]}

      _ ->
        {:ok, acc_manager, acc_commands}
    end
  end

  @doc """
  Runs a specific hook on all enabled plugins.
  Returns {:ok, updated_manager, results} where results is a list of hook results.
  """
  def run_hook(%Core{} = manager, hook_name, args \\ []) do
    Enum.reduce(manager.plugins, {:ok, manager, []}, fn {name, plugin}, acc ->
      run_plugin_hook({name, plugin}, acc, hook_name, args)
    end)
  end

  defp run_plugin_hook(
         {_name, plugin},
         {:ok, acc_manager, acc_results},
         hook_name,
         args
       ) do
    if plugin.enabled do
      module = plugin.__struct__

      if function_exported?(module, hook_name, length(args) + 1) do
        handle_plugin_hook(
          module,
          plugin,
          hook_name,
          args,
          acc_manager,
          acc_results
        )
      else
        {:ok, acc_manager, acc_results}
      end
    else
      {:ok, acc_manager, acc_results}
    end
  end

  defp handle_plugin_hook(
         module,
         plugin,
         hook_name,
         args,
         acc_manager,
         acc_results
       ) do
    case apply(module, hook_name, [plugin | args]) do
      {:ok, updated_plugin, result} ->
        updated_manager =
          Core.update_plugins(
            acc_manager,
            Map.put(acc_manager.plugins, plugin.name, updated_plugin)
          )

        {:ok, updated_manager, [result | acc_results]}

      {:ok, updated_plugin} ->
        updated_manager =
          Core.update_plugins(
            acc_manager,
            Map.put(acc_manager.plugins, plugin.name, updated_plugin)
          )

        {:ok, updated_manager, acc_results}

      result ->
        {:ok, acc_manager, [result | acc_results]}
    end
  end
end
