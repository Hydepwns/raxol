defmodule Raxol.Terminal.Commands.CSIHandlers do
  @moduledoc """
  Handlers for CSI (Control Sequence Introducer) commands.
  """

  alias Raxol.Terminal.Emulator

  alias Raxol.Terminal.Commands.CSIHandlers.{
    WindowHandlers,
    CursorMovement,
    CharsetHandlers,
    ModeHandlers,
    ScreenHandlers,
    DeviceHandlers,
    TextHandlers,
    HandlerFactory,
    SequenceDispatcher,
    CommandDelegator
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

  # Screen handler delegations
  defdelegate handle_erase_display(emulator, mode), to: ScreenHandlers
  defdelegate handle_erase_line(emulator, mode), to: ScreenHandlers
  defdelegate handle_screen_clear(emulator, params), to: ScreenHandlers
  defdelegate handle_line_clear(emulator, params), to: ScreenHandlers
  defdelegate handle_scroll_up(emulator, lines), to: ScreenHandlers
  defdelegate handle_scroll_down(emulator, lines), to: ScreenHandlers

  # Device handler delegations
  defdelegate handle_device_status(emulator, params), to: DeviceHandlers
  defdelegate handle_cursor_position_report(emulator), to: DeviceHandlers

  # Text handler delegations
  defdelegate handle_text_attributes(emulator, params), to: TextHandlers
  defdelegate handle_save_cursor(emulator, params), to: TextHandlers
  defdelegate handle_restore_cursor(emulator, params), to: TextHandlers
  defdelegate handle_save_restore_cursor(emulator, params), to: TextHandlers

  defdelegate csi_command_handlers(), to: HandlerFactory

  # Command delegations
  defdelegate handle_basic_command(emulator, params, byte), to: CommandDelegator

  defdelegate handle_cursor_command(emulator, params, byte),
    to: CommandDelegator

  defdelegate handle_screen_command(emulator, params, byte),
    to: CommandDelegator

  defdelegate handle_device_command(
                emulator,
                params,
                intermediates_buffer,
                byte
              ),
              to: CommandDelegator

  defdelegate handle_deccusr(emulator, params), to: CommandDelegator
  defdelegate handle_q_deccusr(emulator, params), to: CommandDelegator

  # Mode handler delegations
  defdelegate handle_h_or_l(emulator, params, intermediates_buffer, final_byte),
    to: ModeHandlers

  # Charset handler delegations
  defdelegate handle_scs(emulator, params_buffer, final_byte),
    to: CharsetHandlers

  defdelegate handle_locking_shift_g0(emulator), to: CharsetHandlers
  defdelegate handle_locking_shift_g1(emulator), to: CharsetHandlers
  defdelegate handle_single_shift_g2(emulator), to: CharsetHandlers
  defdelegate handle_single_shift_g3(emulator), to: CharsetHandlers

  # Mode handler delegations
  defdelegate handle_mode_change(emulator, mode, enabled), to: ModeHandlers

  # Screen handler delegations
  defdelegate handle_r(emulator, params), to: ScreenHandlers

  # Text handler delegations
  defdelegate handle_s(emulator, params), to: TextHandlers
  defdelegate handle_u(emulator, params), to: TextHandlers

  # Sequence handler delegation
  def handle_sequence(emulator, sequence) do
    case SequenceDispatcher.handle_sequence(emulator, sequence) do
      {:error, :unknown_sequence, _sequence} ->
        # Ignore unknown sequences and return emulator unchanged
        emulator

      result ->
        result
    end
  end

  # Window handler delegations
  defdelegate handle_window_maximize(emulator), to: WindowHandlers
  defdelegate handle_window_unmaximize(emulator), to: WindowHandlers
  defdelegate handle_window_minimize(emulator), to: WindowHandlers
  defdelegate handle_window_unminimize(emulator), to: WindowHandlers
  defdelegate handle_window_iconify(emulator), to: WindowHandlers
  defdelegate handle_window_deiconify(emulator), to: WindowHandlers
  defdelegate handle_window_raise(emulator), to: WindowHandlers
  defdelegate handle_window_lower(emulator), to: WindowHandlers
  defdelegate handle_window_fullscreen(emulator), to: WindowHandlers
  defdelegate handle_window_unfullscreen(emulator), to: WindowHandlers
  defdelegate handle_window_title(emulator), to: WindowHandlers
  defdelegate handle_window_icon_name(emulator), to: WindowHandlers
  defdelegate handle_window_icon_title(emulator), to: WindowHandlers
  defdelegate handle_window_icon_title_name(emulator), to: WindowHandlers
  defdelegate handle_window_save_title(emulator), to: WindowHandlers
  defdelegate handle_window_restore_title(emulator), to: WindowHandlers
  defdelegate handle_window_size_report(emulator), to: WindowHandlers
  defdelegate handle_window_size_pixels(emulator), to: WindowHandlers

  # Bracketed paste handling
  def handle_bracketed_paste_start(emulator) do
    if emulator.mode_manager.bracketed_paste_mode do
      %{emulator | bracketed_paste_active: true, bracketed_paste_buffer: ""}
    else
      emulator
    end
  end

  def handle_bracketed_paste_end(emulator) do
    if emulator.mode_manager.bracketed_paste_mode and
         emulator.bracketed_paste_active do
      # Process the accumulated paste buffer as a single paste event
      updated_emulator =
        process_paste_content(emulator, emulator.bracketed_paste_buffer)

      %{
        updated_emulator
        | bracketed_paste_active: false,
          bracketed_paste_buffer: ""
      }
    else
      %{emulator | bracketed_paste_active: false, bracketed_paste_buffer: ""}
    end
  end

  defp process_paste_content(emulator, content) when content != "" do
    # When bracketed paste is enabled, paste content should be processed
    # without interpretation as commands - just insert as literal text
    Raxol.Terminal.Input.TextProcessor.handle_text_input(content, emulator)
  end

  defp process_paste_content(emulator, _empty_content), do: emulator

  @doc """
  Handles a CSI sequence with command and parameters.
  """
  @spec handle_csi_sequence(Emulator.t(), atom(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_csi_sequence(emulator, command, params) do
    handlers = csi_command_handlers()

    case Map.get(handlers, command) do
      nil -> emulator
      handler -> handler.(emulator, params)
    end
  end
end
