defmodule Raxol.Terminal.Extension.CommandHandler do
  @moduledoc """
  Handles extension command processing and execution.
  """

  require Logger

  @doc """
  Executes an extension command.
  """
  def execute_command(extension_id, command, args, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:error, :extension_not_found}

      extension ->
        handle_command_execution(extension, extension_id, command, args, state)
    end
  end

  # Private functions

  defp handle_command_execution(extension, extension_id, command, args, state) do
    if command in extension.commands do
      case do_execute_command(extension, command, args) do
        {:ok, result} ->
          {:ok, result}

        {:error, reason} ->
          new_extension = %{extension | status: :error, error: reason}
          _new_state = put_in(state.extensions[extension_id], new_extension)
          {:error, reason}
      end
    else
      {:error, :command_not_found}
    end
  end

  defp do_execute_command(extension, command, args) do
    case extension.module do
      {:ok, module} ->
        execute_module_command(module, extension.type, command, args)

      nil ->
        execute_fallback_command(extension, command, args)

      _ ->
        execute_fallback_command(extension, command, args)
    end
  end

  defp execute_module_command(module, type, command, args) do
    try do
      execute_by_type(module, type, command, args)
    rescue
      e ->
        Logger.error("Command execution failed: #{inspect(e)}")
        {:error, :command_execution_failed}
    end
  end

  defp execute_by_type(module, :script, command, args) do
    if function_exported?(module, :execute_command, 2) do
      module.execute_command(command, args)
    else
      {:error, :command_not_implemented}
    end
  end

  defp execute_by_type(module, :plugin, command, args) do
    if function_exported?(module, :run_extension, 2) do
      module.run_extension(command, args)
    else
      {:error, :command_not_implemented}
    end
  end

  defp execute_by_type(module, :theme, _command, args) do
    if function_exported?(module, :apply_theme, 1) do
      module.apply_theme(args)
    else
      {:error, :command_not_implemented}
    end
  end

  defp execute_by_type(module, :custom, command, args) do
    if function_exported?(module, :execute_feature, 2) do
      module.execute_feature(command, args)
    else
      {:error, :command_not_implemented}
    end
  end

  defp execute_fallback_command(extension, command, args) do
    # Fallback implementation for extensions without modules
    case extension.type do
      :script ->
        {:ok, "Command \"#{command}\" executed with args: #{inspect(args)}"}

      :plugin ->
        {:ok, "Command \"#{command}\" executed with args: #{inspect(args)}"}

      :theme ->
        {:ok, "Command \"#{command}\" executed with args: #{inspect(args)}"}

      :custom ->
        {:ok, "Command \"#{command}\" executed with args: #{inspect(args)}"}
    end
  end
end
