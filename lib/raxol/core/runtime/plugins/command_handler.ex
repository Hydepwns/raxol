defmodule Raxol.Core.Runtime.Plugins.CommandHandler do
  @moduledoc """
  Handles plugin command processing and execution.
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Processes a command from a plugin.
  """
  def process_command(command, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Processing command: #{inspect(command)}",
      %{command: command}
    )

    case command do
      :load_plugin ->
        {:error, :plugin_id_required}

      :unload_plugin ->
        {:error, :plugin_id_required}

      :get_plugin ->
        {:error, :plugin_id_required}

      :update_plugin ->
        {:error, :plugin_id_required}

      :list_plugins ->
        plugins = Raxol.Core.Runtime.Plugins.Discovery.list_plugins(state)
        {:ok, plugins}

      :get_plugin_state ->
        {:error, :plugin_id_required}

      :set_plugin_state ->
        {:error, :plugin_id_required}

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "[#{__MODULE__}] Unknown command: #{inspect(command)}",
          %{command: command}
        )

        {:error, :unknown_command}
    end
  end

  @doc """
  Handles a command with arguments.
  """
  def handle_command(command_atom, namespace, data, dispatcher_pid, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Handling command: #{inspect(command_atom)}",
      %{command_atom: command_atom, namespace: namespace, data: data}
    )

    case execute_command(command_atom, namespace, data, state) do
      {:ok, result} ->
        send(dispatcher_pid, {:command_result, command_atom, result})
        {:ok, state.plugin_states}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "[#{__MODULE__}] Command failed: #{inspect(command_atom)}",
          reason,
          nil,
          %{command_atom: command_atom, namespace: namespace, data: data}
        )

        send(dispatcher_pid, {:command_error, command_atom, reason})
        {:error, reason}
    end
  end

  @doc """
  Handles clipboard result.
  """
  def handle_clipboard_result(pid, content) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Handling clipboard result",
      %{pid: pid, content_length: byte_size(content)}
    )

    send(pid, {:clipboard_result, content})
  end

  # Helper function to execute commands
  defp execute_command(:load_plugin, _namespace, plugin_id, state) do
    case Raxol.Core.Runtime.Plugins.LifecycleManager.load_plugin(
           plugin_id,
           %{},
           state.plugins,
           state.metadata,
           state.plugin_states,
           state.load_order,
           state.command_registry_table,
           state.plugin_config
         ) do
      {:ok, _updated_maps} -> {:ok, :plugin_loaded}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_command(:unload_plugin, _namespace, plugin_id, state) do
    case Raxol.Core.Runtime.Plugins.LifecycleManager.unload_plugin(
           plugin_id,
           state.plugins,
           state.metadata,
           state.plugin_states,
           state.command_registry_table,
           state.plugin_config
         ) do
      {:ok, _updated_maps} -> {:ok, :plugin_unloaded}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_command(:get_plugin, _namespace, plugin_id, state) do
    case Raxol.Core.Runtime.Plugins.Discovery.get_plugin(plugin_id, state) do
      {:ok, plugin} -> {:ok, plugin}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_command(
         :update_plugin,
         _namespace,
         {plugin_id, update_fun},
         state
       ) do
    updated_state =
      Raxol.Core.Runtime.Plugins.StateManager.update_plugin_state(
        plugin_id,
        update_fun,
        state
      )

    {:ok, updated_state}
  end

  defp execute_command(:list_plugins, _namespace, _data, state) do
    plugins = Raxol.Core.Runtime.Plugins.Discovery.list_plugins(state)
    {:ok, plugins}
  end

  defp execute_command(:get_plugin_state, _namespace, plugin_id, state) do
    Raxol.Core.Runtime.Plugins.StateManager.get_plugin_state(plugin_id, state)
  end

  defp execute_command(
         :set_plugin_state,
         _namespace,
         {plugin_id, new_state},
         state
       ) do
    updated_state =
      Raxol.Core.Runtime.Plugins.StateManager.set_plugin_state(
        plugin_id,
        new_state,
        state
      )

    {:ok, updated_state}
  end

  defp execute_command(command, namespace, data, _state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[#{__MODULE__}] Unknown command: #{inspect(command)}",
      %{command: command, namespace: namespace, data: data}
    )

    {:error, :unknown_command}
  end

  @doc """
  Handles responses from command execution.
  """
  def handle_response(command, response, state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Handling response for command: #{inspect(command)}",
      %{command: command, response: response}
    )

    # For now, just return the state unchanged
    # This would be where you'd process command responses and update state accordingly
    {:ok, state}
  end
end
