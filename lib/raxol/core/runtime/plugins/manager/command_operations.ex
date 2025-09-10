defmodule Raxol.Core.Runtime.Plugins.PluginManager.CommandOperations do
  @moduledoc """
  Command handling operations for plugin manager.
  Manages plugin command execution, hooks, and command processing.
  """

  alias Raxol.Core.Runtime.Plugins.CommandHandler

  @type plugin_id :: String.t()
  @type command :: String.t()
  @type hook_name :: atom()
  @type state :: map()

  @doc """
  Handles command execution.
  """
  @spec handle_execute_command(command(), any(), any(), state()) ::
          {:reply, any(), state()}
  def handle_execute_command(command, _arg1, _arg2, state) do
    case CommandHandler.process_command(command, state) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @doc """
  Handles command processing.
  """
  @spec handle_process_command(command(), state()) :: {:reply, any(), state()}
  def handle_process_command(command, state) do
    case CommandHandler.process_command(command, state.command_registry_table) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @doc """
  Handles plugin hook calls.
  """
  @spec handle_call_hook(plugin_id(), hook_name(), list(), state()) ::
          {:reply, any(), state()}
  def handle_call_hook(plugin_id, hook_name, args, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:reply, {:error, :plugin_not_found}, state}

      plugin_module ->
        case call_plugin_hook(plugin_module, hook_name, args) do
          {:ok, result} ->
            updated_state = maybe_update_plugin_state(plugin_id, result, state)
            {:reply, {:ok, result}, updated_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}

          result ->
            {:reply, result, state}
        end
    end
  end

  @doc false
  def call_plugin_hook(plugin_module, hook_name, args) do
    case function_exported?(plugin_module, hook_name, length(args)) do
      true ->
        case Raxol.Core.ErrorHandling.safe_call(fn ->
               apply(plugin_module, hook_name, args)
             end) do
          {:ok, result} -> {:ok, result}
          {:error, reason} -> {:error, {:hook_error, reason}}
        end

      false ->
        {:error, {:hook_not_found, hook_name}}
    end
  end

  defp maybe_update_plugin_state(plugin_id, result, state) do
    case result do
      {:state_update, new_plugin_state} ->
        new_plugin_states =
          Map.put(state.plugin_states, plugin_id, new_plugin_state)

        %{state | plugin_states: new_plugin_states}

      _ ->
        state
    end
  end
end
