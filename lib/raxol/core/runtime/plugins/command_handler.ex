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
  require Raxol.Core.Runtime.Log
  import Raxol.Guards
  @behaviour Raxol.Core.Runtime.Plugins.PluginCommandHandler.Behaviour

  @doc """
  Handles a command request by delegating to the appropriate plugin.
  Returns an updated state and any necessary side effects.
  """
  @impl Raxol.Core.Runtime.Plugins.PluginCommandHandler.Behaviour
  def handle_command(command_atom, namespace, data, dispatcher_pid, state) do
    command_name_str = Atom.to_string(command_atom)

    Raxol.Core.Runtime.Log.info(
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
        Raxol.Core.Runtime.Log.debug(
          "[#{__MODULE__}] Command #{inspect(command_atom)} executed by plugin #{inspect(plugin_id)}. Result: #{inspect(result_tuple)}"
        )

        updated_plugin_states =
          Map.put(state.plugin_states, plugin_id, new_plugin_state)

        result_msg = {:command_result, {command_atom, result_tuple}}

        Raxol.Core.Runtime.Log.debug(
          "[#{__MODULE__}] Sending result to #{inspect(dispatcher_pid)}: #{inspect(result_msg)}"
        )

        send(dispatcher_pid, result_msg)

        {:ok, updated_plugin_states}

      {:error, :not_found, _} ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "[#{__MODULE__}] Command not found by CommandHelper",
          %{
            module: __MODULE__,
            command_atom: command_atom,
            namespace: namespace,
            state: state
          }
        )

        error_result_tuple = {:error, :command_not_found}

        send(
          dispatcher_pid,
          {:command_result, {command_atom, error_result_tuple}}
        )

        {:error, :not_found}

      {:error, reason_tuple, plugin_id} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "[#{__MODULE__}] Error executing command",
          reason_tuple,
          nil,
          %{
            module: __MODULE__,
            command_atom: command_atom,
            plugin_id: plugin_id,
            namespace: namespace,
            state: state
          }
        )

        send(
          dispatcher_pid,
          {:command_result, {command_atom, {:error, reason_tuple}}}
        )

        {:error, reason_tuple}
    end
  end

  @doc """
  Processes a command by delegating to the appropriate handler.
  Returns an updated state and any necessary side effects.
  """
  def process_command(command, state) do
    case command do
      {command_atom, namespace, data} ->
        handle_command(command_atom, namespace, data, self(), state)

      {command_atom, data} ->
        handle_command(command_atom, :default, data, self(), state)

      command_atom when atom?(command_atom) ->
        handle_command(command_atom, :default, %{}, self(), state)

      _ ->
        {:error, :invalid_command}
    end
  end

  @doc """
  Handles clipboard result messages.
  """
  def handle_clipboard_result(pid, content) do
    send(pid, {:command_result, {:clipboard_content, content}})
    :ok
  end

  @impl Raxol.Core.Runtime.Plugins.PluginCommandHandler.Behaviour
  def handle_command_result(command_atom, result, dispatcher_pid, state) do
    send(dispatcher_pid, {:command_result, {command_atom, result}})
    {:ok, state}
  end

  @impl Raxol.Core.Runtime.Plugins.PluginCommandHandler.Behaviour
  def handle_command_error(command_atom, error, dispatcher_pid, state) do
    send(dispatcher_pid, {:command_result, {command_atom, {:error, error}}})
    {:ok, state}
  end

  @impl Raxol.Core.Runtime.Plugins.PluginCommandHandler.Behaviour
  def handle_command_timeout(command_atom, dispatcher_pid, state) do
    send(dispatcher_pid, {:command_result, {command_atom, {:error, :timeout}}})
    {:ok, state}
  end

  @impl Raxol.Core.Runtime.Plugins.PluginCommandHandler.Behaviour
  def update_command_state(state, new_state) do
    Map.merge(state, new_state)
  end
end
