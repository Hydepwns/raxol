defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  Manages the state of the terminal emulator, including screen buffer,
  cursor position, attributes, and modes.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.ScreenModes
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ANSI.TerminalState
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.ControlCodes
  alias Raxol.Terminal.Parser
  alias Raxol.Plugins.PluginManager

  require Logger

  @dialyzer [
    {:nowarn_function, [
      resize: 3,
      get_cursor_position: 1,
      map_charset_code_to_atom: 1,
      index_to_gset_atom: 1
    ]}
  ]

  # Constants for control characters
  @escape_char 27
  @compile {:unused_attr, :csi_char}
  @csi_char ?[
  @compile {:unused_attr, :dcs_char}
  @dcs_char ?P
  @compile {:unused_attr, :osc_char}
  @osc_char ?]
  @compile {:unused_attr, :pm_char}
  @pm_char ?^
  @compile {:unused_attr, :apc_char}
  @apc_char ?_
  @compile {:unused_attr, :sos_char}
  @sos_char ?X
  @compile {:unused_attr, :st_char}
  @st_char 92
  @compile {:unused_attr, :ss2_char}
  @ss2_char ?N
  @compile {:unused_attr, :ss3_char}
  @ss3_char ?O

  # Constants for simple C0 codes - used by ControlCodes
  @nul 0
  @bel 7
  @bs_char 8
  @ht 9
  @lf 10
  @vt 11
  @ff 12
  @cr_char 13
  @so 14
  @si 15
  @can_char 24
  @sub_char 26
  @del_char 127

  # Constants for simple control codes - used by parser
  @compile {:unused_attr, :sp}
  @sp 32
  @compile {:unused_attr, :us}
  @us 31

  @type cursor_style_type ::
          :blinking_block
          | :steady_block
          | :blinking_underline
          | :steady_underline
          | :blinking_bar
          | :steady_bar

  @type t :: %__MODULE__{
          main_screen_buffer: ScreenBuffer.t(),
          alternate_screen_buffer: ScreenBuffer.t(),
          active_buffer_type: :main | :alternate,
          cursor: Manager.t(),
          scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
          style: TextFormatting.text_style(),
          memory_limit: non_neg_integer(),
          charset_state: CharacterSets.charset_state(),
          mode_state: ScreenModes.screen_state(),
          plugin_manager: PluginManager.t(),
          options: map(),
          current_hyperlink_url: String.t() | nil,
          window_title: String.t() | nil,
          icon_name: String.t() | nil,
          tab_stops: MapSet.t(),
          output_buffer: String.t(),
          cursor_style: cursor_style_type()
        }

  # Use Manager struct
  defstruct cursor: Manager.new(),
            # TODO: This might need updating to save Manager state?
            saved_cursor: {1, 1},
            style: TextFormatting.new(),
            # Manages G0-G3 designation and invocation
            charset_state: CharacterSets.new(),
            # Tracks various modes (like DECCKM, DECOM)
            mode_state: ScreenModes.new(),
            # Set default tab stops
            # Initialize tab_stops
            tab_stops: MapSet.new(),
            # <--- Change: Store the ScreenBuffer struct here
            # To be initialized in new/3
            main_screen_buffer: nil,
            # To be initialized in new/3
            alternate_screen_buffer: nil,
            active_buffer_type: :main,
            # Stack for DECSC/DECRC like operations
            state_stack: TerminalState.new(),
            # Active scroll region {top_line, bottom_line} (1-based), nil for full screen
            scroll_region: nil,
            # Default memory limit (e.g., bytes or lines)
            memory_limit: 1_000_000,
            # Flag for VT100 line wrapping behavior (DECAWM)
            last_col_exceeded: false,
            # Initialize Plugin Manager,
            plugin_manager: PluginManager.new(),
            options: %{},
            current_hyperlink_url: nil,
            window_title: nil,
            icon_name: nil,
            output_buffer: "",
            cursor_style: :blinking_block

  @doc """
  Creates a new terminal emulator instance with the specified dimensions and options.

  ## Examples

      iex> emulator = Raxol.Terminal.Emulator.new(80, 24, %{})
      iex> emulator.width
      80
      iex> emulator.height
      24
      iex> emulator.cursor.position
      {0, 0}

  """
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  @dialyzer {:nowarn_function, new: 3}
  def new(width \\ 80, height \\ 24, opts \\ []) do
    scrollback_limit = Keyword.get(opts, :scrollback, 1000)
    memory_limit = Keyword.get(opts, :memorylimit, 1_000_000)
    plugin_manager = PluginManager.new()
    # Initialize Manager
    initial_cursor = Manager.new()
    _initial_buffer = ScreenBuffer.new(width, height, scrollback_limit)
    # Initialize both buffers
    main_buffer = ScreenBuffer.new(width, height, scrollback_limit)
    # Alternate buffer usually has no scrollback
    alternate_buffer = ScreenBuffer.new(width, height, 0)
    initial_modes = ScreenModes.new()
    initial_charset_state = CharacterSets.new()
    initial_state_stack = TerminalState.new()
    # Generate default tabs
    initial_tab_stops = default_tab_stops(width)

    %__MODULE__{
      cursor: initial_cursor,
      # TODO: Update saved_cursor logic?
      saved_cursor: {1, 1},
      style: TextFormatting.new(),
      charset_state: initial_charset_state,
      mode_state: initial_modes,
      # Store both buffers
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,
      active_buffer_type: :main,
      state_stack: initial_state_stack,
      scroll_region: nil,
      # Initialize from variable
      memory_limit: memory_limit,
      # Initialize default tab stops
      tab_stops: initial_tab_stops,
      last_col_exceeded: false,
      # Assign initialized Plugin Manager
      plugin_manager: plugin_manager
    }
  end

  @doc """
  Processes input from the user, handling both regular characters and escape sequences.
  Processes the entire input string recursively.

  ## Examples

      iex> emulator = Raxol.Terminal.Emulator.new(80, 24, %{})
      iex> {emulator, _} = Raxol.Terminal.Emulator.process_input(emulator, "a")
      # Cursor position is now 1-based, so {1, 1} after 'a'
      iex> emulator.cursor.position
      {1, 1}
      iex> emulator = Raxol.Terminal.Emulator.new()
      iex> {emulator, _} = Raxol.Terminal.Emulator.process_input(emulator, "\\e[1;31mRed\\e[0m Text")
      iex> {x, y} = emulator.cursor.position
      iex> x # Length of "Red Text" (8 chars) + starting at 1 = 9
      9
      iex> emulator.style.foreground # Should be reset by \\e[0m
      nil

  """
  @spec process_input(t(), String.t()) :: {t(), String.t()}
  def process_input(emulator, input) when is_binary(input) do
    # Call the NEW Parser module, passing the current emulator state
    # <-- Pass emulator directly
    updated_emulator_state = Parser.parse_chunk(emulator, input)

    # Collect the output buffer generated during parsing/command execution
    output_to_send = updated_emulator_state.output_buffer

    # Clear the output buffer in the final state
    final_emulator_state = %{updated_emulator_state | output_buffer: ""}

    # Return the final state and the collected output
    {final_emulator_state, output_to_send}
  end

  # --- Active Buffer Helpers ---

  @doc "Gets the currently active screen buffer."
  @spec get_active_buffer(Raxol.Terminal.Emulator.t()) ::
          Raxol.Terminal.ScreenBuffer.t()
  def get_active_buffer(%__MODULE__{
        active_buffer_type: :main,
        main_screen_buffer: buffer
      }),
      do: buffer

  def get_active_buffer(%__MODULE__{
        active_buffer_type: :alternate,
        alternate_screen_buffer: buffer
      }),
      do: buffer

  @doc "Updates the currently active screen buffer."
  @spec update_active_buffer(
          Raxol.Terminal.Emulator.t(),
          Raxol.Terminal.ScreenBuffer.t()
        ) :: Raxol.Terminal.Emulator.t()
  def update_active_buffer(
        %__MODULE__{active_buffer_type: :main} = emulator,
        new_buffer
      ) do
    %{emulator | main_screen_buffer: new_buffer}
  end

  def update_active_buffer(
        %__MODULE__{active_buffer_type: :alternate} = emulator,
        new_buffer
      ) do
    %{emulator | alternate_screen_buffer: new_buffer}
  end

  # --- Character Processing (C0 and Printable) ---

  def process_character(emulator, char_codepoint)
      when char_codepoint >= 0 and char_codepoint <= 31 do
    # Handle C0 Control Codes -> Delegate to ControlCodes module
    # We need to import/alias ControlCodes first
    case char_codepoint do
      # Ignore NUL
      @nul ->
        emulator

      @bel ->
        ControlCodes.handle_bel(emulator)

      @bs_char ->
        ControlCodes.handle_bs(emulator)

      @ht ->
        ControlCodes.handle_ht(emulator)

      # Also handles VT and FF currently
      @lf ->
        ControlCodes.handle_lf(emulator)

      # Treat VT like LF for now
      @vt ->
        ControlCodes.handle_lf(emulator)

      # Treat FF like LF for now
      @ff ->
        ControlCodes.handle_lf(emulator)

      @cr_char ->
        ControlCodes.handle_cr(emulator)

      @so ->
        ControlCodes.handle_so(emulator)

      @si ->
        ControlCodes.handle_si(emulator)

      @can_char ->
        ControlCodes.handle_can(emulator)

      @sub_char ->
        ControlCodes.handle_sub(emulator)

      # Should be handled by process_chunk, but ignore if it reaches here
      @escape_char ->
        emulator

      # Add other C0 codes as needed (e.g., ENQ, ACK, DC1-4, NAK, SYN, ETB, EM, FS, GS, RS, US)
      _ ->
        Logger.debug("Unhandled C0 control code: #{char_codepoint}")
        emulator
    end
  end

  def process_character(emulator, @del_char) do
    # Handle DEL (Delete) -> Delegate to ControlCodes (create handle_del? or ignore)
    # For now, let's keep ignoring it here as ControlCodes doesn't have handle_del.
    Logger.debug("DEL received, ignoring")
    emulator
  end

  def process_character(emulator, char_codepoint) do
    # Get the currently active buffer
    active_buffer = get_active_buffer(emulator)
    # Handle Printable Characters (including extended ASCII and Unicode)
    # Map character based on current charset state (G0-G3)
    mapped_char =
      CharacterSets.translate_char(emulator.charset_state, char_codepoint)

    # Use the existing emulator state as charset_state is not modified by translate_char
    emulator_with_charset = emulator

    # TODO: Check if in insert mode (IRM) - if so, shift existing chars right
    # TODO: Review and fix potential 0-based vs 1-based indexing issues in autowrap.

    # Access position directly from the cursor struct field
    # 0-based
    {cursor_x, cursor_y} = emulator_with_charset.cursor.position
    # e.g., 80
    width = ScreenBuffer.get_width(active_buffer)

    decawm_enabled =
      ScreenModes.mode_enabled?(
        emulator_with_charset.mode_state,
        :decawm_autowrap
      )

    # Determine write coordinates and next cursor position
    {write_y, write_x, next_cursor_y, next_cursor_x, next_last_col_exceeded} =
      cond do
        # Case 1: Previous character caused wrap flag to be set.
        emulator_with_charset.last_col_exceeded ->
          # Write at start of next line {0, y+1}. Reset flag. Advance cursor to {1, y+1}.
          {cursor_y + 1, 0, cursor_y + 1, 1, false}

        # Case 2: Cursor is at the last column (width - 1).
        cursor_x == width - 1 ->
          if decawm_enabled do
            # Write at last column {width-1, y}. Set wrap flag. Move cursor to next line {0, y+1}.
            {cursor_y, cursor_x, cursor_y + 1, 0, true}
          else
            # DECAWM off: Write at last column {width-1, y}. Don't set flag. Keep cursor at last column {width-1, y}.
            {cursor_y, cursor_x, cursor_y, cursor_x, false}
          end

        # Case 3: Normal character write.
        true ->
          # Write at current position {x,y}. Don't set flag. Advance cursor {x+1, y}.
          {cursor_y, cursor_x, cursor_y, cursor_x + 1, false}
      end

    # Coordinates for ScreenBuffer.write_char (0-based)
    buffer_y = write_y
    buffer_x = write_x

    # Write to the active buffer
    # IO.inspect(
    #   {:process_char_write, buffer_coords: {x, y}, char: char, buffer_dims: {width, ScreenBuffer.get_height(active_buffer)}},
    #   label: "DEBUG_WRITE"
    # )

    updated_active_buffer =
      ScreenBuffer.write_char(
        active_buffer,
        buffer_x,
        buffer_y,
        <<mapped_char::utf8>>,
        emulator_with_charset.style
      )

    # Update cursor to the calculated next position
    # # DEBUG ADD: Inspect arguments passed to move_to
    # IO.inspect({:process_char_before_move_to, cursor_before: emulator_with_charset.cursor, next_x: next_cursor_x, next_y: next_cursor_y}, label: "DEBUG_PROC_CHAR")
    new_cursor_state =
      Manager.move_to(
        emulator_with_charset.cursor,
        next_cursor_x,
        next_cursor_y
      )

    # Update the emulator state with the modified active buffer
    emulator_after_write =
      update_active_buffer(emulator_with_charset, updated_active_buffer)

    %{
      emulator_after_write
      | cursor: new_cursor_state,
        last_col_exceeded: next_last_col_exceeded
    }
  end

  # --- Command Handling Delegates (Called by Parser) ---
  # These functions now primarily deal with Emulator state changes
  # that are NOT sequence execution (which is in CommandExecutor)

  # --- C0 Control Code Handlers (Delegated from process_character via ControlCodes) ---

  # Internal helper, called by ControlCodes
  @doc false
  @spec handle_lf(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_lf(%__MODULE__{} = emulator) do
    # Moves cursor down one line.
    # If at bottom of scroll region, scrolls region up.
    # If Linefeed/Newline Mode (LNM) is set (CSI 20 h), also perform CR.
    %{cursor: cursor, scroll_region: scroll_region, mode_state: mode_state} =
      emulator

    active_buffer = get_active_buffer(emulator)
    {_cur_x, cur_y} = cursor.position
    _height = ScreenBuffer.get_height(active_buffer)

    {_scroll_top, scroll_bottom} =
      ScreenBuffer.get_scroll_region_boundaries(active_buffer)

    new_cursor =
      if cur_y == scroll_bottom do
        # Scroll up if at bottom of region
        new_active_buffer =
          ScreenBuffer.scroll_up(active_buffer, 1, scroll_region)

        _updated_emulator = update_active_buffer(emulator, new_active_buffer)
        cursor
      else
        # Move cursor down
        Manager.move_down(cursor, 1)
      end

    # Handle LNM (move to column 0 if enabled)
    final_cursor =
      if ScreenModes.mode_enabled?(mode_state, :lnm_linefeed_newline) do
        Manager.move_to_col(new_cursor, 0)
      else
        new_cursor
      end

    %{emulator | cursor: final_cursor}
  end

  # Internal helper, called by ControlCodes
  @doc false
  @spec handle_cr(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_cr(%__MODULE__{} = emulator) do
    # Moves cursor to beginning of the current line.
    %{
      emulator
      | cursor: Manager.move_to_col(emulator.cursor, 0),
        last_col_exceeded: false
    }
  end

  # Internal helper, called by ControlCodes
  @doc false
  @spec handle_bs(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_bs(%__MODULE__{} = emulator) do
    # Moves cursor left one position.
    # Stops at the beginning of the line.
    %{
      emulator
      | cursor: Manager.move_left(emulator.cursor, 1),
        last_col_exceeded: false
    }
  end

  # Internal helper, called by ControlCodes
  @doc false
  @spec handle_ht(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  @dialyzer {:nowarn_function, handle_ht: 1}
  def handle_ht(%__MODULE__{} = emulator) do
    # Moves cursor to the next tab stop.
    # If no more tab stops, moves to the last column.
    # Stops if it hits the right margin.
    %{cursor: cursor, tab_stops: tab_stops} = emulator
    active_buffer = get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    {cur_x, _cur_y} = cursor.position

    # Find next tab stop after current position
    next_stops = Enum.filter(tab_stops, fn stop -> stop > cur_x end)

    # Calculate the target column
    target_col =
      if Enum.empty?(next_stops) do
        # Default to last column if no stops found
        width - 1
      else
        # Find the minimum and ensure it's not beyond the last column
        min(Enum.min(next_stops), width - 1)
      end

    %{
      emulator
      | cursor: Manager.move_to_col(cursor, target_col),
        last_col_exceeded: false
    }
  end

  # Internal helper, called by ControlCodes
  @doc false
  @spec handle_so(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_so(%__MODULE__{charset_state: cs} = emulator) do
    # Shift Out: Select G1 character set for GL.
    Logger.debug("Charset: SO (Shift Out) -> Invoking G1")
    %{emulator | charset_state: CharacterSets.invoke_charset(cs, :g1)}
  end

  # Internal helper, called by ControlCodes
  @doc false
  @spec handle_si(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_si(%__MODULE__{charset_state: cs} = emulator) do
    # Shift In: Select G0 character set for GL.
    Logger.debug("Charset: SI (Shift In) -> Invoking G0")
    %{emulator | charset_state: CharacterSets.invoke_charset(cs, :g0)}
  end

  # Internal helper, called by ControlCodes
  @doc false
  @spec handle_bel(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_bel(emulator) do
    Logger.info("BEL received - Sound bell (not implemented visually)")
    # TODO: Implement visual bell or hook for external handler?
    emulator
  end

  # Internal helper, called by ControlCodes
  @doc false
  @spec handle_can(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_can(emulator) do
    Logger.warning(
      "CAN received - Canceling sequence (parser should handle this)"
    )

    # Usually cancels an escape sequence, parser should handle state reset.
    emulator
  end

  # Internal helper, called by ControlCodes
  @doc false
  @spec handle_sub(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_sub(emulator) do
    Logger.warning(
      "SUB received - Treating as error/replacement (parser should handle this)"
    )

    # Often substitutes for invalid characters or cancels sequences.
    emulator
  end

  # --- Escape Sequence Handlers (Called by Parser) ---

  @spec handle_nel(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_nel(%__MODULE__{} = emulator) do
    # NEL (Next Line): Equivalent to CR + LF.
    %{cursor: cursor, scroll_region: scroll_region} = emulator
    # Ignore mode_state for NEL
    _mode_state = emulator.mode_state

    active_buffer = get_active_buffer(emulator)

    {_cur_x, cur_y} = cursor.position
    height = ScreenBuffer.get_height(active_buffer)

    {_scroll_top, scroll_bottom} =
      ScreenBuffer.get_scroll_region_boundaries(active_buffer)

    new_cursor_y =
      if cur_y == scroll_bottom do
        # If at bottom, scroll up
        new_active_buffer =
          ScreenBuffer.scroll_up(active_buffer, 1, scroll_region)

        _updated_emulator = update_active_buffer(emulator, new_active_buffer)
        # Y doesn't change relative to scrolled region
        cur_y
      else
        # Otherwise, just move down
        min(cur_y + 1, height - 1)
      end

    # Move to column 0 of the potentially new line
    new_cursor = Manager.move_to(emulator.cursor, 0, new_cursor_y)
    %{emulator | cursor: new_cursor, last_col_exceeded: false}
  end

  @spec handle_hts(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_hts(%__MODULE__{cursor: cursor} = emulator) do
    # HTS (Horizontal Tabulation Set): Set tab stop at current cursor column.
    {x, _y} = cursor.position
    Logger.debug("HTS: Setting tab stop at column #{x}")
    %{emulator | tab_stops: MapSet.put(emulator.tab_stops, x)}
  end

  @spec handle_ri(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_ri(%__MODULE__{} = emulator) do
    # RI (Reverse Index): Move cursor up one line, scrolling down if at top of region.
    %{cursor: cursor, scroll_region: scroll_region} = emulator
    active_buffer = get_active_buffer(emulator)

    {_cur_x, cur_y} = cursor.position

    {scroll_top, _scroll_bottom} =
      ScreenBuffer.get_scroll_region_boundaries(active_buffer)

    new_cursor =
      if cur_y == scroll_top do
        # Scroll down if at top of region
        new_active_buffer =
          ScreenBuffer.scroll_down(active_buffer, 1, scroll_region)

        # Update the emulator with the scrolled buffer BEFORE updating cursor
        _updated_emulator = update_active_buffer(emulator, new_active_buffer)
        # Cursor position doesn't change
        cursor
      else
        # Just move up 1 if possible (but not past the top of screen)
        Manager.move_up(cursor, 1)
      end

    %{emulator | cursor: new_cursor}
  end

  # --- DECSC/DECRC Handlers (Called by Parser or CommandExecutor) ---

  # Internal helper
  @doc false
  @spec handle_decsc(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_decsc(%__MODULE__{} = emulator) do
    Logger.debug("DECSC: Saving state")
    # Capture relevant state fields into a map
    state_to_save = %{
      cursor: emulator.cursor,
      style: emulator.style,
      charset_state: emulator.charset_state,
      mode_state: emulator.mode_state,
      scroll_region: emulator.scroll_region,
      tab_stops: emulator.tab_stops
      # last_col_exceeded is usually NOT saved by DECSC
      # origin_mode (DECOM) is part of mode_state
    }

    # Prepend the saved state to the stack (list)
    new_stack = [state_to_save | emulator.state_stack]
    %{emulator | state_stack: new_stack}
  end

  # Internal helper
  @doc false
  @spec handle_decrc(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_decrc(%__MODULE__{} = emulator) do
    Logger.debug("DECRC: Restoring state")

    case emulator.state_stack do
      [] ->
        Logger.warning("DECRC called with empty state stack")
        # Return unchanged if stack is empty
        emulator

      [restored_state | new_stack] ->
        # Restore the state from the popped map
        # Note: Use the values directly from the map
        %{
          emulator
          | state_stack: new_stack,
            cursor: restored_state.cursor,
            style: restored_state.style,
            charset_state: restored_state.charset_state,
            mode_state: restored_state.mode_state,
            scroll_region: restored_state.scroll_region,
            tab_stops: restored_state.tab_stops
            # Do NOT restore screen buffer content or last_col_exceeded
        }
    end
  end

  # --- Private Helpers ---

  # Calculates default tab stops (every 8 columns, 0-based)
  defp default_tab_stops(width) do
    # Set default tab stops every 8 columns (1-based index for stops)
    # 0-based calculation, stop at 1, 9, 17, ...
    Enum.to_list(0..div(width - 1, 8))
    |> Enum.map(&(&1 * 8))
  end

  # Helper to map gset index (0-3) to atom (:g0-:g3)
  @dialyzer {:nowarn_function, index_to_gset_atom: 1}
  defp index_to_gset_atom(0), do: :g0
  defp index_to_gset_atom(1), do: :g1
  defp index_to_gset_atom(2), do: :g2
  defp index_to_gset_atom(3), do: :g3
  # Should not happen
  defp index_to_gset_atom(_), do: nil

  # Helper to map charset designation code to charset atom
  @dialyzer {:nowarn_function, map_charset_code_to_atom: 1}
  defp map_charset_code_to_atom(charset_code) do
    case charset_code do
      ?B ->
        :us_ascii

      ?0 ->
        :dec_special_graphics

      # United Kingdom
      ?A ->
        :uk

      ?4 ->
        :dutch

      ?5 ->
        :finnish

      # Alternative code
      ?C ->
        :finnish

      # Alternative code
      ?f ->
        :finnish

      ?R ->
        :french

      ?Q ->
        :french_canadian

      ?K ->
        :german

      ?Y ->
        :italian

      ?Z ->
        :spanish

      ?H ->
        :swedish

      # Alternative code
      ?7 ->
        :swedish

      ?= ->
        :swiss

      ?> ->
        :dec_technical

      # Add other mappings as needed (e.g., Cyrillic, Greek, Hebrew)
      _ ->
        Logger.warning(
          "Unhandled charset designation code: #{<<charset_code>>} (#{charset_code})"
        )

        # Return nil for unhandled codes
        nil
    end
  end

  @doc """
  Handles the RIS (Reset to Initial State) escape sequence.
  This resets the terminal to its initial state, including clearing the screen,
  resetting cursor position, character sets, modes, etc.
  """
  @spec handle_ris(t()) :: t()
  @dialyzer {:nowarn_function, handle_ris: 1}
  def handle_ris(%__MODULE__{} = emulator) do
    # Get current dimensions
    active_buffer = get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    scrollback_limit = active_buffer.scrollback_limit

    # Create a fresh emulator with current dimensions
    # but reset all other state
    new_emulator = new(width, height, scrollback_limit: scrollback_limit)

    # Preserve plugin manager from original emulator
    %{new_emulator | plugin_manager: emulator.plugin_manager}
  end

  @doc """
  Handles the IND (Index) escape sequence.
  Moves cursor down one line, scrolling if necessary.
  Similar to LF but doesn't reset column position.
  """
  @spec handle_ind(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def handle_ind(%__MODULE__{} = emulator) do
    %{cursor: cursor, scroll_region: scroll_region} = emulator
    active_buffer = get_active_buffer(emulator)

    {_cur_x, cur_y} = cursor.position

    {_scroll_top, scroll_bottom} =
      ScreenBuffer.get_scroll_region_boundaries(active_buffer)

    if cur_y == scroll_bottom do
      # At bottom of region, need to scroll
      new_active_buffer =
        ScreenBuffer.scroll_up(active_buffer, 1, scroll_region)

      # Update buffer but keep cursor position
      update_active_buffer(emulator, new_active_buffer)
    else
      # Not at bottom, just move cursor down
      %{emulator | cursor: Manager.move_down(cursor, 1)}
    end
  end

  @doc """
  Resizes the emulator's screen buffers.

  ## Parameters

  * `emulator` - The emulator to resize
  * `new_width` - New width in columns
  * `new_height` - New height in rows

  ## Returns

  Updated emulator with resized buffers
  """
  @spec resize(
          Raxol.Terminal.Emulator.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Raxol.Terminal.Emulator.t()
  @dialyzer {:nowarn_function, resize: 3}
  def resize(%__MODULE__{} = emulator, new_width, new_height) do
    # Resize both buffers
    new_main_buffer =
      ScreenBuffer.resize(emulator.main_screen_buffer, new_width, new_height)

    new_alt_buffer =
      ScreenBuffer.resize(
        emulator.alternate_screen_buffer,
        new_width,
        new_height
      )

    # Update tab stops for the new width
    new_tab_stops = default_tab_stops(new_width)

    # Return updated emulator
    %{
      emulator
      | main_screen_buffer: new_main_buffer,
        alternate_screen_buffer: new_alt_buffer,
        tab_stops: new_tab_stops
    }
  end

  @doc """
  Gets the current cursor position from the emulator.

  ## Parameters

  * `emulator` - The emulator to get the cursor position from

  ## Returns

  A tuple {x, y} representing the cursor position
  """
  @spec get_cursor_position(Raxol.Terminal.Emulator.t()) ::
          {non_neg_integer(), non_neg_integer()}
  @dialyzer {:nowarn_function, get_cursor_position: 1}
  def get_cursor_position(%__MODULE__{} = emulator) do
    emulator.cursor.position
  end

  @doc """
  Gets whether the cursor is currently visible.

  ## Parameters

  * `emulator` - The emulator to check

  ## Returns

  Boolean indicating if cursor is visible
  """
  @spec get_cursor_visible(Raxol.Terminal.Emulator.t()) :: boolean()
  def get_cursor_visible(%__MODULE__{} = emulator) do
    emulator.cursor.state != :hidden
  end
end
