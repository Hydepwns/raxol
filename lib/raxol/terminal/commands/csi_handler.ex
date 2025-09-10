defmodule Raxol.Terminal.Commands.CSIHandler do
  @moduledoc """
  Handlers for CSI (Control Sequence Introducer) commands.
  This is a simplified version that delegates to the available handler modules.
  """

  alias Raxol.Terminal.Commands.WindowHandler
  alias Raxol.Terminal.Commands.CSIHandler.{CursorMovement, Cursor}
  alias Raxol.Terminal.ModeManager

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

  defp handle_other_csi(emulator, command, params) do
    case command do
      ?J ->
        # ED - Erase Display
        mode =
          case params do
            [] -> 0
            [p] when is_integer(p) -> p
            _ -> 0
          end

        handle_erase_display(emulator, mode)

      ?K ->
        # EL - Erase Line
        mode =
          case params do
            [] -> 0
            [p] when is_integer(p) -> p
            _ -> 0
          end

        handle_erase_line(emulator, mode)

      ?m ->
        # SGR - Select Graphic Rendition (text formatting/colors)
        handle_sgr(emulator, params)

      _ ->
        # For other unknown sequences, return emulator unchanged
        emulator
    end
  end

  defp handle_erase_line(emulator, mode) do
    alias Raxol.Terminal.Commands.CSIHandler.ScreenHandlers
    ScreenHandlers.handle_erase_line(emulator, mode)
  end

  defp handle_sgr(emulator, params) do
    alias Raxol.Terminal.ANSI.SGRProcessor

    # Convert params list to string format expected by SGRProcessor
    params_string =
      params
      |> Enum.map(&Integer.to_string/1)
      |> Enum.join(";")

    # Apply SGR formatting to the emulator's current style
    updated_style = SGRProcessor.handle_sgr(params_string, emulator.style)

    # Return emulator with updated style
    %{emulator | style: updated_style}
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

  def handle_screen_command(emulator, params, final_byte) do
    # Delegate to Screen module for screen commands
    alias Raxol.Terminal.Commands.CSIHandler.Screen

    case Screen.handle_command(emulator, params, final_byte) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, updated_emulator} -> updated_emulator
      updated_emulator -> updated_emulator
    end
  end

  def handle_device_command(emulator, params, intermediates, final_byte) do
    # Delegate to DeviceHandler for device commands
    alias Raxol.Terminal.Commands.DeviceHandler

    case final_byte do
      ?c ->
        # Device Attributes (DA)
        {:ok, updated_emulator} =
          DeviceHandler.handle_c(emulator, params, intermediates)

        updated_emulator

      ?n ->
        # Device Status Report (DSR)
        case DeviceHandler.handle_n(emulator, params) do
          {:ok, updated_emulator} -> updated_emulator
          {:error, _, updated_emulator} -> updated_emulator
        end

      _ ->
        # Other device commands not yet implemented
        emulator
    end
  end

  def handle_h_or_l(emulator, params, intermediates, final_byte) do
    # Handle Set Mode (SM - 'h') and Reset Mode (RM - 'l')
    # ?h = 'h', ?l = 'l'
    is_set = final_byte == ?h
    is_private = intermediates == "?"

    # Process each mode parameter
    result =
      Enum.reduce(params, emulator, fn param, acc ->
        mode_value =
          if is_integer(param), do: param, else: String.to_integer(param)

        if is_private do
          # Private DEC modes (with '?' prefix)
          handle_private_mode(acc, mode_value, is_set)
        else
          # Standard ANSI modes
          handle_standard_mode(acc, mode_value, is_set)
        end
      end)

    result
  end

  defp handle_private_mode(emulator, mode, is_set) do
    mode_name =
      case mode do
        # Cursor keys mode
        1 -> :decckm
        # 132 column mode
        3 -> :deccolm_132
        # Screen mode
        5 -> :decscnm
        # Origin mode
        6 -> :decom
        # Auto wrap mode
        7 -> :decawm
        # Auto repeat mode
        8 -> :decarm
        # Interlace mode
        9 -> :decinlm
        # Send/receive mode
        12 -> :decsrm
        # Text cursor enable mode
        25 -> :dectcem
        # Alternate screen buffer
        47 -> :dec_alt_screen
        1000 -> :mouse_report_x10
        1002 -> :mouse_report_cell_motion
        1003 -> :mouse_any_event
        1004 -> :focus_events
        # Alternate screen buffer (no clear)
        1047 -> :dec_alt_screen_save
        # Save/restore cursor
        1048 -> :decsc_deccara
        # Alternate screen buffer (with save cursor)
        1049 -> :alt_screen_buffer
        2004 -> :bracketed_paste_mode
        _ -> nil
      end

    if mode_name do
      # Determine the correct category for the mode
      category =
        case mode do
          47 -> :screen_buffer
          1047 -> :screen_buffer
          1048 -> :screen_buffer
          1049 -> :screen_buffer
          _ -> :dec_private
        end

      # Call ModeManager with the emulator and a list of modes
      updated_emulator =
        if is_set do
          case ModeManager.set_mode(emulator, [mode_name], category) do
            {:ok, emu} -> emu
            _ -> emulator
          end
        else
          case ModeManager.reset_mode(emulator, [mode_name], category) do
            {:ok, emu} -> emu
            _ -> emulator
          end
        end

      # Handle special cases for screen buffer switching
      case {mode_name, is_set} do
        {:dec_alt_screen, true} ->
          %{updated_emulator | active_buffer_type: :alternate}

        {:dec_alt_screen, false} ->
          %{updated_emulator | active_buffer_type: :main}

        {:dec_alt_screen_save, true} ->
          %{updated_emulator | active_buffer_type: :alternate}

        {:dec_alt_screen_save, false} ->
          %{updated_emulator | active_buffer_type: :main}

        {:alt_screen_buffer, true} ->
          # Save cursor and switch to alternate buffer
          emulator = save_cursor_position(updated_emulator)
          %{emulator | active_buffer_type: :alternate}

        {:alt_screen_buffer, false} ->
          # Switch to main buffer and restore cursor
          emulator = %{updated_emulator | active_buffer_type: :main}
          restore_cursor_position(emulator)

        _ ->
          updated_emulator
      end
    else
      emulator
    end
  end

  defp handle_standard_mode(emulator, mode, is_set) do
    mode_name =
      case mode do
        # Insert/Replace mode
        4 -> :irm
        # Send/Receive mode
        12 -> :srm
        # Line feed/new line mode
        20 -> :lnm
        _ -> nil
      end

    if mode_name do
      # Call ModeManager with the emulator and a list of modes
      if is_set do
        case ModeManager.set_mode(emulator, [mode_name], :standard) do
          {:ok, emu} -> emu
          _ -> emulator
        end
      else
        case ModeManager.reset_mode(emulator, [mode_name], :standard) do
          {:ok, emu} -> emu
          _ -> emulator
        end
      end
    else
      emulator
    end
  end

  defp save_cursor_position(emulator) do
    # Save cursor position for later restoration
    cursor = emulator.cursor
    updated_cursor = %{cursor | saved_row: cursor.row, saved_col: cursor.col}
    %{emulator | cursor: updated_cursor}
  end

  defp restore_cursor_position(emulator) do
    # Restore previously saved cursor position
    cursor = emulator.cursor

    if cursor.saved_row != nil && cursor.saved_col != nil do
      updated_cursor = %{
        cursor
        | row: cursor.saved_row,
          col: cursor.saved_col
      }

      %{emulator | cursor: updated_cursor}
    else
      emulator
    end
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

  # Compatibility functions for tests
  # These map old test function names to the actual implementations

  # Note: handle_cursor_position is already delegated above

  def handle_text_attributes(emulator, attrs) do
    # Map to actual text attribute handling
    style = Map.get(emulator, :style, %{})
    updated_style = apply_text_attributes(style, attrs)
    {:ok, %{emulator | style: updated_style}}
  end

  defp apply_text_attributes(style, attrs) do
    Enum.reduce(attrs, style, fn
      1, s -> Map.put(s, :bold, true)
      4, s -> Map.put(s, :underline, true)
      _, s -> s
    end)
  end

  def handle_mode_change(emulator, mode, enabled) do
    # Map to actual mode handling
    mode_state = Map.get(emulator, :mode_state, %{})
    updated_mode_state = Map.put(mode_state, mode, enabled)
    {:ok, %{emulator | mode_state: updated_mode_state}}
  end

  def handle_scroll_up(emulator, _lines) do
    # Map to actual scroll handling
    # Simplified for now
    {:ok, emulator}
  end

  def handle_scroll_down(emulator, _lines) do
    # Map to actual scroll handling  
    # Simplified for now
    {:ok, emulator}
  end

  def handle_erase_display(emulator, mode) do
    alias Raxol.Terminal.Commands.CSIHandler.ScreenHandlers
    ScreenHandlers.handle_erase_display(emulator, mode)
  end
end
