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
  alias Raxol.Terminal.Parser
  alias Raxol.Plugins.PluginManager

  require Logger

  @dialyzer [
    {:nowarn_function,
     [
       resize: 3,
       get_cursor_position: 1
     ]}
  ]

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
  @compile {:unused_attr, :us}

  # Escape character
  @esc 27

  # Define escape_char, even if not used currently
  @escape_char @esc

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
  Returns the currently active screen buffer (:main or :alternate).
  """
  @spec get_active_buffer(t()) :: ScreenBuffer.t()
  def get_active_buffer(emulator) do
    case emulator.active_buffer_type do
      :main -> emulator.main_screen_buffer
      :alternate -> emulator.alternate_screen_buffer
    end
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
    initial_parser_state = %Raxol.Terminal.Parser.State{}
    # Calls parse_loop recursively
    updated_emulator_state = Parser.parse_loop(emulator, initial_parser_state, input)

    output_to_send = updated_emulator_state.output_buffer
    final_emulator_state = %{updated_emulator_state | output_buffer: ""}

    # Return the final state and the collected output
    {final_emulator_state, output_to_send}
  end

  # --- Active Buffer Helpers ---

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
    case char_codepoint do
      # Ignore NUL
      @nul ->
        emulator

      @bel ->
        Raxol.Terminal.ControlCodes.handle_bel(emulator)

      @bs_char ->
        Raxol.Terminal.ControlCodes.handle_bs(emulator)

      @ht ->
        Raxol.Terminal.ControlCodes.handle_ht(emulator)

      # Also handles VT and FF currently
      @lf ->
        Raxol.Terminal.ControlCodes.handle_lf(emulator)

      # Treat VT like LF for now
      @vt ->
        Raxol.Terminal.ControlCodes.handle_lf(emulator)

      # Treat FF like LF for now
      @ff ->
        Raxol.Terminal.ControlCodes.handle_lf(emulator)

      @cr_char ->
        Raxol.Terminal.ControlCodes.handle_cr(emulator)

      @so ->
        Raxol.Terminal.ControlCodes.handle_so(emulator)

      @si ->
        Raxol.Terminal.ControlCodes.handle_si(emulator)

      @can_char ->
        Raxol.Terminal.ControlCodes.handle_can(emulator)

      @sub_char ->
        Raxol.Terminal.ControlCodes.handle_sub(emulator)

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
    # Handle DEL (Delete) -> Currently Ignored
    Logger.debug("DEL received, ignoring")
    emulator
  end

  def process_character(emulator, char_codepoint) do
    active_buffer = get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)

    # Map character based on current charset state
    mapped_char = CharacterSets.translate_char(emulator.charset_state, char_codepoint)

    # Determine write position and next cursor state based on autowrap
    {write_y, write_x, next_cursor_y, next_cursor_x, next_last_col_exceeded} =
      calculate_write_position(emulator, width)

    # Write to the active buffer
    updated_active_buffer =
      ScreenBuffer.write_char(
        active_buffer,
        write_x, # Use calculated write coords
        write_y,
        <<mapped_char::utf8>>,
        emulator.style
      )

    # Update cursor state
    new_cursor_state = Manager.move_to(emulator.cursor, next_cursor_x, next_cursor_y)

    # Update the emulator state, then check for scroll
    emulator
    |> update_active_buffer(updated_active_buffer)
    |> Map.put(:cursor, new_cursor_state)
    |> Map.put(:last_col_exceeded, next_last_col_exceeded)
    |> maybe_scroll()
  end

  # --- Command Handling Delegates (Called by Parser) ---
  # These functions now primarily deal with Emulator state changes
  # that are NOT sequence execution (which is in CommandExecutor)

  # --- C0 Control Code Handlers (Delegated from process_character via ControlCodes) ---

  # (handle_lf moved to ControlCodes)
  # (handle_cr moved to ControlCodes)
  # (handle_bs moved to ControlCodes)
  # (handle_ht moved to ControlCodes)
  # (handle_so moved to ControlCodes)
  # (handle_si moved to ControlCodes)

  # --- Other ESC Sequence Handlers (Moved to ControlCodes) ---

  # (handle_ind moved to ControlCodes)
  # (handle_nel moved to ControlCodes)
  # (handle_hts moved to ControlCodes)
  # (handle_ri moved to ControlCodes)
  # (handle_decsc moved to ControlCodes)
  # (handle_decrc moved to ControlCodes)

  # --- Parameterized Command Handlers (Called by Parser/CommandExecutor) ---
  # These modify the Emulator state based on parsed CSI, OSC, etc. commands.

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

  # --- Private Helpers ---

  @doc false
  # Calculates the position to write the next character and the resulting
  # cursor position, handling DECAWM (autowrap).
  # Returns {write_y, write_x, next_cursor_y, next_cursor_x, next_last_col_exceeded}
  defp calculate_write_position(emulator, width) do
    {cursor_x, cursor_y} = emulator.cursor.position
    autowrap_enabled = emulator.mode_state.auto_wrap
    last_col_exceeded = emulator.last_col_exceeded

    result = cond do
      # Case 1: Previous character caused wrap flag to be set.
      last_col_exceeded ->
        # Conceptual cursor is {cursor_y + 1, 0}. Write there.
        # Next cursor position is {cursor_y + 1, 1}.
        {cursor_y + 1, 0, cursor_y + 1, 1, false}

      # Case 2: Cursor is at the last column (width - 1).
      cursor_x == width - 1 ->
        if autowrap_enabled do
          {cursor_y, cursor_x, cursor_y + 1, 0, true}
        else
          {cursor_y, cursor_x, cursor_y, cursor_x, false}
        end

      # Case 3: Normal character write.
      true ->
        {cursor_y, cursor_x, cursor_y, cursor_x + 1, false}
    end

    result
  end

  # Calculates default tab stops (every 8 columns, 0-based)
  defp default_tab_stops(width) do
    # Set default tab stops every 8 columns (1-based index for stops)
    # 0-based calculation, stop at 1, 9, 17, ...
    Enum.to_list(0..div(width - 1, 8))
    |> Enum.map(&(&1 * 8))
    |> MapSet.new() # Ensure it's a MapSet
  end

  # (handle_ris moved to ControlCodes)

  @doc """
  Checks if the cursor is below the scroll region and scrolls up if necessary.
  Called after operations like LF, IND, NEL that might move the cursor off-screen.
  """
  def maybe_scroll(%__MODULE__{} = emulator) do
    {cursor_row, cursor_col} = get_cursor_position(emulator)
    scroll_region = emulator.scroll_region
    active_buffer = get_active_buffer(emulator)

    {_top, bottom} =
      scroll_region || {0, ScreenBuffer.get_height(active_buffer) - 1}

    if cursor_row > bottom do # Check if cursor is *below* the region
      # Perform scroll up using the Screen command module
      scrolled_emulator = Raxol.Terminal.Commands.Screen.scroll_up(emulator, 1)

      # After scrolling, clamp cursor Y to the bottom of the scroll region
      # as the content moved up, the cursor effectively stays at the bottom line.
      new_cursor = CursorManager.move_to(scrolled_emulator.cursor, cursor_col, bottom)
      %{scrolled_emulator | cursor: new_cursor}
    else
      emulator # Cursor within region or above, no scroll needed
    end
  end
end
