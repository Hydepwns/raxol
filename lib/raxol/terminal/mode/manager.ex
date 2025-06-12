defmodule Raxol.Terminal.Mode.Manager do
  @moduledoc """
  Manages terminal modes for the terminal emulator.
  This module handles various terminal modes like DECCKM, DECOM, etc.
  """

  alias Raxol.Terminal.ModeManager
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @doc """
  Creates a new mode manager instance.
  """
  @spec new() :: ModeManager.t()
  def new do
    ModeManager.new()
  end

  @doc """
  Gets the current mode manager instance.
  """
  @spec get_manager(EmulatorStruct.t()) :: ModeManager.t()
  def get_manager(emulator) do
    emulator.mode_manager
  end

  @doc """
  Updates the mode manager instance.
  """
  @spec update_manager(EmulatorStruct.t(), ModeManager.t()) :: EmulatorStruct.t()
  def update_manager(emulator, manager) do
    %{emulator | mode_manager: manager}
  end

  @doc """
  Sets a mode.
  """
  @spec set_mode(EmulatorStruct.t(), atom()) :: EmulatorStruct.t()
  def set_mode(emulator, mode) do
    new_manager = ModeManager.set_mode(emulator.mode_manager, mode)
    update_manager(emulator, new_manager)
  end

  @doc """
  Resets a mode.
  """
  @spec reset_mode(EmulatorStruct.t(), atom()) :: EmulatorStruct.t()
  def reset_mode(emulator, mode) do
    new_manager = ModeManager.reset_mode(emulator.mode_manager, mode)
    update_manager(emulator, new_manager)
  end

  @doc """
  Checks if a mode is set.
  """
  @spec mode_set?(EmulatorStruct.t(), atom()) :: boolean()
  def mode_set?(emulator, mode) do
    ModeManager.mode_set?(emulator.mode_manager, mode)
  end

  @doc """
  Gets all set modes.
  """
  @spec get_set_modes(EmulatorStruct.t()) :: list(atom())
  def get_set_modes(emulator) do
    ModeManager.get_set_modes(emulator.mode_manager)
  end

  @doc """
  Resets all modes.
  """
  @spec reset_all_modes(EmulatorStruct.t()) :: EmulatorStruct.t()
  def reset_all_modes(emulator) do
    new_manager = ModeManager.reset_all_modes(emulator.mode_manager)
    update_manager(emulator, new_manager)
  end

  @doc """
  Saves current modes.
  """
  @spec save_modes(EmulatorStruct.t()) :: EmulatorStruct.t()
  def save_modes(emulator) do
    new_manager = ModeManager.save_modes(emulator.mode_manager)
    update_manager(emulator, new_manager)
  end

  @doc """
  Restores saved modes.
  """
  @spec restore_modes(EmulatorStruct.t()) :: EmulatorStruct.t()
  def restore_modes(emulator) do
    new_manager = ModeManager.restore_modes(emulator.mode_manager)
    update_manager(emulator, new_manager)
  end
end
