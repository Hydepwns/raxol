defmodule Raxol.Terminal.Commands.CSIHandler.CommandDelegator do
  @moduledoc """
  Delegates basic CSI commands to appropriate handler modules.
  """

  alias Raxol.Terminal.Commands.CSIHandler.{Basic, Cursor, Screen, Device}

  def handle_basic_command(emulator, params, byte) do
    Basic.handle_command(emulator, params, byte)
  end

  def handle_cursor_command(emulator, params, byte) do
    Cursor.handle_command(emulator, params, byte)
  end

  def handle_screen_command(emulator, params, byte) do
    Screen.handle_command(emulator, params, byte)
  end

  def handle_device_command(emulator, params, intermediates_buffer, byte) do
    Device.handle_command(emulator, params, intermediates_buffer, byte)
  end

  def handle_deccusr(emulator, params) do
    Basic.handle_decscusr(emulator, params)
  end

  @doc """
  Handles DECCUSR (DEC Cursor Style Report) command.
  This is an alias for handle_deccusr/2 for backward compatibility.
  """
  def handle_q_deccusr(emulator, params) do
    handle_deccusr(emulator, params)
  end
end
