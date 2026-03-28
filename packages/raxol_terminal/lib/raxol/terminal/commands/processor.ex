defmodule Raxol.Terminal.Commands.Processor do
  @moduledoc """
  Handles command processing for the terminal emulator.
  This module is responsible for parsing, validating, and executing terminal commands.
  """

  alias Raxol.Terminal.Commands.{
    Executor,
    ParameterValidation
  }

  alias Raxol.Terminal.Commands.CommandsParser, as: Parser

  alias Raxol.Terminal.Emulator

  @doc """
  Processes a command string and executes it on the emulator.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec process_command(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def process_command(emulator, command) when is_binary(command) do
    case Parser.parse(command) do
      {:ok, parsed_command} ->
        execute_command(emulator, parsed_command)

      {:error, reason} ->
        {:error, "Failed to parse command: #{inspect(reason)}"}
    end
  end

  @doc """
  Executes a parsed command on the emulator.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec execute_command(Emulator.t(), map()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def execute_command(emulator, %{type: :csi} = command) do
    Executor.execute_csi_command(
      emulator,
      command.params_buffer,
      command.intermediates_buffer,
      command.final_byte
    )
  end

  def execute_command(emulator, %{type: :osc} = command) do
    Executor.execute_osc_command(
      emulator,
      command.command,
      command.params
    )
  end

  def execute_command(emulator, %{type: :dcs} = command) do
    Executor.execute_dcs_command(
      emulator,
      command.params_buffer || "",
      command.intermediates_buffer || "",
      command.data_string || ""
    )
  end

  def execute_command(_emulator, invalid_command) do
    {:error, "Invalid command type: #{inspect(invalid_command)}"}
  end

  @doc """
  Validates command parameters against the emulator's current state.
  Returns {:ok, validated_params} or {:error, reason}.
  """
  @spec validate_parameters(Emulator.t(), list(), atom()) ::
          {:ok, list()} | {:error, String.t()}
  def validate_parameters(emulator, params, command_type) do
    case command_type do
      :cursor ->
        {:ok, ParameterValidation.validate_coordinates(emulator, params)}

      :screen ->
        {:ok, ParameterValidation.validate_count(emulator, params)}

      :mode ->
        {:ok, ParameterValidation.validate_mode(params)}

      :color ->
        {:ok, ParameterValidation.validate_color(params)}

      _ ->
        {:ok, params}
    end
  end

  @doc """
  Handles command execution errors.
  Returns {:ok, updated_emulator} with error state or {:error, reason}.
  """
  @spec handle_command_error(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def handle_command_error(emulator, reason) do
    Raxol.Core.Runtime.Log.error("Command execution error: #{reason}")
    {:ok, emulator}
  end
end
