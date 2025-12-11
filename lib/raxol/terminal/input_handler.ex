defmodule Raxol.Terminal.InputHandler do
  @moduledoc """
  Main input handler module that coordinates between different input handling components.
  """

  alias Raxol.Terminal.Input.{
    CoreHandler,
    CharacterProcessor,
    ControlSequenceHandler,
    ClipboardHandler
  }

  @doc """
  Creates a new input handler with default values.
  """
  def new do
    CoreHandler.new()
  end

  @doc """
  Handles clipboard paste operation.
  """
  def handle_paste(handler) do
    ClipboardHandler.handle_paste(handler)
  end

  @doc """
  Handles clipboard copy operation.
  """
  def handle_copy(handler) do
    ClipboardHandler.handle_copy(handler)
  end

  @doc """
  Handles clipboard cut operation.
  """
  def handle_cut(handler) do
    ClipboardHandler.handle_cut(handler)
  end

  @doc """
  Processes a raw input string for the terminal.
  """
  def process_terminal_input(emulator, input) do
    CoreHandler.process_terminal_input(emulator, input)
  end

  @doc """
  Processes a single character codepoint.
  """
  def process_character(emulator, char_codepoint) do
    CharacterProcessor.process_character(emulator, char_codepoint)
  end

  @doc """
  Handles a CSI sequence.
  """
  def handle_csi_sequence(emulator, command, params) do
    ControlSequenceHandler.handle_csi_sequence(emulator, command, params)
  end

  @doc """
  Handles an OSC sequence.
  """
  def handle_osc_sequence(emulator, command, data) do
    ControlSequenceHandler.handle_osc_sequence(emulator, command, data)
  end

  @doc """
  Handles a DCS sequence.
  """
  def handle_dcs_sequence(emulator, command, data) do
    ControlSequenceHandler.handle_dcs_sequence(emulator, command, data)
  end

  @doc """
  Handles a PM sequence.
  """
  def handle_pm_sequence(emulator, command, data) do
    ControlSequenceHandler.handle_pm_sequence(emulator, command, data)
  end

  @doc """
  Handles an APC sequence.
  """
  def handle_apc_sequence(emulator, command, data) do
    ControlSequenceHandler.handle_apc_sequence(emulator, command, data)
  end
end
