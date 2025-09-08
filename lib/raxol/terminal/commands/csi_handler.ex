defmodule Raxol.Terminal.Commands.CSIHandler do
  @moduledoc """
  Handlers for CSI (Control Sequence Introducer) commands.
  This is a simplified version that delegates to the available handler modules.
  """

  alias Raxol.Terminal.Commands.WindowHandler
  alias Raxol.Terminal.Commands.CSIHandler.{CursorMovement, Cursor}

  require Raxol.Core.Runtime.Log
  require Logger

  # Cursor movement delegations
  defdelegate handle_cursor_up(emulator, amount), to: CursorMovement
  defdelegate handle_cursor_down(emulator, amount), to: CursorMovement
  defdelegate handle_cursor_forward(emulator, amount), to: CursorMovement
  defdelegate handle_cursor_backward(emulator, amount), to: CursorMovement

  defdelegate handle_cursor_position_direct(emulator, row, col),
    to: CursorMovement

  defdelegate handle_cursor_position(emulator, row, col), to: CursorMovement
  defdelegate handle_cursor_position(emulator, params), to: CursorMovement
  defdelegate handle_cursor_column(emulator, column), to: CursorMovement

  @doc """
  Handles cursor movement based on the command byte.
  """
  def handle_cursor_movement(emulator, [command_byte]) do
    case command_byte do
      ?A -> handle_cursor_up(emulator, 1)
      ?B -> handle_cursor_down(emulator, 1)
      ?C -> handle_cursor_forward(emulator, 1)
      ?D -> handle_cursor_backward(emulator, 1)
      _ -> emulator
    end
  end

  # Main CSI handler
  def handle_csi_sequence(emulator, command, params) do
    # Delegate to cursor handler for cursor commands
    case Cursor.handle_command(emulator, params, command) do
      {:error, :unknown_cursor_command, _} ->
        # Try other handlers
        handle_other_csi(emulator, command, params)

      result ->
        result
    end
  end

  defp handle_other_csi(emulator, _command, _params) do
    # For now, just return emulator unchanged for unknown sequences
    emulator
  end

  # Window handler delegations - only delegate functions that exist
  defdelegate handle_iconify(emulator), to: WindowHandler
  defdelegate handle_deiconify(emulator), to: WindowHandler
  defdelegate handle_raise(emulator), to: WindowHandler
  defdelegate handle_lower(emulator), to: WindowHandler
  defdelegate handle_window_title(emulator, params), to: WindowHandler
  defdelegate handle_icon_name(emulator, params), to: WindowHandler
  defdelegate handle_icon_title(emulator, params), to: WindowHandler

  # Handler functions for Executor compatibility
  def handle_basic_command(emulator, params, final_byte) do
    handle_csi_sequence(emulator, final_byte, params)
  end

  def handle_cursor_command(emulator, params, final_byte) do
    case Cursor.handle_command(emulator, params, final_byte) do
      {:error, :unknown_cursor_command, _} -> emulator
      {:ok, updated_emulator} -> updated_emulator
      updated_emulator -> updated_emulator
    end
  end

  def handle_screen_command(emulator, _params, _final_byte) do
    # Screen commands not yet implemented
    emulator
  end

  def handle_device_command(emulator, _params, _intermediates, _final_byte) do
    # Device commands not yet implemented
    emulator
  end

  def handle_h_or_l(emulator, _params, _intermediates, _final_byte) do
    # Mode commands not yet implemented
    emulator
  end

  def handle_scs(emulator, _params_buffer, _final_byte) do
    # SCS commands not yet implemented
    emulator
  end

  def handle_q_deccusr(emulator, _params) do
    # DECCUSR command not yet implemented
    emulator
  end

  # Bracketed paste handling
  def handle_bracketed_paste_start(emulator) do
    case emulator.mode_manager.bracketed_paste_mode do
      true ->
        %{emulator | bracketed_paste_active: true, bracketed_paste_buffer: ""}

      false ->
        emulator
    end
  end

  def handle_bracketed_paste_end(emulator) do
    case emulator.bracketed_paste_active do
      true ->
        # Process the accumulated paste buffer
        %{emulator | bracketed_paste_active: false, bracketed_paste_buffer: ""}

      false ->
        emulator
    end
  end
end
