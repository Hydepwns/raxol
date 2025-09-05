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
    validate_and_execute_command(
      command in extension.commands,
      extension,
      extension_id,
      command,
      args,
      state
    )
  end

  defp validate_and_execute_command(
         false,
         _extension,
         _extension_id,
         _command,
         _args,
         _state
       ) do
    {:error, :command_not_found}
  end

  defp validate_and_execute_command(
         true,
         extension,
         extension_id,
         command,
         args,
         state
       ) do
    case do_execute_command(extension, command, args) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        new_extension = %{extension | status: :error, error: reason}
        _new_state = put_in(state.extensions[extension_id], new_extension)
        {:error, reason}
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
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           execute_by_type(module, type, command, args)
         end) do
      {:ok, result} ->
        result

      {:error, reason} ->
        Logger.error("Command execution failed: #{inspect(reason)}")
        {:error, :command_execution_failed}
    end
  end

  defp execute_by_type(module, :script, command, args) do
    execute_if_exported(
      function_exported?(module, :execute_command, 2),
      module,
      :execute_command,
      [command, args]
    )
  end

  defp execute_by_type(module, :plugin, command, args) do
    execute_if_exported(
      function_exported?(module, :run_extension, 2),
      module,
      :run_extension,
      [command, args]
    )
  end

  defp execute_by_type(module, :theme, _command, args) do
    execute_if_exported(
      function_exported?(module, :apply_theme, 1),
      module,
      :apply_theme,
      [args]
    )
  end

  defp execute_by_type(module, :custom, command, args) do
    execute_if_exported(
      function_exported?(module, :execute_feature, 2),
      module,
      :execute_feature,
      [command, args]
    )
  end

  defp execute_if_exported(true, module, function, args) do
    apply(module, function, args)
  end

  defp execute_if_exported(false, _module, _function, _args) do
    {:error, :command_not_implemented}
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
