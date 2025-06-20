defmodule Raxol.Terminal.CommandExecutor do
  @moduledoc """
  DEPRECATED: Handles the execution of parsed terminal commands.

  This module is being replaced by `Raxol.Terminal.Commands.Executor` and
  various submodules within `Raxol.Terminal.Commands.*`.

  Existing functions are kept temporarily for backward compatibility or as
  placeholders during refactoring, but they primarily log warnings and delegate
  to the new modules where possible.

  For mode handling, use `Raxol.Terminal.Commands.ModeHandlers` instead.
  """
  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Parser
  alias Raxol.Terminal.Commands.Executor

  @deprecated "This module is deprecated. Use Raxol.Terminal.Commands.* modules instead."

  @doc """
  Executes a CSI (Control Sequence Introducer) command.

  DEPRECATED: Use Raxol.Terminal.Commands.Executor.execute_csi_command/4 instead.
  """
  @spec execute_csi_command(
          Emulator.t(),
          String.t(),
          String.t(),
          non_neg_integer()
        ) :: Emulator.t()
  def execute_csi_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        final_byte
      ) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Raxol.Terminal.CommandExecutor.execute_csi_command/4 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Executor.execute_csi_command/4 instead.",
      []
    )

    Executor.execute_csi_command(
      emulator,
      params_buffer,
      intermediates_buffer,
      final_byte
    )
  end

  @doc """
  Parses a raw parameter string buffer into a list of integers or nil values.

  DEPRECATED: Use Raxol.Terminal.Commands.Parser.parse_params/1 instead.
  """
  @spec parse_params(String.t()) ::
          list(integer() | nil | list(integer() | nil))
  def parse_params(params_string) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Raxol.Terminal.CommandExecutor.parse_params/1 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Parser.parse_params/1 instead.",
      []
    )

    Parser.parse_params(params_string)
  end

  @doc """
  Gets a parameter at a specific index from the params list.

  DEPRECATED: Use Raxol.Terminal.Commands.Parser.get_param/3 instead.
  """
  @spec get_param(list(integer() | nil), pos_integer(), integer()) :: integer()
  def get_param(params, index, default \\ 1) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Raxol.Terminal.CommandExecutor.get_param/3 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Parser.get_param/3 instead.",
      []
    )

    Parser.get_param(params, index, default)
  end

  @doc """
  Executes an OSC (Operating System Command).

  DEPRECATED: Use Raxol.Terminal.Commands.Executor.execute_osc_command/2 instead.
  """
  @spec execute_osc_command(Emulator.t(), String.t()) :: Emulator.t()
  def execute_osc_command(emulator, command_string) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Raxol.Terminal.CommandExecutor.execute_osc_command/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Executor.execute_osc_command/2 instead.",
      []
    )

    Executor.execute_osc_command(emulator, command_string)
  end

  @doc """
  Executes a DCS (Device Control String) command.

  DEPRECATED: Use Raxol.Terminal.Commands.Executor.execute_dcs_command/4 instead.
  """
  @spec execute_dcs_command(
          Emulator.t(),
          String.t(),
          String.t(),
          String.t()
        ) :: Emulator.t()
  def execute_dcs_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        data_string
      ) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Raxol.Terminal.CommandExecutor.execute_dcs_command/4 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Executor.execute_dcs_command/4 instead.",
      []
    )

    Raxol.Terminal.Commands.Executor.execute_dcs_command(
      emulator,
      params_buffer,
      intermediates_buffer,
      data_string
    )
  end
end
