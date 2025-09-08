defmodule Raxol.Terminal.Commands.CSIHandler do
  @moduledoc """
  Handlers for CSI (Control Sequence Introducer) commands.
  This is a simplified version that delegates to the available handler modules.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.WindowHandler

  alias Raxol.Terminal.Commands.CSIHandler.{
    CursorMovement,
    ScreenHandler,
    DeviceHandler,
    TextHandler,
    ModeHandler,
    CharsetHandler,
    Cursor
  }

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

  # Window handler delegations
  defdelegate handle_window_maximize(emulator), to: WindowHandler
  defdelegate handle_window_unmaximize(emulator), to: WindowHandler
  defdelegate handle_window_minimize(emulator), to: WindowHandler
  defdelegate handle_window_unminimize(emulator), to: WindowHandler
  defdelegate handle_window_iconify(emulator), to: WindowHandler
  defdelegate handle_window_deiconify(emulator), to: WindowHandler
  defdelegate handle_window_raise(emulator), to: WindowHandler
  defdelegate handle_window_lower(emulator), to: WindowHandler
  defdelegate handle_window_fullscreen(emulator), to: WindowHandler
  defdelegate handle_window_unfullscreen(emulator), to: WindowHandler
  defdelegate handle_window_title(emulator), to: WindowHandler
  defdelegate handle_window_icon_name(emulator), to: WindowHandler
  defdelegate handle_window_icon_title(emulator), to: WindowHandler
  defdelegate handle_window_icon_title_name(emulator), to: WindowHandler
  defdelegate handle_window_save_title(emulator), to: WindowHandler
  defdelegate handle_window_restore_title(emulator), to: WindowHandler
  defdelegate handle_window_size_report(emulator), to: WindowHandler
  defdelegate handle_window_size_pixels(emulator), to: WindowHandler

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
