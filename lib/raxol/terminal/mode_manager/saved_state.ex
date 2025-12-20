defmodule Raxol.Terminal.ModeManager.SavedState do
  @moduledoc """
  Handles saved state operations for the mode manager.
  This includes saving and restoring cursor positions, screen states, and other terminal modes.
  """

  alias Raxol.Terminal.ANSI.TerminalState
  alias Raxol.Terminal.{Cursor, ScreenBuffer}

  @doc """
  Saves the current terminal state.
  This includes:
  - Cursor position and attributes
  - Screen state (main/alternate)
  - Current modes
  """
  def save_state(emulator) do
    # Save cursor state
    cursor_state = %{
      position: Cursor.get_position(emulator.cursor),
      visible: Cursor.visible?(emulator.cursor),
      style: Cursor.get_style(emulator.cursor),
      blink:
        Raxol.Terminal.Operations.CursorOperations.cursor_blinking?(emulator)
    }

    # Save screen state
    screen_state = %{
      buffer_type: emulator.active_buffer_type,
      scroll_region: ScreenBuffer.get_scroll_region(emulator.active_buffer),
      cursor_style: emulator.cursor_style
    }

    # Save current modes
    mode_state = %{
      cursor_visible: emulator.mode_manager.cursor_visible,
      auto_wrap: emulator.mode_manager.auto_wrap,
      origin_mode: emulator.mode_manager.origin_mode,
      insert_mode: emulator.mode_manager.insert_mode,
      line_feed_mode: emulator.mode_manager.line_feed_mode,
      column_width_mode: emulator.mode_manager.column_width_mode,
      cursor_keys_mode: emulator.mode_manager.cursor_keys_mode,
      screen_mode_reverse: emulator.mode_manager.screen_mode_reverse,
      auto_repeat_mode: emulator.mode_manager.auto_repeat_mode,
      interlacing_mode: emulator.mode_manager.interlacing_mode,
      alternate_buffer_active: emulator.mode_manager.alternate_buffer_active,
      mouse_report_mode: emulator.mode_manager.mouse_report_mode,
      focus_events_enabled: emulator.mode_manager.focus_events_enabled,
      alt_screen_mode: emulator.mode_manager.alt_screen_mode,
      bracketed_paste_mode: emulator.mode_manager.bracketed_paste_mode,
      active_buffer_type: emulator.mode_manager.active_buffer_type
    }

    # Combine all states
    saved_state = %{
      cursor: cursor_state,
      screen: screen_state,
      modes: mode_state
    }

    # Update terminal state
    new_terminal_state = TerminalState.save(emulator.terminal_state)

    new_terminal_state =
      TerminalState.update_current_state(new_terminal_state, saved_state)

    %{emulator | terminal_state: new_terminal_state}
  end

  @doc """
  Restores the previously saved terminal state.
  """
  def restore_state(emulator) do
    case TerminalState.restore(emulator.terminal_state) do
      %{current_state: nil} ->
        # No saved state to restore
        emulator

      %{current_state: saved_state} = new_terminal_state ->
        # Restore cursor state
        emulator = restore_cursor_state(emulator, saved_state.cursor)

        # Restore screen state
        emulator = restore_screen_state(emulator, saved_state.screen)

        # Restore mode state
        emulator = restore_mode_state(emulator, saved_state.modes)

        # Update terminal state
        %{emulator | terminal_state: new_terminal_state}
    end
  end

  # Private Functions

  defp restore_cursor_state(emulator, cursor_state) do
    emulator
    |> Cursor.set_position(cursor_state.position)
    |> Cursor.set_visibility(cursor_state.visible)
    |> Cursor.set_style(cursor_state.style)
    |> Cursor.set_blink(cursor_state.blink)
  end

  defp restore_screen_state(emulator, screen_state) do
    emulator
    |> ScreenBuffer.set_scroll_region(screen_state.scroll_region)
    |> Map.put(:active_buffer_type, screen_state.buffer_type)
    |> Map.put(:cursor_style, screen_state.cursor_style)
  end

  defp restore_mode_state(emulator, mode_state) do
    %Raxol.Terminal.ModeManager{} =
      mode_manager =
      case emulator.mode_manager do
        %Raxol.Terminal.ModeManager{} = mm -> mm
        mm when is_map(mm) -> struct(Raxol.Terminal.ModeManager, mm)
        _ -> Raxol.Terminal.ModeManager.new()
      end

    updated_mode_manager = %{
      mode_manager
      | cursor_visible: mode_state.cursor_visible,
        auto_wrap: mode_state.auto_wrap,
        origin_mode: mode_state.origin_mode,
        insert_mode: mode_state.insert_mode,
        line_feed_mode: mode_state.line_feed_mode,
        column_width_mode: mode_state.column_width_mode,
        cursor_keys_mode: mode_state.cursor_keys_mode,
        screen_mode_reverse: mode_state.screen_mode_reverse,
        auto_repeat_mode: mode_state.auto_repeat_mode,
        interlacing_mode: mode_state.interlacing_mode,
        alternate_buffer_active: mode_state.alternate_buffer_active,
        mouse_report_mode: mode_state.mouse_report_mode,
        focus_events_enabled: mode_state.focus_events_enabled,
        alt_screen_mode: mode_state.alt_screen_mode,
        bracketed_paste_mode: mode_state.bracketed_paste_mode,
        active_buffer_type: mode_state.active_buffer_type
    }

    %{emulator | mode_manager: updated_mode_manager}
  end
end
