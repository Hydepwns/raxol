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
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ModeManager
  alias Raxol.Terminal.ANSI.TerminalState # Needed for RIS
  alias Raxol.System.Interaction # Added alias for system interactions

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

  # --- C0 Control Code Handlers ---

  @doc """
  Handles a C0 control code (0-31) or DEL (127).
  Delegates to specific handlers based on the codepoint.
  """
  @spec handle_c0(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def handle_c0(emulator, char_codepoint) do
    case char_codepoint do
      @nul ->
        Logger.debug("NUL received, ignoring")
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
        Logger.debug("DEL received, ignoring")
        emulator
      # Add other C0 codes as needed (e.g., ENQ, ACK, DC1-4, NAK, SYN, ETB, EM, FS, GS, RS, US)
      _ ->
        Logger.debug("Unhandled C0 control code: #{char_codepoint}")
        emulator
    end
  end

  @spec handle_bel(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_bel(emulator) do
    Logger.info("BEL received - Ringing bell.")
    Interaction.ring_bell()
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
    Logger.debug(
      "[handle_lf] Input: cursor=#{inspect(emulator.cursor.position)}, last_exceeded=#{emulator.last_col_exceeded}"
    )

    # 1. Handle pending wrap if necessary, then check for scrolling *once*
    emulator_after_wrap_and_scroll =
      if emulator.last_col_exceeded do
        Logger.debug("[handle_lf] Pending wrap detected")
        # Perform the deferred wrap: move cursor to col 0, next line
        {_cx, cy} = emulator.cursor.position
        wrapped_cursor = Movement.move_to_position(emulator.cursor, 0, cy + 1)
        Logger.debug("[handle_lf] Cursor after wrap: #{inspect(wrapped_cursor.position)}")

        # Create intermediate state *after* wrap but *before* scroll check
        emulator_after_wrap = %{
          emulator
          | cursor: wrapped_cursor,
            last_col_exceeded: false # Clear flag immediately after handling wrap
        }

        # Now check if scrolling is needed in this post-wrap state
        Logger.debug("[handle_lf] Checking maybe_scroll after wrap")
        scrolled_emulator = Emulator.maybe_scroll(emulator_after_wrap)
        Logger.debug(
          "[handle_lf] State after wrap scroll check: cursor=#{inspect(scrolled_emulator.cursor.position)}"
        )
        scrolled_emulator # This state is now ready for the final cursor move
      else
        Logger.debug("[handle_lf] No pending wrap")
        # No wrap needed, just check if scrolling is needed based on current state
        Logger.debug("[handle_lf] Checking maybe_scroll (no wrap)")
        scrolled_emulator = Emulator.maybe_scroll(emulator)
        Logger.debug(
          "[handle_lf] State after no-wrap scroll check: cursor=#{inspect(scrolled_emulator.cursor.position)}"
        )
        scrolled_emulator # This state is ready for the final cursor move
      end

    # 2. Now proceed with standard LF cursor movement logic on the (potentially) scrolled state
    cursor_after_scroll = emulator_after_wrap_and_scroll.cursor
    active_buffer = Emulator.get_active_buffer(emulator_after_wrap_and_scroll)
    {_buffer_width, buffer_height} = ScreenBuffer.get_dimensions(active_buffer)

    # Get effective scroll region (used for clamping Y after move)
    {scroll_top, scroll_bottom_inclusive} =
      case emulator_after_wrap_and_scroll.scroll_region do
        {top, bottom} when is_integer(top) and top >= 0 and is_integer(bottom) and bottom > top ->
          {top, min(bottom, buffer_height - 1)}
        _ -> {0, buffer_height - 1} # Default: full buffer
      end

    # Perform the move down
    lnm_enabled = ModeManager.mode_enabled?(emulator_after_wrap_and_scroll.mode_manager, :lnm)
    Logger.debug("[handle_lf] Performing move down (LNM enabled: #{lnm_enabled})")
    final_cursor_before_clamp =
      if lnm_enabled do
        # LNM: LF acts like CRLF (move down, then to column 0)
        moved_down = Movement.move_down(cursor_after_scroll, 1)
        Movement.move_to_column(moved_down, 0)
      else
        # Normal Mode: LF moves down one line in the same column
        Movement.move_down(cursor_after_scroll, 1)
      end
    Logger.debug("[handle_lf] Cursor after move down (before clamp): #{inspect(final_cursor_before_clamp.position)}")

    # 3. Clamp the final Y position
    {final_x, final_y_unclamped} = final_cursor_before_clamp.position
    effective_bottom = min(buffer_height - 1, scroll_bottom_inclusive)
    final_y_clamped = min(final_y_unclamped, effective_bottom)
    final_cursor = Manager.move_to(final_cursor_before_clamp, final_x, final_y_clamped)
    Logger.debug("[handle_lf] Final cursor (after clamp): #{inspect(final_cursor.position)}")

    # Ensure cursor stays within scroll region (may already be handled by clamp above)
    final_cursor_clamped_region = clamp_cursor_to_scroll_region(emulator_after_wrap_and_scroll, final_cursor)
    Logger.debug(
      "[handle_lf] Cursor After Move (After Region Clamp): #{inspect(final_cursor_clamped_region.position)}"
    )

    # Return final state (Note: last_col_exceeded was already reset if wrap occurred)
    %{emulator_after_wrap_and_scroll | cursor: final_cursor_clamped_region}
  end

  defp clamp_cursor_to_scroll_region(emulator, cursor) do
    active_buffer = Emulator.get_active_buffer(emulator)
    buffer_height = ScreenBuffer.get_height(active_buffer)

    {scroll_top, scroll_bottom_inclusive} =
      case emulator.scroll_region do
        {top, bottom} when is_integer(top) and top >= 0 and is_integer(bottom) and bottom > top ->
          {top, min(bottom, buffer_height - 1)}
        _ -> {0, buffer_height - 1} # Default: full buffer
      end

    {x, y} = cursor.position
    clamped_y = max(scroll_top, min(y, scroll_bottom_inclusive))

    if y != clamped_y do
      Logger.debug("[clamp_cursor] Clamped Y from #{y} to #{clamped_y} (region #{scroll_top}-#{scroll_bottom_inclusive}) ")
      Manager.move_to(cursor, x, clamped_y)
    else
      cursor
    end
  end

  @doc "Handle Carriage Return (CR)"
  def handle_cr(%Emulator{} = emulator) do
    Logger.debug(
      "[handle_cr] Input: cursor=#{inspect(emulator.cursor.position)}, last_exceeded=#{emulator.last_col_exceeded}"
    )
    # 1. Check for pending wrap
    emulator_after_pending_wrap =
      if emulator.last_col_exceeded do
        Logger.debug("[handle_cr] Pending wrap detected")
        # Perform the deferred wrap: move cursor to col 0, next line
        {_cx, cy} = emulator.cursor.position
        wrapped_cursor = Movement.move_to_position(emulator.cursor, 0, cy + 1)
        Logger.debug("[handle_cr] Cursor after wrap: #{inspect(wrapped_cursor.position)}")
        # Also scroll if needed after wrap (use maybe_scroll on potentially wrapped state)
        maybe_scrolled_emulator = Emulator.maybe_scroll(%{
          emulator
          | cursor: wrapped_cursor,
            last_col_exceeded: false
        })
        Logger.debug(
          "[handle_cr] State after pending wrap + scroll: cursor=#{inspect(maybe_scrolled_emulator.cursor.position)}, last_exceeded=#{maybe_scrolled_emulator.last_col_exceeded}"
        )
        maybe_scrolled_emulator
      else
        Logger.debug("[handle_cr] No pending wrap")
        emulator
      end

    # 2. Perform CR logic on potentially updated state
    Logger.debug("[handle_cr] Moving cursor to column 0")
    {_cx, cy} = emulator_after_pending_wrap.cursor.position # Get current Y coordinate
    final_cursor = Movement.move_to_position(emulator_after_pending_wrap.cursor, 0, cy)
    Logger.debug("[handle_cr] Final cursor: #{inspect(final_cursor.position)}")

    %{emulator_after_pending_wrap | cursor: final_cursor}
  end

  @spec handle_so(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_so(emulator) do
    # SO: Shift Out. Invoke G1 character set.
    %{emulator | charset_state: CharacterSets.invoke_charset(emulator.charset_state, :g1)}
  end

  @spec handle_si(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_si(emulator) do
    # SI: Shift In. Invoke G0 character set.
    %{emulator | charset_state: CharacterSets.invoke_charset(emulator.charset_state, :g0)}
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
    Logger.info("SUB received - Triggering substitute action.")
    Interaction.substitute_character()
    # TODO: Should SUB potentially cancel the current escape sequence in the parser state?
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
      # Directly use the restored cursor, style, charset_state, mode_manager, scroll_region
      new_cursor = restored_state_data.cursor
      new_style = restored_state_data.style
      new_charset_state = restored_state_data.charset_state
      new_mode_manager_state = restored_state_data.mode_manager # Corrected key
      new_scroll_region = restored_state_data.scroll_region
      # Assuming cursor_style was also saved by TerminalState.save_state if it's part of full DECRC
      new_cursor_style = Map.get(restored_state_data, :cursor_style, emulator.cursor_style)

      %{
        emulator
        | state_stack: new_stack,
          cursor: new_cursor,
          style: new_style,
          charset_state: new_charset_state,
          mode_manager: new_mode_manager_state, # Corrected field
          scroll_region: new_scroll_region,
          cursor_style: new_cursor_style # Ensure cursor_style is restored
      }
    else
      # Stack was empty, no state to restore
      emulator
    end
  end

end
