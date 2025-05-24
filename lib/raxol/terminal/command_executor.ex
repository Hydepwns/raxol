defmodule Raxol.Terminal.CommandExecutor do
  @moduledoc """
  DEPRECATED: Handles the execution of parsed terminal commands.

  This module is being replaced by `Raxol.Terminal.Commands.Executor` and
  various submodules within `Raxol.Terminal.Commands.*`.

  Existing functions are kept temporarily for backward compatibility or as
  placeholders during refactoring, but they primarily log warnings and delegate
  to the new modules where possible.
  """
  require Logger

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Screen
  alias Raxol.Terminal.Commands.Parser
  alias Raxol.Terminal.Commands.Executor
  alias Raxol.Terminal.Commands.CSIHandlers
  alias Raxol.Terminal.Commands.OSCHandlers
  alias Raxol.Terminal.Commands.DCSHandlers
  alias Raxol.Terminal.ModeManager

  # Display a compile-time deprecation warning
  @deprecated "This module is deprecated. Use Raxol.Terminal.Commands.* modules instead."

  # --- Sequence Executors ---

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
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.execute_csi_command/4 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Executor.execute_csi_command/4 instead."
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
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.parse_params/1 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Parser.parse_params/1 instead."
    )

    Parser.parse_params(params_string)
  end

  @doc """
  Gets a parameter at a specific index from the params list.

  DEPRECATED: Use Raxol.Terminal.Commands.Parser.get_param/3 instead.
  """
  @spec get_param(list(integer() | nil), pos_integer(), integer()) :: integer()
  def get_param(params, index, default \\ 1) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.get_param/3 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Parser.get_param/3 instead."
    )

    Parser.get_param(params, index, default)
  end

  @doc """
  Handles DEC Private Mode Set (CSI ? Pn h) and Reset (CSI ? Pn l).
  """
  @spec handle_dec_private_mode(Emulator.t(), list(integer()), :set | :reset) ::
          Emulator.t()
  def handle_dec_private_mode(emulator, params, action) do
    modes =
      Enum.map(params, &ModeManager.lookup_private/1) |> Enum.reject(&is_nil/1)

    case action do
      :set -> ModeManager.set_mode(emulator, modes)
      :reset -> ModeManager.reset_mode(emulator, modes)
    end
  end

  @doc """
  Handles Standard Mode Set (CSI Pn h) and Reset (CSI Pn l).
  """
  @spec handle_ansi_mode(Emulator.t(), list(integer()), :set | :reset) ::
          Emulator.t()
  def handle_ansi_mode(emulator, params, action) do
    modes =
      Enum.map(params, &ModeManager.lookup_standard/1) |> Enum.reject(&is_nil/1)

    case action do
      :set -> ModeManager.set_mode(emulator, modes)
      :reset -> ModeManager.reset_mode(emulator, modes)
    end
  end

  @doc """
  Clears the screen or a part of it based on the mode parameter.

  DEPRECATED: Use Raxol.Terminal.Commands.Screen.clear_screen/2 instead.
  """
  @spec clear_screen(Emulator.t(), integer()) :: Emulator.t()
  def clear_screen(emulator, mode) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.clear_screen/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.clear_screen/2 instead."
    )

    Screen.clear_screen(emulator, mode)
  end

  @doc """
  Clears a line or part of a line based on the mode parameter.

  DEPRECATED: Use Raxol.Terminal.Commands.Screen.clear_line/2 instead.
  """
  @spec clear_line(Emulator.t(), integer()) :: Emulator.t()
  def clear_line(emulator, mode) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.clear_line/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.clear_line/2 instead."
    )

    Screen.clear_line(emulator, mode)
  end

  @doc """
  Inserts blank lines at the current cursor position.

  DEPRECATED: Use Raxol.Terminal.Commands.Screen.insert_lines/2 instead.
  """
  @spec insert_line(Emulator.t(), integer()) :: Emulator.t()
  def insert_line(emulator, count) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.insert_line/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.insert_lines/2 instead."
    )

    Screen.insert_lines(emulator, count)
  end

  @doc """
  Deletes lines at the current cursor position.

  DEPRECATED: Use Raxol.Terminal.Commands.Screen.delete_lines/2 instead.
  """
  @spec delete_line(Emulator.t(), integer()) :: Emulator.t()
  def delete_line(emulator, count) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.delete_line/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.delete_lines/2 instead."
    )

    Screen.delete_lines(emulator, count)
  end

  @doc """
  Executes an OSC (Operating System Command).

  DEPRECATED: Use Raxol.Terminal.Commands.Executor.execute_osc_command/2 instead.
  """
  @spec execute_osc_command(Emulator.t(), String.t()) :: Emulator.t()
  def execute_osc_command(emulator, command_string) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.execute_osc_command/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Executor.execute_osc_command/2 instead."
    )

    Executor.execute_osc_command(emulator, command_string)
  end

  @doc """
  Executes a DCS (Device Control String) command.

  DEPRECATED: Use Raxol.Terminal.Commands.Executor.execute_dcs_command/5 instead.
  """
  @spec execute_dcs_command(
          Emulator.t(),
          String.t(),
          String.t(),
          non_neg_integer(),
          String.t()
        ) :: Emulator.t()
  def execute_dcs_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        final_byte,
        payload
      ) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.execute_dcs_command/5 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Executor.execute_dcs_command/5 instead."
    )

    Raxol.Terminal.Commands.Executor.execute_dcs_command(
      emulator,
      params_buffer,
      intermediates_buffer,
      final_byte,
      payload
    )
  end

  @doc """
  Erase Display handler.

  DEPRECATED: Use Raxol.Terminal.Commands.Screen.clear_screen/2 instead.
  """
  @spec handle_ed(Emulator.t(), integer()) :: Emulator.t()
  def handle_ed(emulator, mode \\ 0) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.handle_ed/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.clear_screen/2 instead."
    )

    Raxol.Terminal.Commands.Screen.clear_screen(emulator, mode)
  end

  @doc """
  Erase Line handler.

  DEPRECATED: Use Raxol.Terminal.Commands.Screen.clear_line/2 instead.
  """
  @spec handle_el(Emulator.t(), integer()) :: Emulator.t()
  def handle_el(emulator, mode \\ 0) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.handle_el/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.clear_line/2 instead."
    )

    Raxol.Terminal.Commands.Screen.clear_line(emulator, mode)
  end
end
