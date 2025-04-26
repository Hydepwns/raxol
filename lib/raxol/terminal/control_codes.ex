defmodule Raxol.Terminal.ControlCodes do
  @moduledoc """
  Handles simple C0 control codes and non-parameterized ESC sequences.
  """

  require Logger

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.CharacterSets
  alias Raxol.Terminal.ANSI.ScreenModes
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ANSI.TerminalState # Needed for RIS

  # --- C0 Control Code Handlers ---

  @spec handle_bel(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_bel(emulator) do
    Logger.info("BEL received - Action TBD (e.g., emit event, play sound)")
    # TODO: Implement Bell action (e.g., emit :bell event)
    emulator
  end

  @spec handle_bs(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_bs(emulator) do
    # Backspace: Move cursor left, but not past column 0.
    new_cursor = Manager.move_left(emulator.cursor, 1)
    %{emulator | cursor: new_cursor, last_col_exceeded: false}
  end

  @spec handle_ht(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_ht(emulator) do
    # Horizontal Tab: Move to next tab stop. If none, move to end of line.
    {x, y} = emulator.cursor.position
    active_buffer = Emulator.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)

    next_stop = emulator.tab_stops
                |> Enum.filter(&(&1 > x))
                |> Enum.min(fn -> width - 1 end) # Go to end if no stops found

    new_cursor = Manager.move_to_col(emulator.cursor, next_stop)
    %{emulator | cursor: new_cursor, last_col_exceeded: false}
  end

  @spec handle_lf(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_lf(emulator) do
    # Moves cursor down one line.
    # If at bottom of scroll region, scrolls region up.
    # If Linefeed/Newline Mode (LNM) is set (CSI 20 h), also perform CR.
    %{cursor: cursor, scroll_region: scroll_region, mode_state: mode_state} = emulator
    active_buffer = Emulator.get_active_buffer(emulator)
    {_cur_x, cur_y} = cursor.position
    {scroll_top, scroll_bottom} = ScreenBuffer.get_scroll_region_boundaries(active_buffer)

    emulator_after_scroll =
      if cur_y == scroll_bottom do
        # Scroll up if at bottom of region
        new_active_buffer = ScreenBuffer.scroll_up(active_buffer, 1, scroll_region)
        Emulator.update_active_buffer(emulator, new_active_buffer)
      else
        emulator
      end

    # Move cursor down (or stay if scrolled)
    cursor_after_move =
      if cur_y == scroll_bottom do
        cursor # Cursor stays in the same relative position when scrolling
      else
        Manager.move_down(cursor, 1)
      end

    # Handle LNM (move to column 0 if enabled)
    final_cursor =
      if ScreenModes.mode_enabled?(mode_state, :lnm_linefeed_newline) do
        Manager.move_to_col(cursor_after_move, 0)
      else
        cursor_after_move
      end

    %{emulator_after_scroll | cursor: final_cursor, last_col_exceeded: false}
  end

  @spec handle_cr(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_cr(emulator) do
    # Moves cursor to beginning of the current line (column 0).
    new_cursor = Manager.move_to_col(emulator.cursor, 0)
    %{emulator | cursor: new_cursor, last_col_exceeded: false}
  end

  @spec handle_so(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_so(emulator) do
    # SO: Shift Out. Invoke G1 character set.
    %{emulator | charset_state: CharacterSets.invoke_designator(emulator.charset_state, :g1)}
  end

  @spec handle_si(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_si(emulator) do
    # SI: Shift In. Invoke G0 character set.
    %{emulator | charset_state: CharacterSets.invoke_designator(emulator.charset_state, :g0)}
  end

  @spec handle_can(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_can(emulator) do
    # CAN: Cancel. Parser should handle this within sequences.
    # If it reaches here, it was outside a sequence.
    Logger.debug("CAN received outside escape sequence, ignoring")
    emulator
  end

  @spec handle_sub(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_sub(emulator) do
    # SUB: Substitute. Often treated as CAN or ignored.
    Logger.debug("SUB received outside escape sequence, ignoring")
    emulator
  end

  # --- Other ESC Sequence Handlers ---

  @spec handle_ris(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  # ESC c - Reset to Initial State
  def handle_ris(emulator) do
    Logger.info("RIS (Reset to Initial State) received")
    # Re-initialize most state components, keeping buffer dimensions
    active_buffer = Emulator.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    scrollback_limit = active_buffer.scrollback_limit

    # Create a completely new default state, preserving only dimensions/limits
    Emulator.new(width, height, scrollback: scrollback_limit, memorylimit: emulator.memory_limit)
  end

  @spec handle_ind(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  # ESC D - Index
  def handle_ind(emulator) do
    # Move cursor down one line, scroll if at bottom margin. Same as LF.
    handle_lf(emulator)
  end

  @spec handle_nel(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  # ESC E - Next Line
  def handle_nel(emulator) do
    # Move cursor to start of next line. Like CR + LF.
    emulator
    |> handle_lf() # Move down/scroll
    |> handle_cr() # Move to col 0
  end

  @spec handle_hts(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  # ESC H - Horizontal Tabulation Set
  def handle_hts(emulator) do
    # Set a tab stop at the current cursor column.
    {x, _y} = emulator.cursor.position
    new_tab_stops = MapSet.put(emulator.tab_stops, x)
    %{emulator | tab_stops: new_tab_stops}
  end

  @spec handle_ri(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  # ESC M - Reverse Index
  def handle_ri(emulator) do
    # Move cursor up one line, scroll if at top margin.
    %{cursor: cursor, scroll_region: scroll_region} = emulator
    active_buffer = Emulator.get_active_buffer(emulator)
    {_cur_x, cur_y} = cursor.position
    {scroll_top, _scroll_bottom} = ScreenBuffer.get_scroll_region_boundaries(active_buffer)

    emulator_after_scroll =
      if cur_y == scroll_top do
        # Scroll down if at top of region
        new_active_buffer = ScreenBuffer.scroll_down(active_buffer, 1, scroll_region)
        Emulator.update_active_buffer(emulator, new_active_buffer)
      else
        emulator
      end

    # Move cursor up (or stay if scrolled)
    final_cursor =
      if cur_y == scroll_top do
         cursor
      else
         Manager.move_up(cursor, 1)
      end

    %{emulator_after_scroll | cursor: final_cursor, last_col_exceeded: false}
  end

  @spec handle_decsc(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  # ESC 7 - Save Cursor State (DEC specific)
  def handle_decsc(emulator) do
    Logger.debug("DECSC (Save Cursor) received")
    # Save cursor position, attributes, charsets
    current_state = TerminalState.capture(emulator)
    new_stack = TerminalState.push(emulator.state_stack, current_state)
    %{emulator | state_stack: new_stack}
  end

  @spec handle_decrc(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  # ESC 8 - Restore Cursor State (DEC specific)
  def handle_decrc(emulator) do
    Logger.debug("DECRC (Restore Cursor) received")
    # Restore cursor position, attributes, charsets
    {restored_state_data, new_stack} = TerminalState.pop(emulator.state_stack)
    if restored_state_data do
      TerminalState.restore(emulator, restored_state_data)
      |> Map.put(:state_stack, new_stack) # Put back the modified stack
    else
      emulator # No state saved, do nothing
    end
  end

  # --- Private Helpers ---

  # Calculates default tab stops (every 8 columns, 0-based)
  defp default_tab_stops(width) do
    0..(div(width - 1, 8))
    |> Enum.map(&(&1 * 8))
    |> MapSet.new()
  end
end
