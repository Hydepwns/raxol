defmodule Raxol.Terminal.ControlCodes do
  @moduledoc """
  Handles C0 control codes and simple ESC sequences.

  Extracted from Terminal.Emulator for better organization.
  Relies on Emulator state and ScreenBuffer for actions.
  """

  require Logger

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Movement
  alias Raxol.Terminal.CharacterSets
  alias Raxol.Terminal.ANSI.ScreenModes
  alias Raxol.Terminal.ANSI.TerminalState # Needed for RIS

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
  @esc 27 # Escape
  @del 127 # Delete

  # --- C0 Control Code Handlers ---

  @doc """
  Handles a C0 control code (0-31) or DEL (127).
  Delegates to specific handlers based on the codepoint.
  """
  @spec handle_c0(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def handle_c0(emulator, char_codepoint) do
    case char_codepoint do
      @nul ->
        Logger.trace("NUL received, ignoring")
        emulator
      @bel -> handle_bel(emulator)
      @bs -> handle_bs(emulator)
      @ht -> handle_ht(emulator)
      @lf -> handle_lf(emulator)
      @vt -> handle_lf(emulator) # Treat VT like LF for now
      @ff -> handle_lf(emulator) # Treat FF like LF for now
      @cr -> handle_cr(emulator)
      @so -> handle_so(emulator)
      @si -> handle_si(emulator)
      @can -> handle_can(emulator)
      @sub -> handle_sub(emulator)
      @esc ->
        # Should be handled by the parser's state transitions
        Logger.debug("ESC received unexpectedly in C0 handler, ignoring")
        emulator
      @del ->
        Logger.trace("DEL received, ignoring")
        emulator
      # Add other C0 codes as needed (e.g., ENQ, ACK, DC1-4, NAK, SYN, ETB, EM, FS, GS, RS, US)
      _ ->
        Logger.debug("Unhandled C0 control code: #{char_codepoint}")
        emulator
    end
  end

  @spec handle_bel(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_bel(emulator) do
    Logger.info("BEL received - Action TBD (e.g., emit event, play sound)")
    # TODO: Implement Bell action (e.g., emit :bell event)
    emulator
  end

  @doc "Handle Backspace (BS)"
  def handle_bs(%Emulator{} = emulator) do
    # Move cursor left by one, respecting margins
    # Use alias
    new_cursor = Movement.move_left(emulator.cursor, 1)
    %{emulator | cursor: new_cursor}
  end

  @doc "Handle Horizontal Tab (HT)"
  def handle_ht(%Emulator{} = emulator) do
    # Move cursor to the next tab stop
    {current_col, _} = emulator.cursor.position
    active_buffer = Emulator.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    # Placeholder: move to next multiple of 8 or end of line
    next_stop = min(width - 1, div(current_col, 8) * 8 + 8)
    # Use alias
    new_cursor = Movement.move_to_column(emulator.cursor, next_stop)
    %{emulator | cursor: new_cursor}
  end

  @doc "Handle Line Feed (LF), New Line (NL), Vertical Tab (VT)"
  def handle_lf(%Emulator{} = emulator) do
    Logger.debug("Handling LF at cursor: #{inspect(emulator.cursor.position)}")
    # Behavior depends on New Line Mode (LNM)
    cursor = emulator.cursor

    if ScreenModes.mode_enabled?(emulator.mode_state, :lnm) do
      # LNM: LF acts like CRLF
      # Move down first
      # Use alias
      cursor = Movement.move_down(cursor, 1)
      # Then move to column 0
      # Use alias
      cursor = Movement.move_to_column(cursor, 0)
      %{emulator | cursor: cursor} |> Emulator.maybe_scroll()
    else
      # Normal Mode: LF moves down one line in the same column
      # Use alias
      cursor = Movement.move_down(cursor, 1)
      %{emulator | cursor: cursor} |> Emulator.maybe_scroll()
    end
  end

  @doc "Handle Carriage Return (CR)"
  def handle_cr(%Emulator{} = emulator) do
    # Move cursor to column 0
    # Use alias
    new_cursor = Movement.move_to_column(emulator.cursor, 0)
    %{emulator | cursor: new_cursor}
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

  @doc "Handle Reverse Index (RI) - ESC M"
  def handle_ri(%Emulator{} = emulator) do
    # Move cursor up one line. If at the top margin, scroll down.
    {_col, row} = emulator.cursor.position
    active_buffer = Emulator.get_active_buffer(emulator)
    {top_margin, _} =
      case emulator.scroll_region do
        {top, bottom} -> {top, bottom} # Use scroll_region directly
        nil -> {0, ScreenBuffer.get_height(active_buffer) - 1} # Default to full height
      end

    if row == top_margin do
      Raxol.Terminal.Commands.Screen.scroll_down(emulator, 1)
    else
      cursor = emulator.cursor
      # Use alias
      cursor = Movement.move_up(cursor, 1)
      %{emulator | cursor: cursor}
    end
  end

  @spec handle_decsc(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  # ESC 7 - Save Cursor State (DEC specific)
  def handle_decsc(emulator) do
    # current_state = TerminalState.capture(emulator)
    # new_stack = TerminalState.push(emulator.state_stack, current_state)
    # Capture necessary parts of the emulator state - NO, save_state expects full state
    # current_state = %{
    #   cursor_pos: emulator.cursor.position,
    #   attributes: emulator.current_attributes,
    #   charset_state: emulator.charsets,
    #   # Add other relevant state fields if needed
    #   # scroll_region: ScreenBuffer.get_scroll_region_boundaries(emulator.active_buffer) ?
    # }
    # new_stack = TerminalState.save_state(emulator.state_stack, current_state)
    new_stack = TerminalState.save_state(emulator.state_stack, emulator)
    %{emulator | state_stack: new_stack}
  end

  @spec handle_decrc(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  # ESC 8 - Restore Cursor State (DEC specific)
  def handle_decrc(emulator) do
    {new_stack, restored_state_data} = TerminalState.restore_state(emulator.state_stack)

    if restored_state_data do
      # Apply the restored state components
      # Directly use the restored cursor, style, charset_state, mode_state, scroll_region
      new_cursor = restored_state_data.cursor
      new_style = restored_state_data.style
      new_charset_state = restored_state_data.charset_state
      new_mode_state = restored_state_data.mode_state
      new_scroll_region = restored_state_data.scroll_region

      %{
        emulator
        | state_stack: new_stack,
          cursor: new_cursor,
          style: new_style,
          charset_state: new_charset_state,
          mode_state: new_mode_state,
          scroll_region: new_scroll_region
      }
    else
      # Stack was empty, no state to restore
      emulator
    end
  end

  # --- Helper Function ---

  # REMOVE Private maybe_scroll definition
  # defp maybe_scroll(state) do
  #   {cursor_row, _} = Emulator.get_cursor_position(state.emulator)
  #   # Get scroll region directly from emulator state
  #   scroll_region = state.emulator.scroll_region
  #   active_buffer = Emulator.get_active_buffer(state.emulator)
  #
  #   {_top, bottom} = scroll_region || {0, ScreenBuffer.get_height(active_buffer) - 1}
  #
  #   if cursor_row > bottom do # Check if cursor is *below* the region
  #     # Return updated emulator state after scrolling
  #     # Raxol.Terminal.Commands.Screen.scroll_up(state.emulator, 1)
  #     Logger.debug("Cursor below scroll region, would scroll up (currently commented out)")
  #     state # Return original state for now
  #   else
  #     state # Cursor within region, no scroll needed
  #   end
  # end
end
