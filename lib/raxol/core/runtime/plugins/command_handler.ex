defmodule Raxol.Core.Runtime.Plugins.CommandHandler do
  @moduledoc """
  Handles command execution and management for plugins.
  This module is responsible for:
  - Processing command requests
  - Executing commands through plugins
  - Managing command results and error handling
  - Handling clipboard-related commands
  """

  alias Raxol.Core.Runtime.Plugins.CommandHelper
  require Logger

  @doc """
  Handles a command request by delegating to the appropriate plugin.
  Returns an updated state and any necessary side effects.
  """
  def handle_command(command_atom, namespace, data, dispatcher_pid, state) do
    command_name_str = Atom.to_string(command_atom)

    Logger.info(
      "[#{__MODULE__}] Delegating command: #{inspect(command_atom)} in namespace: #{inspect(namespace)} with data: #{inspect(data)}, result_to: #{inspect(dispatcher_pid)}"
    )

    case CommandHelper.handle_command(
           state.command_registry_table,
           command_name_str,
           namespace,
           data,
           state
         ) do
      {:ok, new_plugin_state, result_tuple, plugin_id} ->
        Logger.debug(
          "[#{__MODULE__}] Command #{inspect(command_atom)} executed by plugin #{inspect(plugin_id)}. Result: #{inspect(result_tuple)}"
        )

        updated_plugin_states =
          Map.put(state.plugin_states, plugin_id, new_plugin_state)

        result_msg = {:command_result, {command_atom, result_tuple}}

        Logger.debug(
          "[#{__MODULE__}] Sending result to #{inspect(dispatcher_pid)}: #{inspect(result_msg)}"
        )

        send(dispatcher_pid, result_msg)

        {:ok, updated_plugin_states}

      :not_found ->
        Logger.warning(
          "[#{__MODULE__}] Command not found by CommandHelper: #{inspect(command_atom)} in namespace: #{inspect(namespace)}"
        )

        error_result_tuple = {:error, :command_not_found}

        send(
          dispatcher_pid,
          {:command_result, {command_atom, error_result_tuple}}
        )

        {:error, :not_found}

      {:error, reason_tuple, plugin_id} ->
        Logger.error(
          "[#{__MODULE__}] Error executing command #{inspect(command_atom)} in plugin #{inspect(plugin_id || "unknown")}: #{inspect(reason_tuple)}"
        )

        send(
          dispatcher_pid,
          {:command_result, {command_atom, {:error, reason_tuple}}}
        )

        {:error, reason_tuple}
    end
  end

  @doc """
  Handles clipboard result messages.
  """
  def handle_clipboard_result(pid, content) do
    send(pid, {:command_result, {:clipboard_content, content}})
    :ok
  end
end
