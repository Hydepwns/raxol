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
    Enum.reduce(manager.plugins, {:ok, manager, []}, fn {_name, plugin},
                                                        {:ok, acc_manager,
                                                         acc_commands} ->
      if plugin.enabled do
        # Get the module from the struct
        module = plugin.__struct__

        # Check if module implements handle_render
        if function_exported?(module, :handle_render, 1) do
          # Call using the module with plugin state as first argument
          case module.handle_render(plugin) do
            {:ok, updated_plugin, command} when not is_nil(command) ->
              updated_manager =
                Core.update_plugins(
                  acc_manager,
                  Map.put(acc_manager.plugins, plugin.name, updated_plugin)
                )

              {:ok, updated_manager, [command | acc_commands]}

            # No command returned
            {:ok, updated_plugin} ->
              updated_manager =
                Core.update_plugins(
                  acc_manager,
                  Map.put(acc_manager.plugins, plugin.name, updated_plugin)
                )

              {:ok, updated_manager, acc_commands}

            # Allow plugins to just return the command if state doesn't change
            command when is_binary(command) ->
              {:ok, acc_manager, [command | acc_commands]}

            # Ignore other return values or errors for now
            _ ->
              {:ok, acc_manager, acc_commands}
          end
        else
          # Plugin doesn't implement hook
          {:ok, acc_manager, acc_commands}
        end
      else
        # Plugin disabled
        {:ok, acc_manager, acc_commands}
      end
    end)
  end

  @doc """
  Runs a specific hook on all enabled plugins.
  Returns {:ok, updated_manager, results} where results is a list of hook results.
  """
  def run_hook(%Core{} = manager, hook_name, args \\ []) do
    Enum.reduce(manager.plugins, {:ok, manager, []}, fn {_name, plugin},
                                                        {:ok, acc_manager,
                                                         acc_results} ->
      if plugin.enabled do
        # Get the module from the struct
        module = plugin.__struct__

        # Check if module implements the hook
        if function_exported?(module, hook_name, length(args) + 1) do
          # Call using the module with plugin state as first argument
          case apply(module, hook_name, [plugin | args]) do
            {:ok, updated_plugin, result} ->
              updated_manager =
                Core.update_plugins(
                  acc_manager,
                  Map.put(acc_manager.plugins, plugin.name, updated_plugin)
                )

              {:ok, updated_manager, [result | acc_results]}

            # No result returned
            {:ok, updated_plugin} ->
              updated_manager =
                Core.update_plugins(
                  acc_manager,
                  Map.put(acc_manager.plugins, plugin.name, updated_plugin)
                )

              {:ok, updated_manager, acc_results}

            # Allow plugins to just return the result if state doesn't change
            result ->
              {:ok, acc_manager, [result | acc_results]}
          end
        else
          # Plugin doesn't implement hook
          {:ok, acc_manager, acc_results}
        end
      else
        # Plugin disabled
        {:ok, acc_manager, acc_results}
      end
    end)
  end
end
