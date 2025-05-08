defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  Manages the state of the terminal emulator, including screen buffer,
  cursor position, attributes, and modes.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Operations
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ANSI.TerminalState
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.ModeManager
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
          mode_manager: ModeManager.t(),
          plugin_manager: PluginManager.t(),
          options: map(),
          current_hyperlink_url: String.t() | nil,
          window_title: String.t() | nil,
          icon_name: String.t() | nil,
          tab_stops: MapSet.t(),
          output_buffer: String.t(),
          cursor_style: cursor_style_type(),
          parser_state: Parser.State.t(),
          command_history: list(),
          max_command_history: non_neg_integer(),
          current_command_buffer: String.t()
        }

  # Use Manager struct
  defstruct cursor: Manager.new(),
            # TODO: This might need updating to save Manager state?
            saved_cursor: {1, 1},
            style: TextFormatting.new(),
            # Manages G0-G3 designation and invocation
            charset_state: CharacterSets.new(),
            # Tracks various modes (like DECCKM, DECOM)
            mode_manager: ModeManager.new(),
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
            cursor_style: :blinking_block,
            # Command History
            command_history: [],
            # Default, overridden in new/3
            max_command_history: 100,
            current_command_buffer: ""

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
    max_command_history_opt = Keyword.get(opts, :max_command_history, 100)
    plugin_manager = PluginManager.new()
    # Initialize Manager
    initial_cursor = Manager.new()
    _initial_buffer = ScreenBuffer.new(width, height, scrollback_limit)
    # Initialize both buffers
    main_buffer = ScreenBuffer.new(width, height, scrollback_limit)
    # Alternate buffer usually has no scrollback
    alternate_buffer = ScreenBuffer.new(width, height, 0)
    initial_mode_manager = ModeManager.new()
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
      mode_manager: initial_mode_manager,
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
      cursor_style: :blinking_block,
      # Initialize command history fields
      command_history: [],
      max_command_history: max_command_history_opt,
      current_command_buffer: ""
    }
  end

  @doc """
  Returns the currently active screen buffer (:main or :alternate).
  """
  @spec get_active_buffer(t()) :: ScreenBuffer.t()
  def get_active_buffer(emulator) do
    Logger.debug(
      "[get_active_buffer] Type: #{inspect(emulator.active_buffer_type)}, Keys: #{inspect(Map.keys(emulator))}"
    )

    # Defensive check instead of case statement
    type = emulator.active_buffer_type
    # Assuming type must be :alternate if not :main
    if type == :main do
      emulator.main_screen_buffer
    else
      # Check key exists before accessing, to provide a better error if needed
      if Map.has_key?(emulator, :alternate_screen_buffer) do
        emulator.alternate_screen_buffer
      else
        # This should NOT happen based on Emulator.new, but helps diagnose
        Logger.error(
          "[get_active_buffer] CRITICAL: Type is :alternate but :alternate_screen_buffer key is missing!"
        )

        # Raise a more informative error or return nil/main buffer?
        # Raising here to make the problem explicit if this path is hit.
        raise KeyError, key: :alternate_screen_buffer, term: emulator
      end
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
      iex> {emulator, _} = Raxol.Terminal.Emulator.process_input(emulator, "\e[1;31mRed\e[0m Text")
      iex> {x, y} = emulator.cursor.position
      iex> x # Length of "Red Text" (8 chars) + starting at 1 = 9
      9
      iex> emulator.style.foreground # Should be reset by \e[0m
      nil

  """
  @spec process_input(t(), String.t()) :: {t(), String.t()}
  def process_input(emulator, input) when is_binary(input) do
    # Get the current parser state from the emulator
    current_parser_state = emulator.parser_state

    # === BRACKETED PASTE CHECK ===
    if ModeManager.mode_enabled?(emulator.mode_manager, :bracketed_paste) do
      wrapped_paste = <<"\e[200~", input::binary, "\e[201~">>
      state_after_paste_event = %{emulator | output_buffer: ""}
      {state_after_paste_event, wrapped_paste}
    else
      # Call the public parse_chunk function (if not in bracketed paste mode)
      parse_result = Parser.parse_chunk(emulator, current_parser_state, input)

      # Inspect the raw result from the parser
      # IO.inspect(parse_result, label: "[Emulator.process_input] Parser.parse_chunk returned:")

      {final_emulator, final_parser_state} = parse_result

      # Directly update the parser state on the result and return
      final_emulator_updated = %{
        final_emulator
        | parser_state: final_parser_state
      }

      # For debugging, inspect right before return
      # IO.inspect(final_emulator_updated.charset_state, label: "[Emulator.process_input simplified] Returning charset_state:")
      # IO.inspect(final_emulator_updated.charset_state, label: "[Emulator.process_input] Returning charset_state:")

      # Restore original logic
      output_to_send = final_emulator_updated.output_buffer

      final_emulator_state_no_output = %{
        final_emulator_updated
        | output_buffer: ""
      }

      {final_emulator_state_no_output, output_to_send}
    end
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

  # Removed process_character/2 - Moved to InputHandler

  # Removed process_printable_character/2 - Moved to InputHandler

  # --- CSI Sequence Handling ---
  # TODO: Move CSI handling logic to InputHandler

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
  # Helper to calculate the position where the next character should be written
  # and the subsequent cursor position, considering autowrap mode.
  # Returns: {write_x, write_y, next_cursor_x, next_cursor_y, next_last_col_exceeded}
  defp calculate_write_position(%__MODULE__{} = emulator, width) do
    {cursor_x, cursor_y} = emulator.cursor.position
    autowrap_enabled = emulator.mode_manager.auto_wrap
    last_col_exceeded = emulator.last_col_exceeded
    buffer = get_active_buffer(emulator)
    %{width: buffer_width, height: buffer_height} = buffer

    Logger.debug(
      "[calc_write] Input: cursor={#{cursor_x}, #{cursor_y}}, width=#{width}, buffer_w=#{buffer_width}, wrap=#{autowrap_enabled}, last_exceeded=#{last_col_exceeded}"
    )

    result =
      cond do
        # Case 1: Previous character caused wrap flag to be set.
        last_col_exceeded ->
          Logger.debug("[calc_write] Case 1: Last col exceeded")
          target_y = cursor_y + 1
          write_x = 0
          write_y = target_y
          # Start at col 0, add char width
          next_cursor_x = min(width, buffer_width)
          next_cursor_y = target_y

          next_last_col_exceeded =
            autowrap_enabled and next_cursor_x >= buffer_width

          {write_x, write_y, next_cursor_x, next_cursor_y,
           next_last_col_exceeded}

        # Case 2: Current write would exceed right margin
        # Note: Using > width-1 means hitting the last column counts
        cursor_x + width > buffer_width - 1 ->
          Logger.debug(
            "[calc_write] Case 2: Exceeds right margin (cursor_x=#{cursor_x}, width=#{width}, buffer_w=#{buffer_width})"
          )

          if autowrap_enabled do
            Logger.debug("[calc_write] Case 2a: Autowrap enabled")
            # Write at current pos (may be clipped by write_char), SET flag
            # Cursor ADVANCES conceptually for next char wrap
            write_x = cursor_x
            write_y = cursor_y
            # Cursor stays visually, flag indicates wrap needed
            next_cursor_x = cursor_x
            next_cursor_y = cursor_y
            # Set flag for next character
            next_last_col_exceeded = true

            {write_x, write_y, next_cursor_x, next_cursor_y,
             next_last_col_exceeded}
          else
            Logger.debug("[calc_write] Case 2b: Autowrap disabled")

            # Autowrap disabled: Write at current pos (may clip), cursor stays at last valid pos.
            write_x = cursor_x
            write_y = cursor_y
            # Clamp cursor to last column
            next_cursor_x = buffer_width - 1
            next_cursor_y = cursor_y
            next_last_col_exceeded = false

            {write_x, write_y, next_cursor_x, next_cursor_y,
             next_last_col_exceeded}
          end

        # Case 3: Normal character write within the line.
        true ->
          Logger.debug("[calc_write] Case 3: Normal write")
          write_x = cursor_x
          write_y = cursor_y
          next_cursor_x = min(cursor_x + width, buffer_width)
          next_cursor_y = cursor_y

          next_last_col_exceeded =
            autowrap_enabled and cursor_x + width >= buffer_width

          {write_x, write_y, next_cursor_x, next_cursor_y,
           next_last_col_exceeded}
      end

    Logger.debug(
      "[calc_write] Output: write={#{elem(result, 0)}, #{elem(result, 1)}}, next_cursor={#{elem(result, 2)}, #{elem(result, 3)}}, next_last_exceeded=#{elem(result, 4)}"
    )

    result
  end

  # Calculates default tab stops (every 8 columns, 0-based)
  defp default_tab_stops(width) do
    # Set default tab stops every 8 columns (1-based index for stops)
    # 0-based calculation, stop at 1, 9, 17, ...
    Enum.to_list(0..div(width - 1, 8))
    |> Enum.map(&(&1 * 8))
    # Ensure it's a MapSet
    |> MapSet.new()
  end

  # (handle_ris moved to ControlCodes)

  @doc """
  Checks if the cursor is below the scroll region and scrolls up if necessary.
  Called after operations like LF, IND, NEL that might move the cursor off-screen.
  Version called with no specific target Y - checks current cursor position.
  """
  @spec maybe_scroll(t()) :: t()
  def maybe_scroll(%__MODULE__{} = emulator) do
    {cursor_col, cursor_row} = get_cursor_position(emulator)
    active_buffer = get_active_buffer(emulator)
    buffer_height = ScreenBuffer.get_height(active_buffer)

    {top_margin, bottom_margin} =
      case emulator.scroll_region do
        {top, bottom}
        when is_integer(top) and top >= 0 and is_integer(bottom) and
               bottom > top ->
          {top, min(bottom, buffer_height - 1)}

        # Default: full buffer
        _ ->
          {0, buffer_height - 1}
      end

    Logger.debug(
      "[maybe_scroll] Check: cursor={#{cursor_col}, #{cursor_row}}, region={#{top_margin}, #{bottom_margin}}, scroll?=#{cursor_row > bottom_margin}"
    )

    if cursor_row > bottom_margin do
      Logger.debug("[maybe_scroll] SCROLLING TRIGGERED!")

      scroll_region_tuple = {top_margin, bottom_margin}

      # Calls ScreenBuffer.scroll_up (which calls Scroller.scroll_up)
      # Scrolls up by 1 line
      {buffer_after_scroll_cells, scrolled_lines} =
        ScreenBuffer.scroll_up(active_buffer, 1, scroll_region_tuple)

      # Adds scrolled line(s) to scrollback
      new_scrollback = scrolled_lines ++ active_buffer.scrollback

      limited_scrollback =
        Enum.take(new_scrollback, active_buffer.scrollback_limit)

      buffer_with_scrollback = %{
        buffer_after_scroll_cells
        | scrollback: limited_scrollback
      }

      # Update emulator state (use original cursor, let caller handle movement)
      emulator_with_scrolled_buffer =
        update_active_buffer(emulator, buffer_with_scrollback)

      # Return state with scrolled buffer but original cursor
      emulator_with_scrolled_buffer
    else
      Logger.debug("[maybe_scroll] No scroll needed.")
      # No scroll needed
      emulator
    end
  end

  # TODO: Add more complex handlers as needed

  # Fallback: Ignore unknown characters
  # def process_control_character(emulator, _char_codepoint), do: emulator # Seems unused/obsolete

  # --- Helper Functions ---

  @doc """
  Puts the appropriate buffer (:main or :alt) into the emulator state.
  """
  defp put_active_buffer(
         %__MODULE__{active_buffer_type: :main} = emulator,
         buffer
       )
       when is_struct(buffer, ScreenBuffer) do
    %{emulator | main_screen_buffer: buffer}
  end

  defp put_active_buffer(
         %__MODULE__{active_buffer_type: :alternate} = emulator,
         buffer
       )
       when is_struct(buffer, ScreenBuffer) do
    %{emulator | alternate_screen_buffer: buffer}
  end

  @doc """
  Gets the currently active buffer (:main or :alt) from the emulator state.
  """
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

  # --- Core Processing Logic ---

  # Removed maybe_scroll/2 as it seemed unused and potentially confusing
  # If needed later, re-evaluate its purpose and implementation clearly.

  # --- Command Handling Delegates (Called by Parser) ---

  @doc """
  Determines the effective scroll region based on DECSTBM settings and buffer height.
  Returns {top_row_index, bottom_row_index_exclusive}.
  """
  defp get_effective_scroll_region(emulator, buffer) do
    buffer_height = ScreenBuffer.get_height(buffer)

    case emulator.scroll_region do
      {top, bottom}
      when is_integer(top) and is_integer(bottom) and top < bottom and top >= 0 and
             bottom <= buffer_height ->
        # Valid region set
        {top, bottom}

      _ ->
        # No valid region set, use full buffer
        {0, buffer_height}
    end
  end
end
