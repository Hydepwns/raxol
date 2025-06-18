defmodule Raxol.Terminal.ModeManager.SavedState do
  @moduledoc """
  Handles saved state operations for the mode manager.
  This includes saving and restoring cursor positions, screen states, and other terminal modes.
  """

  alias Raxol.Terminal.{Emulator, Cursor, ScreenBuffer}
  alias Raxol.Terminal.ANSI.TerminalState

  @doc """
  Saves the current terminal state.
  This includes:
  - Cursor position and attributes
  - Screen state (main/alternate)
  - Current modes
  """
  @spec save_state(Emulator.t()) :: Emulator.t()
  def save_state(emulator) do
    # Save cursor state
    cursor_state = %{
      position: Cursor.get_position(emulator.cursor),
      visible: Cursor.is_visible?(emulator.cursor),
      style: Cursor.get_style(emulator.cursor),
      blink: Cursor.is_blinking?(emulator.cursor)
    }

    # Save screen state
    screen_state = %{
      buffer_type: emulator.active_buffer_type,
      scroll_region: ScreenBuffer.get_scroll_region(emulator.active_buffer),
      cursor_style: emulator.cursor_style
    }

    # Save current modes
    mode_state = %{
      modes: emulator.mode_manager.modes,
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
  @spec restore_state(Emulator.t()) :: Emulator.t()
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
    %{
      emulator
      | mode_manager: %{
          emulator.mode_manager
          | modes: mode_state.modes,
            active_buffer_type: mode_state.active_buffer_type
        }
    }
  end
end
