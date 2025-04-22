defmodule Raxol.Terminal.ControlCodes do
  @moduledoc """
  Handles simple C0 control codes and non-parameterized ESC sequences.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.CharacterSets
  alias Raxol.Terminal.ANSI.ScreenModes
  # Needed for handle_ris
  alias Raxol.Terminal.ANSI.TextFormatting
  require Logger

  # --- C0 Control Code Handlers ---

  @spec handle_bel(Emulator.t()) :: Emulator.t()
  def handle_bel(emulator) do
    Logger.info("BEL received - Action TBD (e.g., emit event, play sound)")
    # TODO: Implement Bell action (e.g., emit :bell event)
    emulator
  end

  @spec handle_bs(Emulator.t()) :: Emulator.t()
  def handle_bs(emulator) do
    # Backspace: Move cursor left, but not past column 0.
    # Note: Cursor position is 0-based internally
    {cursor_x, cursor_y} = emulator.cursor.position
    active_buffer = Emulator.get_active_buffer(emulator)
    buffer_width = ScreenBuffer.get_width(active_buffer)
    buffer_height = ScreenBuffer.get_height(active_buffer)

    new_cursor =
      Manager.move_to(
        emulator.cursor,
        {max(0, cursor_x - 1), cursor_y},
        buffer_width,
        buffer_height
      )

    %{
      emulator
      | cursor: new_cursor,
        last_col_exceeded: false
    }
  end

  @spec handle_ht(Emulator.t()) :: Emulator.t()
  def handle_ht(emulator) do
    # Horizontal Tab: Move to next tab stop. If none, move to end of line.
    # 0-based
    # Renamed y to cursor_y for clarity
    {x, cursor_y} = emulator.cursor.position
    active_buffer = Emulator.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    # Added height
    height = ScreenBuffer.get_height(active_buffer)
    # Find the smallest tab stop > x
    next_stop =
      emulator.tab_stops
      |> Enum.filter(&(&1 > x))
      # If no stops found, go to end
      |> Enum.min(width - 1)

    # Ensure the stop is within bounds
    target_col = min(next_stop, width - 1)

    # Use move_to/4
    new_cursor =
      Manager.move_to(emulator.cursor, {target_col, cursor_y}, width, height)

    %{emulator | cursor: new_cursor, last_col_exceeded: false}
  end

  @spec handle_lf(Emulator.t()) :: Emulator.t()
  def handle_lf(emulator) do
    # LF: Line Feed. Also used for VT (Vertical Tab) and FF (Form Feed).
    # Moves cursor down one line, possibly scrolling. Stays in same column.
    # Honors scroll region. If LNM (Line Feed New Line Mode) is active, also does CR.
    Emulator.handle_lf(emulator)
  end

  @spec handle_cr(Emulator.t()) :: Emulator.t()
  def handle_cr(emulator) do
    # CR: Carriage Return. Move cursor to beginning of the current line (column 0).
    Emulator.handle_cr(emulator)
  end

  @spec handle_so(Emulator.t()) :: Emulator.t()
  def handle_so(emulator) do
    # SO: Shift Out. Invoke G1 character set.
    %{
      emulator
      | charset_state:
          CharacterSets.invoke_designator(emulator.charset_state, :g1)
    }
  end

  @spec handle_si(Emulator.t()) :: Emulator.t()
  def handle_si(emulator) do
    # SI: Shift In. Invoke G0 character set.
    %{
      emulator
      | charset_state:
          CharacterSets.invoke_designator(emulator.charset_state, :g0)
    }
  end

  @spec handle_can(Emulator.t()) :: Emulator.t()
  def handle_can(emulator) do
    # CAN: Cancel. Parser should handle this within sequences.
    # If it reaches here, it was outside a sequence.
    Logger.debug("CAN received outside escape sequence, ignoring")
    emulator
  end

  @spec handle_sub(Emulator.t()) :: Emulator.t()
  def handle_sub(emulator) do
    # SUB: Substitute. Often treated as CAN or ignored.
    Logger.debug("SUB received outside escape sequence, ignoring")
    emulator
  end

  # --- Other ESC Sequence Handlers ---

  @spec handle_ris(Emulator.t()) :: Emulator.t()
  # ESC c - Reset to Initial State
  def handle_ris(emulator) do
    Logger.info("RIS (Reset to Initial State) received")
    # Re-initialize most state components, keeping buffer dimensions
    active_buffer = Emulator.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    # Preserve limit
    scrollback_limit = active_buffer.scrollback_limit

    # Reset cursor to {0, 0}
    new_cursor = Manager.new()
    # Reset style
    new_style = TextFormatting.new()
    # Clear main buffer
    # Reset main
    cleared_main_buffer = ScreenBuffer.new(width, height, scrollback_limit)
    # Clear alternate buffer (assuming it should reset too?)
    # No scrollback for alt
    cleared_alt_buffer = ScreenBuffer.new(width, height, 0)
    # Reset modes
    new_modes = ScreenModes.new()
    # Reset charsets
    new_charsets = CharacterSets.new()
    # Reset tab stops
    # Use helper
    new_tab_stops = default_tab_stops(width)

    # Reset state stack - Use TerminalState.new()
    new_state_stack = Raxol.Terminal.ANSI.TerminalState.new()

    %{
      emulator
      | cursor: new_cursor,
        style: new_style,
        # Reset both buffers
        main_screen_buffer: cleared_main_buffer,
        alternate_screen_buffer: cleared_alt_buffer,
        # Reset to main
        active_buffer_type: :main,
        mode_state: new_modes,
        charset_state: new_charsets,
        # Reset scroll region
        scroll_region: nil,
        # Reset tab stops
        tab_stops: new_tab_stops,
        last_col_exceeded: false,
        # Reset stack
        state_stack: new_state_stack
    }
  end

  @spec handle_ind(Emulator.t()) :: Emulator.t()
  # ESC D - Index
  def handle_ind(emulator) do
    # Move cursor down one line, scroll if at bottom margin. Same as LF?
    Emulator.handle_lf(emulator)
  end

  @spec handle_nel(Emulator.t()) :: Emulator.t()
  # ESC E - Next Line
  def handle_nel(emulator) do
    # Move cursor to start of next line. Like CR + LF.
    Emulator.handle_nel(emulator)
  end

  @spec handle_hts(Emulator.t()) :: Emulator.t()
  # ESC H - Horizontal Tabulation Set
  def handle_hts(emulator) do
    # Set a tab stop at the current cursor column.
    Emulator.handle_hts(emulator)
  end

  @spec handle_ri(Emulator.t()) :: Emulator.t()
  # ESC M - Reverse Index
  def handle_ri(emulator) do
    # Move cursor up one line, scroll if at top margin.
    Emulator.handle_ri(emulator)
  end

  @spec handle_decsc(Emulator.t()) :: Emulator.t()
  # ESC 7 - Save Cursor State (DEC specific)
  def handle_decsc(emulator) do
    Logger.debug("DECSC (Save Cursor) received")
    Emulator.handle_decsc(emulator)
  end

  @spec handle_decrc(Emulator.t()) :: Emulator.t()
  # ESC 8 - Restore Cursor State (DEC specific)
  def handle_decrc(emulator) do
    Logger.debug("DECRC (Restore Cursor) received")
    Emulator.handle_decrc(emulator)
  end

  # --- Private Helpers ---

  # Calculates default tab stops (every 8 columns, 0-based)
  defp default_tab_stops(width) do
    # Set default tab stops every 8 columns
    # 0-based calculation
    Enum.to_list(0..div(width - 1, 8))
    |> Enum.map(&(&1 * 8))
    # Convert to MapSet for efficient lookup
    |> MapSet.new()
  end
end
