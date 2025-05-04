defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  Manages the state of the terminal emulator, including screen buffer,
  cursor position, attributes, and modes.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Operations
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.ScreenModes
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ANSI.TerminalState
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.Parser
  alias Raxol.Plugins.PluginManager
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ControlCodes
  alias Raxol.Terminal.Style.Manager, as: StyleManager

  require Logger

  @dialyzer [
    {:nowarn_function,
     [
       resize: 3,
       get_cursor_position: 1
     ]}
  ]

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
          cursor_style: cursor_style_type(),
          parser_state: Parser.State.t()
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
            # Add parser state
            parser_state: %Parser.State{},
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
    # Initialize Parser State
    initial_parser_state = %Parser.State{}

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
      plugin_manager: plugin_manager,
      # Assign parser state
      parser_state: initial_parser_state,
      options: %{},
      current_hyperlink_url: nil,
      window_title: nil,
      icon_name: nil,
      output_buffer: "",
      cursor_style: :blinking_block
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
    # Get the current parser state from the emulator
    current_parser_state = emulator.parser_state
    # IO.inspect({:process_input_before_parse, emulator, current_parser_state, input}, label: "DEBUG_EMULATOR")

    # Call the public parse_chunk function
    parse_result = Parser.parse_chunk(emulator, current_parser_state, input)
    # IO.inspect({:process_input_after_parse, parse_result}, label: "DEBUG_EMULATOR")

    # parse_chunk returns {final_emulator_state, final_parser_state}
    # Line 205 (approx):
    {final_emulator_state, final_parser_state} = parse_result

    # Update the emulator's parser state with the final state from the parser
    emulator_with_updated_parser_state = %{final_emulator_state | parser_state: final_parser_state}

    output_to_send = emulator_with_updated_parser_state.output_buffer
    final_emulator_state_no_output = %{emulator_with_updated_parser_state | output_buffer: ""}

    # Return the final state and the collected output
    # --- DEBUG LOG ---
    # IO.inspect({:proc_input_return, final_emulator_state_no_output.cursor.position}, label: "DEBUG")
    # --- END DEBUG LOG ---
    {final_emulator_state_no_output, output_to_send}
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
      when (char_codepoint >= 0 and char_codepoint <= 31) or char_codepoint == 127 do
    # Handle C0 Control Codes and DEL using the ControlCodes module
    ControlCodes.handle_c0(emulator, char_codepoint)
  end

  @doc """
  Processes a single printable character codepoint.
  Writes the character to the buffer at the calculated position and updates the cursor position.
  Handles autowrap logic.
  """
  def process_character(%__MODULE__{} = emulator, char_codepoint) do
    # Get character width FIRST
    char = <<char_codepoint::utf8>>
    char_width = Raxol.Terminal.CharacterHandling.get_char_width(char)

    # 1. Determine where to write the character based on current state
    # CALL calculate_write_position/2
    {write_y, write_x, next_cursor_y, next_cursor_x, next_last_col_exceeded} = calculate_write_position(emulator, char_width)
    # We need the emulator state *before* the cursor moves for writing.
    # Let's assume calculate_write_position doesn't modify the state itself, only calculates values.
    emulator_state_before_write = emulator # Use the original state passed in

    # 2. Write the character to the buffer at (write_x, write_y)
    # --- CHANGE: Use the state *before* potential calculation side effects (if any) ---
    buffer = get_active_buffer(emulator_state_before_write)
    style = emulator_state_before_write.style # Use current style
    updated_buffer = Operations.write_char(buffer, write_x, write_y, char, style)
    updated_emulator = put_active_buffer(emulator_state_before_write, updated_buffer)

    # 4. Move cursor to the calculated NEXT position and update flag
    # --- CHANGE: Use values directly from calculate_write_position/2 return ---
    updated_cursor = Manager.move_to(updated_emulator.cursor, next_cursor_x, next_cursor_y)
    emulator_after_cursor_move = %{updated_emulator | cursor: updated_cursor, last_col_exceeded: next_last_col_exceeded}

    # 5. Handle potential scrolling based on next_cursor_y
    # --- CHANGE: Use next_cursor_y from the calculation ---
    final_emulator = maybe_scroll(emulator_after_cursor_move, next_cursor_y)

    final_emulator
  end

  # --- Command Handling Delegates (Called by Parser) ---

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
  defp calculate_write_position(emulator, width) do # width here is char_width
    {cursor_x, cursor_y} = emulator.cursor.position
    autowrap_enabled = emulator.mode_state[:auto_wrap]
    last_col_exceeded = emulator.last_col_exceeded
    # Get buffer dimensions needed for bounds checks
    buffer = get_active_buffer(emulator)
    %{width: buffer_width, height: buffer_height} = buffer # Add this

    cond do
      # Case 1: Previous character caused wrap flag to be set.
      last_col_exceeded ->
        # --- FIX START ---
        # Conceptually move to start of next line FIRST
        target_y = cursor_y + 1

        write_x = 0
        write_y = target_y # Target Y for write

        # Calculate cursor position AFTER writing char at {0, target_y}
        next_cursor_x = min(width, buffer_width) # Starts at col 0, add char_width (`width`)
        next_cursor_y = target_y

        # Does this new char itself reach/exceed end?
        next_last_col_exceeded = autowrap_enabled and (next_cursor_x >= buffer_width)

        # Return calculated positions. The last_col_exceeded flag was consumed.
        {write_y, write_x, next_cursor_y, next_cursor_x, next_last_col_exceeded}
        # --- FIX END ---

      # Case 2: Cursor is at the last column.
      cursor_x == buffer_width - 1 -> # Use buffer_width
        if autowrap_enabled do
          # Write at current {cursor_y, cursor_x}.
          # Cursor stays conceptually at end of line, wrap happens on next char.
          # Flag is set.
          {cursor_y, cursor_x, cursor_y, cursor_x, true}
        else
          # Autowrap disabled: Write at current pos, cursor stays.
          {cursor_y, cursor_x, cursor_y, cursor_x, false}
        end

      # Case 3: Normal character write within the line.
      true ->
        write_y = cursor_y
        write_x = cursor_x # Write happens at current cursor pos

        # Calculate next cursor position
        next_cursor_x = min(cursor_x + width, buffer_width) # Clamp X
        next_cursor_y = cursor_y
        # Set flag if write *reaches or exceeds* the end boundary
        next_last_col_exceeded = autowrap_enabled and (cursor_x + width >= buffer_width)
        {write_y, write_x, next_cursor_y, next_cursor_x, next_last_col_exceeded}
    end
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
      # FIX: Don't clamp cursor. Return state after scroll.
      scrolled_emulator = Raxol.Terminal.Commands.Screen.scroll_up(emulator, 1)
      scrolled_emulator
    else
      emulator # Cursor within region or above, no scroll needed
    end
  end

  # --- Removed old calculation logic ---

  # TODO: Add more complex handlers as needed

  # Fallback: Ignore unknown characters
  def process_control_character(emulator, _char_codepoint), do: emulator

  # --- Helper Functions ---

  @doc """
  Puts the appropriate buffer (:main or :alt) into the emulator state.
  """
  defp put_active_buffer(%__MODULE__{active_buffer_type: :main} = emulator, buffer)
       when is_struct(buffer, ScreenBuffer) do
    %{emulator | main_screen_buffer: buffer}
  end

  defp put_active_buffer(%__MODULE__{active_buffer_type: :alternate} = emulator, buffer)
       when is_struct(buffer, ScreenBuffer) do
    %{emulator | alternate_screen_buffer: buffer}
  end

  @doc """
  Gets the currently active buffer (:main or :alt) from the emulator state.
  """
  def get_active_buffer(%__MODULE__{active_buffer_type: :main, main_screen_buffer: buffer}),
    do: buffer

  def get_active_buffer(%__MODULE__{active_buffer_type: :alternate, alternate_screen_buffer: buffer}),
    do: buffer

  # --- Core Processing Logic ---

  @doc """
  Handles the maybe_scroll logic after character processing or cursor movement.
  Checks if the cursor's Y position is outside the scroll region (or buffer height) and scrolls if necessary.
  Returns the potentially updated emulator state.
  """
  def maybe_scroll(%__MODULE__{} = emulator, next_cursor_y) do
    buffer = get_active_buffer(emulator)
    buffer_height = ScreenBuffer.get_height(buffer)
    {scroll_top, scroll_bottom_exclusive} = get_effective_scroll_region(emulator, buffer)

    cond do
      next_cursor_y < scroll_top ->
        emulator # Cursor target is above the scroll region

      next_cursor_y >= buffer_height ->
        scroll_amount = next_cursor_y - buffer_height + 1
        # Use effective scroll region bottom for scroll operation boundary
        scroll_bottom_inclusive = scroll_bottom_exclusive - 1
        scrolled_buffer =
          Buffer.Operations.scroll_up(buffer, scroll_amount, scroll_top, scroll_bottom_inclusive)
        # --- FIX: Don't modify cursor. Return emulator with scrolled buffer. ---
        put_active_buffer(emulator, scrolled_buffer)

      true -> # Cursor target is within the buffer bounds (and scroll region)
        emulator
    end
  end

  # --- Command Handling Delegates (Called by Parser) ---

  @doc """
  Determines the effective scroll region based on DECSTBM settings and buffer height.
  Returns {top_row_index, bottom_row_index_exclusive}.
  """
  defp get_effective_scroll_region(emulator, buffer) do
    buffer_height = ScreenBuffer.get_height(buffer)
    case emulator.scroll_region do
      {top, bottom} when is_integer(top) and is_integer(bottom) and top < bottom and top >= 0 and bottom <= buffer_height ->
        # Valid region set
        {top, bottom}
      _ ->
        # No valid region set, use full buffer
        {0, buffer_height}
    end
  end
end
