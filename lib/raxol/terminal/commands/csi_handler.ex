defmodule Raxol.Terminal.Commands.CSIHandler do
  @moduledoc """
  Handlers for CSI (Control Sequence Introducer) commands.
  This is a simplified version that delegates to the available handler modules.
  """

  alias Raxol.Terminal.Commands.WindowHandler
  alias Raxol.Terminal.Commands.CSIHandler.{CursorMovementHandler, Cursor}
  alias Raxol.Terminal.ModeManager

  require Raxol.Core.Runtime.Log
  require Logger

  # Cursor movement delegations
  defdelegate handle_cursor_up(emulator, amount), to: CursorMovementHandler
  defdelegate handle_cursor_down(emulator, amount), to: CursorMovementHandler
  defdelegate handle_cursor_forward(emulator, amount), to: CursorMovementHandler

  defdelegate handle_cursor_backward(emulator, amount),
    to: CursorMovementHandler

  defdelegate handle_cursor_position_direct(emulator, row, col),
    to: CursorMovementHandler

  defdelegate handle_cursor_position(emulator, row, col),
    to: CursorMovementHandler

  defdelegate handle_cursor_position(emulator, params),
    to: CursorMovementHandler

  defdelegate handle_cursor_column(emulator, column), to: CursorMovementHandler

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
    # Convert command to string if it's an integer (character code)
    command_str =
      case command do
        cmd when is_integer(cmd) -> <<cmd::utf8>>
        cmd when is_binary(cmd) -> cmd
        _ -> ""
      end

    # Delegate to cursor handler for cursor commands
    case Cursor.handle_command(emulator, params, command_str) do
      {:error, :unknown_cursor_command} ->
        # Try other handlers
        handle_other_csi(emulator, command, params)

      {:ok, updated_emulator} ->
        updated_emulator
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

      ?s ->
        # Save cursor position
        save_cursor_position(emulator)

      ?u ->
        # Restore cursor position
        restore_cursor_position(emulator)

      _ ->
        # For other unknown sequences, return emulator unchanged
        emulator
    end
  end

  def handle_erase_line(emulator, mode) do
    alias Raxol.Terminal.Commands.CSIHandler.ScreenHandlers
    ScreenHandlers.handle_erase_line(emulator, mode)
  end

  defp handle_sgr(emulator, params) do
    alias Raxol.Terminal.ANSI.SGRProcessor

    # Convert params list to string format expected by SGRProcessor
    params_string =
      params
      |> Enum.map_join(";", &Integer.to_string/1)

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
      {:error, :unknown_cursor_command} -> emulator
      {:ok, updated_emulator} -> updated_emulator
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

  defp save_cursor_position(emulator) do
    cursor = emulator.cursor

    # Save position in cursor fields
    updated_cursor = %{
      cursor
      | saved_row: cursor.row,
        saved_col: cursor.col,
        saved_position: {cursor.row, cursor.col}
    }

    # Also save in emulator.saved_cursor for consistency with handle_s/handle_u
    saved_cursor = %{
      position: {cursor.row, cursor.col},
      row: cursor.row,
      col: cursor.col,
      shape: Map.get(cursor, :shape),
      visible: Map.get(cursor, :visible, true)
    }

    %{emulator | cursor: updated_cursor, saved_cursor: saved_cursor}
  end

  defp restore_cursor_position(emulator) do
    # Try to restore from emulator.saved_cursor first (newer style)
    case Map.get(emulator, :saved_cursor) do
      nil ->
        # Fall back to cursor saved fields
        cursor = emulator.cursor

        {new_row, new_col} =
          case {cursor.saved_row, cursor.saved_col} do
            # Don't move if nothing saved
            {nil, nil} -> {cursor.row, cursor.col}
            {row, col} -> {row, col}
          end

        updated_cursor = %{
          cursor
          | row: new_row,
            col: new_col,
            position: {new_row, new_col}
        }

        %{emulator | cursor: updated_cursor}

      saved_cursor ->
        # Restore from saved_cursor structure
        {row, col} = saved_cursor.position

        updated_cursor = %{
          emulator.cursor
          | row: row,
            col: col,
            position: {row, col},
            shape: Map.get(saved_cursor, :shape, emulator.cursor.shape),
            visible: Map.get(saved_cursor, :visible, emulator.cursor.visible)
        }

        %{emulator | cursor: updated_cursor}
    end
  end

  def handle_device_command(emulator, params, _intermediates, final_byte) do
    # Delegate to UnifiedCommandHandler for device commands
    alias Raxol.Terminal.Commands.UnifiedCommandHandler

    case final_byte do
      ?c ->
        # Device Attributes (DA)
        {:ok, updated_emulator} =
          UnifiedCommandHandler.handle_csi(emulator, params, "c")

        updated_emulator

      ?n ->
        # Device Status Report (DSR)
        case UnifiedCommandHandler.handle_csi(emulator, params, "n") do
          {:ok, updated_emulator} -> updated_emulator
          {:error, _, updated_emulator} -> updated_emulator
        end

      ?s ->
        # Save Cursor Position (SCP)
        save_cursor_position(emulator)

      ?u ->
        # Restore Cursor Position (RCP)
        restore_cursor_position(emulator)

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

  def handle_scs(emulator, _params_buffer, _final_byte) do
    # SCS commands not yet implemented
    emulator
  end

  def handle_q_deccusr(emulator, params) do
    # DECCUSR - Set cursor style
    style =
      case params do
        # Default
        [0] -> :blink_block
        [1] -> :blink_block
        [2] -> :steady_block
        [3] -> :blink_underline
        [4] -> :steady_underline
        [5] -> :blink_bar
        [6] -> :steady_bar
        # Keep current style for invalid params
        _ -> emulator.cursor.style
      end

    updated_cursor = %{emulator.cursor | style: style}
    %{emulator | cursor: updated_cursor}
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

  # Missing functions that tests expect

  def handle_s(emulator, _params) do
    # Save cursor position - delegate to save_cursor_position for consistency
    updated_emulator = save_cursor_position(emulator)
    {:ok, updated_emulator}
  end

  def handle_u(emulator, _params) do
    # Restore cursor position - delegate to restore_cursor_position for consistency
    updated_emulator = restore_cursor_position(emulator)
    {:ok, updated_emulator}
  end

  def handle_r(emulator, params) do
    # Set scrolling region (DECSTBM)
    {top, bottom, scroll_region} =
      case params do
        [] ->
          # Reset scroll region
          {1, emulator.height, nil}

        [nil, bottom] ->
          # Bottom only (top defaults to 1)
          clamped_bottom = max(1, min(bottom, emulator.height))
          {1, clamped_bottom, {0, clamped_bottom - 1}}

        [top] ->
          # Top only
          clamped_top = max(1, min(top, emulator.height))
          {clamped_top, emulator.height, {clamped_top - 1, emulator.height - 1}}

        [top, bottom] ->
          # Both parameters
          clamped_top = max(1, min(top, emulator.height))
          clamped_bottom = max(clamped_top, min(bottom, emulator.height))

          # Invalid region if top >= bottom
          if clamped_top >= clamped_bottom do
            {1, emulator.height, nil}
          else
            {clamped_top, clamped_bottom, {clamped_top - 1, clamped_bottom - 1}}
          end

        [top, bottom | _] ->
          # Same as [top, bottom]
          clamped_top = max(1, min(top, emulator.height))
          clamped_bottom = max(clamped_top, min(bottom, emulator.height))

          if clamped_top >= clamped_bottom do
            {1, emulator.height, nil}
          else
            {clamped_top, clamped_bottom, {clamped_top - 1, clamped_bottom - 1}}
          end
      end

    # Update cursor margins
    updated_cursor = %{
      emulator.cursor
      | top_margin: top - 1,
        bottom_margin: bottom - 1
    }

    # Move cursor to home position
    home_cursor =
      Raxol.Terminal.Cursor.Manager.set_position(updated_cursor, {0, 0})

    {:ok, %{emulator | cursor: home_cursor, scroll_region: scroll_region}}
  end

  def handle_sequence(emulator, params) do
    # Generic sequence handler - delegate to handle_csi_sequence
    case params do
      [?s] -> handle_s(emulator, [])
      [?u] -> handle_u(emulator, [])
      _ -> {:ok, emulator}
    end
  end

  def handle_save_restore_cursor(emulator, [command]) do
    case command do
      ?s -> handle_s(emulator, [])
      ?u -> handle_u(emulator, [])
      _ -> {:ok, emulator}
    end
  end

  def handle_screen_clear(emulator, params) do
    # Delegate to erase display
    mode =
      case params do
        [] -> 0
        [mode] -> mode
        [mode | _] -> mode
      end

    handle_erase_display(emulator, mode)
  end

  def handle_line_clear(emulator, params) do
    # Handle line clearing
    mode =
      case params do
        [] -> 0
        [mode] -> mode
        [mode | _] -> mode
      end

    handle_erase_line(emulator, mode)
  end

  def handle_device_status(emulator, params) do
    # Handle device status reports
    case params do
      [5] ->
        # Device status OK
        output = "\e[0n"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> output}}

      [6] ->
        # Cursor position report
        output = "\e[#{emulator.cursor.y + 1};#{emulator.cursor.x + 1}R"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> output}}

      _ ->
        {:ok, emulator}
    end
  end
end
