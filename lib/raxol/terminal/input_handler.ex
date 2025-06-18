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
  @spec new() :: CoreHandler.t()
  def new do
    CoreHandler.new()
  end

  @doc """
  Handles clipboard paste operation.
  """
  @spec handle_paste(CoreHandler.t()) ::
          {:ok, CoreHandler.t()} | {:error, any()}
  def handle_paste(handler) do
    ClipboardHandler.handle_paste(handler)
  end

  @doc """
  Handles clipboard copy operation.
  """
  @spec handle_copy(CoreHandler.t()) :: {:ok, CoreHandler.t()} | {:error, any()}
  def handle_copy(handler) do
    ClipboardHandler.handle_copy(handler)
  end

  @doc """
  Handles clipboard cut operation.
  """
  @spec handle_cut(CoreHandler.t()) :: {:ok, CoreHandler.t()} | {:error, any()}
  def handle_cut(handler) do
    ClipboardHandler.handle_cut(handler)
  end

  @doc """
  Processes a raw input string for the terminal.
  """
  @spec process_terminal_input(Emulator.t(), String.t()) ::
          {Emulator.t(), String.t()}
  def process_terminal_input(emulator, input) do
    CoreHandler.process_terminal_input(emulator, input)
  end

  @doc """
  Processes a single character codepoint.
  """
  @spec process_character(Emulator.t(), integer()) :: Emulator.t()
  def process_character(emulator, char_codepoint) do
    CharacterProcessor.process_character(emulator, char_codepoint)
  end

  @doc """
  Handles a CSI sequence.
  """
  @spec handle_csi_sequence(Emulator.t(), String.t(), list(String.t())) ::
          Emulator.t()
  def handle_csi_sequence(emulator, command, params) do
    ControlSequenceHandler.handle_csi_sequence(emulator, command, params)
  end

  @doc """
  Handles an OSC sequence.
  """
  @spec handle_osc_sequence(Emulator.t(), String.t(), String.t()) ::
          Emulator.t()
  def handle_osc_sequence(emulator, command, data) do
    ControlSequenceHandler.handle_osc_sequence(emulator, command, data)
  end

  @doc """
  Handles a DCS sequence.
  """
  @spec handle_dcs_sequence(Emulator.t(), String.t(), String.t()) ::
          Emulator.t()
  def handle_dcs_sequence(emulator, command, data) do
    ControlSequenceHandler.handle_dcs_sequence(emulator, command, data)
  end

  @doc """
  Handles a PM sequence.
  """
  @spec handle_pm_sequence(Emulator.t(), String.t(), String.t()) :: Emulator.t()
  def handle_pm_sequence(emulator, command, data) do
    ControlSequenceHandler.handle_pm_sequence(emulator, command, data)
  end

  @doc """
  Handles an APC sequence.
  """
  @spec handle_apc_sequence(Emulator.t(), String.t(), String.t()) ::
          Emulator.t()
  def handle_apc_sequence(emulator, command, data) do
    ControlSequenceHandler.handle_apc_sequence(emulator, command, data)
  end
end
