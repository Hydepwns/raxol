defmodule Raxol.Terminal.Commands.CSIHandler.ModeHandlers do
  @moduledoc """
  Handles CSI mode commands (Set Mode/Reset Mode).
  """

  alias Raxol.Terminal.Emulator

  @doc """
  Handles Set Mode (SM - 'h') and Reset Mode (RM - 'l') commands.
  """
  @spec handle_h_or_l(Emulator.t(), list(), String.t(), integer()) :: {:ok, Emulator.t()}
  def handle_h_or_l(emulator, params, intermediates, final_byte) do
    # Handle Set Mode (SM - 'h') and Reset Mode (RM - 'l')
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

    {:ok, result}
  end

  defp handle_private_mode(emulator, mode, is_set) do
    mode_name =
      case mode do
        # Cursor keys mode
        1 -> :cursor_keys_mode
        # 132 column mode
        3 -> :column_width_mode
        # Screen mode
        5 -> :screen_mode_reverse
        # Origin mode
        6 -> :origin_mode
        # Auto wrap mode
        7 -> :auto_wrap
        # Auto repeat mode
        8 -> :auto_repeat_mode
        # Interlace mode
        9 -> :interlacing_mode
        # Send/receive mode
        12 -> :send_receive_mode
        # Text cursor enable mode
        25 -> :cursor_visible
        # Alternate screen buffer
        47 -> :alternate_buffer_active
        1000 -> :mouse_report_mode
        1002 -> :mouse_report_mode
        1003 -> :mouse_report_mode
        1004 -> :focus_events_enabled
        1005 -> :mouse_report_mode
        1006 -> :mouse_report_mode
        1047 -> :alternate_buffer_active
        1048 -> :save_cursor_mode
        1049 -> :save_cursor_and_alt_screen_mode
        2004 -> :bracketed_paste_mode
        _ -> :unknown_private_mode
      end

    if mode_name != :unknown_private_mode do
      # Create or update mode manager
      mode_manager = emulator.mode_manager || %Raxol.Terminal.ModeManager{}

      updated_mode_manager =
        case mode_name do
          :cursor_keys_mode ->
            Map.put(mode_manager, mode_name, if(is_set, do: :application, else: :normal))
          :column_width_mode ->
            Map.put(mode_manager, mode_name, if(is_set, do: :wide, else: :normal))
          :mouse_report_mode ->
            # Set based on specific mode number
            mouse_mode = case mode do
              1000 -> :x10
              1002 -> :cell_motion
              1003 -> :any_event
              _ -> :none
            end
            Map.put(mode_manager, mode_name, if(is_set, do: mouse_mode, else: :none))
          # For fields that don't exist in the struct, skip them
          field when field in [:send_receive_mode, :save_cursor_mode, :save_cursor_and_alt_screen_mode] ->
            mode_manager
          _ ->
            Map.put(mode_manager, mode_name, is_set)
        end

      # Handle special cases that require additional changes
      updated_emulator = %{emulator | mode_manager: updated_mode_manager}

      case {mode_name, is_set} do
        {:column_width_mode, true} ->
          resize_screen_buffers(updated_emulator, 132)
        {:column_width_mode, false} ->
          resize_screen_buffers(updated_emulator, 80)
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
        2 -> :keyboard_action
        4 -> :insert_mode
        12 -> :send_receive
        20 -> :line_feed_mode
        _ -> :unknown_standard_mode
      end

    if mode_name != :unknown_standard_mode do
      # Create or update mode manager
      mode_manager = emulator.mode_manager || %Raxol.Terminal.ModeManager{}
      updated_mode_manager = Map.put(mode_manager, mode_name, is_set)
      %{emulator | mode_manager: updated_mode_manager}
    else
      emulator
    end
  end

  defp resize_screen_buffers(emulator, new_width) do
    height = Raxol.Terminal.ScreenBuffer.get_height(emulator.main_screen_buffer)

    main_buffer = Raxol.Terminal.ScreenBuffer.resize(
      emulator.main_screen_buffer,
      new_width,
      height
    )

    alternate_buffer =
      case emulator.alternate_screen_buffer do
        nil -> nil
        buffer -> Raxol.Terminal.ScreenBuffer.resize(buffer, new_width, height)
      end

    %{emulator |
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,
      width: new_width
    }
  end
end