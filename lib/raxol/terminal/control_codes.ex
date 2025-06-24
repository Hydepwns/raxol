defmodule Raxol.Terminal.ControlCodes do
  import Raxol.Guards

  @moduledoc """
  Handles C0 control codes and simple ESC sequences.

  Extracted from Terminal.Emulator for better organization.
  Relies on Emulator state and ScreenBuffer for actions.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Movement
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ModeManager
  # Needed for RIS
  alias Raxol.Terminal.ANSI.TerminalState

  # C0 Constants
  @nul 0
  @bel 7
  @bs 8
  @ht 9
  @lf 10
  @vt 11
  @ff 12
  @cr 13
  @so 14
  @si 15
  @can 24
  @sub 26
  @esc 27
  @del 127

  @doc """
  Handles a C0 control code (0-31) or DEL (127).
  Delegates to specific handlers based on the codepoint.
  """
  @spec handle_c0(EmulatorStruct.t(), non_neg_integer()) :: EmulatorStruct.t()
  def handle_c0(emulator, char_codepoint) do
    handler = c0_handler_for(char_codepoint)
    handler.(emulator)
  end

  defp c0_handler_for(@nul),
    do: fn emulator ->
      Raxol.Core.Runtime.Log.debug("NUL received, ignoring")
      emulator
    end

  defp c0_handler_for(@bel), do: &handle_bel/1
  defp c0_handler_for(@bs), do: &handle_bs/1
  defp c0_handler_for(@ht), do: &handle_ht/1
  defp c0_handler_for(@lf), do: &handle_lf/1
  defp c0_handler_for(@vt), do: &handle_lf/1
  defp c0_handler_for(@ff), do: &handle_lf/1
  defp c0_handler_for(@cr), do: &handle_cr/1
  defp c0_handler_for(@so), do: &handle_so/1
  defp c0_handler_for(@si), do: &handle_si/1
  defp c0_handler_for(@can), do: &handle_can/1
  defp c0_handler_for(@sub), do: &handle_sub/1

  defp c0_handler_for(@esc),
    do: fn emulator ->
      Raxol.Core.Runtime.Log.debug(
        "ESC received unexpectedly in C0 handler, ignoring"
      )

      emulator
    end

  defp c0_handler_for(@del),
    do: fn emulator ->
      Raxol.Core.Runtime.Log.debug("DEL received, ignoring")
      emulator
    end

  defp c0_handler_for(_),
    do: fn emulator ->
      Raxol.Core.Runtime.Log.debug("Unhandled C0 control code")
      emulator
    end

  @doc """
  Handles bell control code.
  """
  def handle_bel(emulator) do
    System.cmd("tput", ["bel"])
    emulator
  end

  @doc "Handle Backspace (BS)"
  def handle_bs(%EmulatorStruct{} = emulator) do
    # Move cursor left by one, respecting margins
    # Use alias
    new_cursor = Movement.move_left(emulator.cursor, 1)
    %{emulator | cursor: new_cursor}
  end

  @doc """
  Handles the Horizontal Tab (HT) action.
  """
  def handle_ht(%EmulatorStruct{} = emulator) do
    # Move cursor to the next tab stop
    {current_col, _} =
      Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    active_buffer = EmulatorStruct.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    # Placeholder: move to next multiple of 8 or end of line
    next_stop = min(width - 1, div(current_col, 8) * 8 + 8)
    # Use alias
    new_cursor = Movement.move_to_column(emulator.cursor, next_stop)
    %{emulator | cursor: new_cursor}
  end

  @doc "Handle Line Feed (LF), New Line (NL), Vertical Tab (VT)"
  def handle_lf(%EmulatorStruct{} = emulator) do
    emulator
    |> handle_pending_wrap()
    |> move_cursor_down()
    |> clamp_to_scroll_region()
  end

  defp handle_pending_wrap(emulator) do
    if emulator.last_col_exceeded do
      {_cx, cy} = Manager.get_position(emulator.cursor)
      wrapped_cursor = Movement.move_to_position(emulator.cursor, 0, cy + 1)

      EmulatorStruct.maybe_scroll(%{
        emulator
        | cursor: wrapped_cursor,
          last_col_exceeded: false
      })
    else
      EmulatorStruct.maybe_scroll(emulator)
    end
  end

  defp move_cursor_down(emulator) do
    active_buffer = EmulatorStruct.get_active_buffer(emulator)
    {buffer_width, buffer_height} = ScreenBuffer.get_dimensions(active_buffer)
    cursor = emulator.cursor

    moved_cursor = Movement.move_down(cursor, 1, buffer_width, buffer_height)
    final_cursor = apply_lnm_mode(emulator.mode_manager, moved_cursor)
    %{emulator | cursor: final_cursor}
  end

  defp apply_lnm_mode(mode_manager, cursor) do
    if ModeManager.mode_enabled?(mode_manager, :lnm) do
      Movement.move_to_column(cursor, 0)
    else
      cursor
    end
  end

  defp clamp_to_scroll_region(emulator) do
    %{
      emulator
      | cursor: clamp_cursor_to_scroll_region(emulator, emulator.cursor)
    }
  end

  defp clamp_cursor_to_scroll_region(emulator, cursor) do
    active_buffer = EmulatorStruct.get_active_buffer(emulator)

    {scroll_top, scroll_bottom} =
      get_scroll_region_bounds(emulator, active_buffer)

    {x, y} = cursor.position
    clamped_y = max(scroll_top, min(y, scroll_bottom))

    if y != clamped_y do
      log_cursor_clamp(y, clamped_y, scroll_top, scroll_bottom)
      move_cursor_to_position(cursor, x, clamped_y)
    else
      cursor
    end
  end

  defp log_cursor_clamp(y, clamped_y, scroll_top, scroll_bottom) do
    Raxol.Core.Runtime.Log.debug(
      "[clamp_cursor] Clamped Y from \\#{y} to \\#{clamped_y} (region \\#{scroll_top}-\\#{scroll_bottom}) "
    )
  end

  defp move_cursor_to_position(cursor, x, y), do: Manager.move_to(cursor, x, y)

  defp get_scroll_region_bounds(emulator, active_buffer) do
    buffer_height = ScreenBuffer.get_height(active_buffer)

    case emulator.scroll_region do
      {top, bottom}
      when integer?(top) and top >= 0 and integer?(bottom) and bottom > top ->
        {top, min(bottom, buffer_height - 1)}

      _ ->
        {0, buffer_height - 1}
    end
  end

  @doc "Handle Carriage Return (CR)"
  def handle_cr(%EmulatorStruct{} = emulator) do
    Raxol.Core.Runtime.Log.debug(
      "[handle_cr] Input: cursor=#{inspect(Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor))}, last_exceeded=#{emulator.last_col_exceeded}"
    )

    # 1. Check for pending wrap
    emulator_after_pending_wrap =
      if emulator.last_col_exceeded do
        Raxol.Core.Runtime.Log.debug("[handle_cr] Pending wrap detected")
        # Perform the deferred wrap: move cursor to col 0, next line
        {_cx, cy} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)
        wrapped_cursor = Movement.move_to_position(emulator.cursor, 0, cy + 1)

        Raxol.Core.Runtime.Log.debug(
          "[handle_cr] Cursor after wrap: #{inspect(wrapped_cursor.position)}"
        )

        # Also scroll if needed after wrap (use maybe_scroll on potentially wrapped state)
        maybe_scrolled_emulator =
          EmulatorStruct.maybe_scroll(%{
            emulator
            | cursor: wrapped_cursor,
              last_col_exceeded: false
          })

        Raxol.Core.Runtime.Log.debug(
          "[handle_cr] State after pending wrap + scroll: cursor=#{inspect(Raxol.Terminal.Cursor.Manager.get_position(maybe_scrolled_emulator.cursor))}, last_exceeded=#{maybe_scrolled_emulator.last_col_exceeded}"
        )

        maybe_scrolled_emulator
      else
        Raxol.Core.Runtime.Log.debug("[handle_cr] No pending wrap")
        emulator
      end

    # 2. Perform CR logic on potentially updated state
    Raxol.Core.Runtime.Log.debug("[handle_cr] Moving cursor to column 0")
    # Get current Y coordinate
    {_cx, cy} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    final_cursor =
      Movement.move_to_position(emulator_after_pending_wrap.cursor, 0, cy)

    Raxol.Core.Runtime.Log.debug(
      "[handle_cr] Final cursor: #{inspect(final_cursor.position)}"
    )

    %{emulator_after_pending_wrap | cursor: final_cursor}
  end

  @spec handle_so(EmulatorStruct.t()) :: EmulatorStruct.t()
  def handle_so(emulator) do
    # SO: Shift Out. Invoke G1 character set.
    %{
      emulator
      | charset_state:
          CharacterSets.invoke_designator(emulator.charset_state, :g1)
    }
  end

  @spec handle_si(EmulatorStruct.t()) :: EmulatorStruct.t()
  def handle_si(emulator) do
    # SI: Shift In. Invoke G0 character set.
    %{
      emulator
      | charset_state:
          CharacterSets.invoke_designator(emulator.charset_state, :g0)
    }
  end

  @spec handle_can(EmulatorStruct.t()) :: EmulatorStruct.t()
  def handle_can(emulator) do
    # CAN: Cancel. Parser should handle this within sequences.
    # If it reaches here, it was outside a sequence.
    Raxol.Core.Runtime.Log.debug(
      "CAN received outside escape sequence, ignoring"
    )

    emulator
  end

  @doc """
  Handles substitute character control code.
  """
  def handle_sub(emulator) do
    # Print a substitute character (typically displayed as ^Z)
    System.cmd("echo", ["-n", "^Z"])
    emulator
  end

  @spec handle_ris(EmulatorStruct.t()) :: EmulatorStruct.t()
  # ESC c - Reset to Initial State
  def handle_ris(emulator) do
    Raxol.Core.Runtime.Log.info("RIS (Reset to Initial State) received")
    # Re-initialize most state components, keeping buffer dimensions
    active_buffer = EmulatorStruct.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    scrollback_limit = active_buffer.scrollback_limit

    # Create a completely new default state, preserving only dimensions/limits
    EmulatorStruct.new(width, height,
      scrollback: scrollback_limit,
      memorylimit: emulator.memory_limit
    )
  end

  @spec handle_ind(EmulatorStruct.t()) :: EmulatorStruct.t()
  # ESC D - Index
  def handle_ind(emulator) do
    # Move cursor down one line, scroll if at bottom margin. Same as LF.
    handle_lf(emulator)
  end

  @spec handle_nel(EmulatorStruct.t()) :: EmulatorStruct.t()
  # ESC E - Next Line
  def handle_nel(emulator) do
    # Move cursor to start of next line. Like CR + LF.
    emulator
    # Move down/scroll
    |> handle_lf()
    # Move to col 0
    |> handle_cr()
  end

  @spec handle_hts(EmulatorStruct.t()) :: EmulatorStruct.t()
  # ESC H - Horizontal Tabulation Set
  def handle_hts(emulator) do
    # Set a tab stop at the current cursor column.
    {x, _y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)
    new_tab_stops = MapSet.put(emulator.tab_stops, x)
    %{emulator | tab_stops: new_tab_stops}
  end

  @doc "Handle Reverse Index (RI) - ESC M"
  def handle_ri(%EmulatorStruct{} = emulator) do
    # Move cursor up one line. If at the top margin, scroll down.
    {_col, row} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)
    active_buffer = EmulatorStruct.get_active_buffer(emulator)

    {top_margin, _} =
      case emulator.scroll_region do
        # Use scroll_region directly
        {top, bottom} -> {top, bottom}
        # Default to full height
        nil -> {0, ScreenBuffer.get_height(active_buffer) - 1}
      end

    if row == top_margin do
      Raxol.Terminal.Commands.Screen.scroll_down(emulator, 1)
    else
      cursor = emulator.cursor
      # Use alias
      cursor =
        Movement.move_up(
          cursor,
          1,
          ScreenBuffer.get_width(active_buffer),
          ScreenBuffer.get_height(active_buffer)
        )

      %{emulator | cursor: cursor}
    end
  end

  @spec handle_decsc(EmulatorStruct.t()) :: EmulatorStruct.t()
  # ESC 7 - Save Cursor State (DEC specific)
  def handle_decsc(emulator) do
    # Capture necessary parts of the emulator state - NO, save_state expects full state
    new_stack = TerminalState.save_state(emulator.state_stack, emulator)
    %{emulator | state_stack: new_stack}
  end

  @spec handle_decrc(EmulatorStruct.t()) :: EmulatorStruct.t()
  # ESC 8 - Restore Cursor State (DEC specific)
  def handle_decrc(emulator) do
    {new_stack, restored_state_data} =
      TerminalState.restore_state(emulator.state_stack)

    if restored_state_data do
      # Apply the restored state components
      # Directly use the restored cursor, style, charset_state, mode_manager, scroll_region
      new_cursor = restored_state_data.cursor
      new_style = restored_state_data.style
      new_charset_state = restored_state_data.charset_state
      # Corrected key
      new_mode_manager_state = restored_state_data.mode_manager
      new_scroll_region = restored_state_data.scroll_region

      # Assuming cursor_style was also saved by TerminalState.save_state if it's part of full DECRC
      new_cursor_style =
        Map.get(restored_state_data, :cursor_style, emulator.cursor_style)

      %{
        emulator
        | state_stack: new_stack,
          cursor: new_cursor,
          style: new_style,
          charset_state: new_charset_state,
          # Corrected field
          mode_manager: new_mode_manager_state,
          scroll_region: new_scroll_region,
          # Ensure cursor_style is restored
          cursor_style: new_cursor_style
      }
    else
      # Stack was empty, no state to restore
      emulator
    end
  end
end
