defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  Manages the state of the terminal emulator, including screen buffer,
  cursor position, attributes, and modes.

  ## Scrollback Limit Configuration

  The scrollback buffer limit can be set via application config:

      config :raxol, :terminal, scrollback_lines: 1000

  Or overridden per emulator instance by passing the `:scrollback` option to `new/3`:

      Emulator.new(80, 24, scrollback: 2000)

  """

  @behaviour Raxol.Terminal.EmulatorBehaviour

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Operations
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ANSI.TerminalState
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.ModeManager
  alias Raxol.Terminal.Parser
  alias Raxol.Plugins.Manager.Core
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ControlCodes
  alias Raxol.Terminal.Style.Manager, as: StyleManager
  alias Raxol.Terminal.Buffer.Manager, as: BufferManager
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ANSI.Processor
  alias Raxol.Terminal.ANSI.CharacterSets.StateManager
  alias Raxol.Terminal.Command.Manager, as: CommandManager

  require Raxol.Core.Runtime.Log

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
          saved_cursor: Manager.t() | nil,
          scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
          style: TextFormatting.text_style(),
          memory_limit: non_neg_integer(),
          charset_state: CharacterSets.charset_state(),
          mode_manager: ModeManager.t(),
          plugin_manager: Manager.t(Core),
          options: map(),
          current_hyperlink_url: String.t() | nil,
          window_title: String.t() | nil,
          icon_name: String.t() | nil,
          tab_stops: MapSet.t(),
          output_buffer: String.t(),
          color_palette: map(),
          cursor_style: cursor_style_type(),
          parser_state: map(),
          command_history: list(),
          max_command_history: non_neg_integer(),
          current_command_buffer: String.t(),
          last_key_event: map() | nil,
          width: non_neg_integer(),
          height: non_neg_integer(),
          state: StateManager.t(),
          command: CommandManager.t(),
          # Window state for window manipulation commands
          window_state: %{
            title: String.t(),
            icon_name: String.t(),
            size: {non_neg_integer(), non_neg_integer()},
            position: {non_neg_integer(), non_neg_integer()},
            stacking_order: :normal | :maximized | :iconified,
            iconified: boolean(),
            maximized: boolean(),
            previous_size: {non_neg_integer(), non_neg_integer()} | nil
          },
          scrollback_buffer: list(),
          cwd: String.t() | nil,
          current_hyperlink: map() | nil,
          default_palette: map() | nil,
          scrollback_limit: non_neg_integer(),
          session_id: String.t() | nil,
          client_options: map(),
          # --- Added for Sixel graphics state tracking ---
          sixel_state: map() | nil
        }

  # NOTE: The `:position` field is NOT a top-level field of the Emulator struct.
  # To access the window position, use `emulator.window_state.position`.
  # Do NOT use `emulator.position` -- this will cause a KeyError.

  # Use Manager struct
  defstruct cursor: Manager.new(),
            # TODO: This might need updating to save Manager state?
            saved_cursor: nil,
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
            plugin_manager: Core.new(),
            # Add parser state
            parser_state: %Raxol.Terminal.Parser.State{state: :ground},
            options: %{},
            current_hyperlink_url: nil,
            window_title: nil,
            icon_name: nil,
            output_buffer: "",
            color_palette: %{},
            cursor_style: :blinking_block,
            # Command History
            command_history: [],
            # Default, overridden in new/3
            max_command_history: 100,
            current_command_buffer: "",
            last_key_event: nil,
            width: 80,
            height: 24,
            state: StateManager.new(),
            command: CommandManager.new(),
            # Window state for window manipulation commands
            window_state: %{
              title: "",
              icon_name: "",
              size: {80, 24},
              position: {0, 0},
              stacking_order: :normal,
              iconified: false,
              maximized: false,
              previous_size: nil
            },
            scrollback_buffer: [],
            cwd: nil,
            current_hyperlink: nil,
            default_palette: nil,
            scrollback_limit: 1000,
            session_id: nil,
            client_options: %{},
            # --- Added for Sixel graphics state tracking ---
            sixel_state: nil

  @doc """
  Creates a new terminal emulator instance with the specified dimensions and options.

  ## Options

    * `:scrollback` - Maximum number of scrollback lines (default: from config or 1000)
    * `:memorylimit` - Memory limit (default: 1_000_000)
    * `:max_command_history` - Max command history (default: 100)

  ## Examples

      iex> emulator = Raxol.Terminal.Emulator.new(80, 24, scrollback: 2000)
      iex> emulator.scrollback_limit
      2000

  """
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  @dialyzer {:nowarn_function, new: 3}
  @impl Raxol.Terminal.EmulatorBehaviour
  def new(width \\ 80, height \\ 24, opts \\ []) do
    # Get default from config if not provided
    config_limit =
      Application.get_env(:raxol, :terminal, [])
      |> Keyword.get(:scrollback_lines, 1000)

    scrollback_limit = Keyword.get(opts, :scrollback, config_limit)
    memory_limit = Keyword.get(opts, :memorylimit, 1_000_000)
    max_command_history_opt = Keyword.get(opts, :max_command_history, 100)
    # Extract session_id and client_options from opts
    session_id = Keyword.get(opts, :session_id)
    client_options = Keyword.get(opts, :client_options, %{})

    plugin_manager = Core.new()
    initial_cursor = Manager.new()
    initial_mode_manager = ModeManager.new()
    initial_charset_state = CharacterSets.new()
    initial_parser_state = %Raxol.Terminal.Parser.State{state: :ground}
    command_manager = CommandManager.new()

    # Initialize buffers through BufferManager
    {main_buffer, alternate_buffer} =
      BufferManager.initialize_buffers(width, height, scrollback_limit)

    %__MODULE__{
      cursor: initial_cursor,
      saved_cursor: nil,
      style: TextFormatting.new(),
      charset_state: initial_charset_state,
      mode_manager: initial_mode_manager,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,
      active_buffer_type: :main,
      state_stack: TerminalState.new(),
      scroll_region: nil,
      memory_limit: memory_limit,
      tab_stops: BufferManager.default_tab_stops(width),
      last_col_exceeded: false,
      plugin_manager: plugin_manager,
      parser_state: initial_parser_state,
      # Store remaining opts
      options:
        Enum.reduce(
          [
            :session_id,
            :client_options,
            :scrollback,
            :memorylimit,
            :max_command_history
          ],
          opts,
          fn key, acc -> Keyword.delete(acc, key) end
        ),
      current_hyperlink_url: nil,
      window_title: nil,
      icon_name: nil,
      output_buffer: "",
      color_palette: %{},
      cursor_style: :blinking_block,
      command_history: [],
      max_command_history: max_command_history_opt,
      current_command_buffer: "",
      last_key_event: nil,
      width: width,
      height: height,
      state: StateManager.new(),
      command: command_manager,
      window_state: %{
        title: "",
        icon_name: "",
        size: {width, height},
        position: {0, 0},
        stacking_order: :normal,
        iconified: false,
        maximized: false,
        previous_size: nil
      },
      scrollback_buffer: [],
      cwd: nil,
      current_hyperlink: nil,
      default_palette: nil,
      scrollback_limit: scrollback_limit,
      session_id: session_id,
      client_options: client_options,
      sixel_state: nil
    }
  end

  @doc """
  Creates a new terminal emulator instance with specified dimensions, session ID, and client options.
  This function is required by the TerminalChannel.
  """
  @impl Raxol.Terminal.EmulatorBehaviour
  def new(width, height, session_id, client_options) do
    # Call the existing new/3, passing through session_id and client_options.
    emulator_instance =
      new(width, height, session_id: session_id, client_options: client_options)

    {:ok, emulator_instance}
  end

  @doc """
  Returns the currently active screen buffer (:main or :alternate).
  """
  @spec get_active_buffer(t()) :: ScreenBuffer.t()
  @impl Raxol.Terminal.EmulatorBehaviour
  def get_active_buffer(%__MODULE__{active_buffer_type: :main} = emulator) do
    Raxol.Core.Runtime.Log.debug(
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
        Raxol.Core.Runtime.Log.error(
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
  Delegates to Raxol.Terminal.InputHandler.process_terminal_input/2.
  """
  @spec process_input(t(), String.t()) :: {t(), String.t()}
  @impl Raxol.Terminal.EmulatorBehaviour
  def process_input(%__MODULE__{} = emulator, input) when is_binary(input) do
    Raxol.Terminal.InputHandler.process_terminal_input(emulator, input)
  end

  # --- Active Buffer Helpers ---

  @doc "Updates the currently active screen buffer."
  @spec update_active_buffer(
          Raxol.Terminal.Emulator.t(),
          Raxol.Terminal.ScreenBuffer.t()
        ) :: Raxol.Terminal.Emulator.t()
  @impl Raxol.Terminal.EmulatorBehaviour
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
  # Logic moved to InputHandler which calls Parser, which calls Commands.Executor for CSI.

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
  @impl Raxol.Terminal.EmulatorBehaviour
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
    new_tab_stops = BufferManager.default_tab_stops(new_width)

    # Clamp cursor position
    {cur_x, cur_y} = Raxol.Terminal.Emulator.get_cursor_position(emulator)
    clamped_x = min(max(cur_x, 0), new_width - 1)
    clamped_y = min(max(cur_y, 0), new_height - 1)
    new_cursor = %{emulator.cursor | position: {clamped_x, clamped_y}}

    # Clamp or reset scroll region
    new_scroll_region =
      case emulator.scroll_region do
        {top, bottom}
        when is_integer(top) and is_integer(bottom) and top < bottom and
               top >= 0 and bottom < new_height ->
          {top, bottom}

        _ ->
          nil
      end

    # Return updated emulator
    %{
      emulator
      | main_screen_buffer: new_main_buffer,
        alternate_screen_buffer: new_alt_buffer,
        tab_stops: new_tab_stops,
        cursor: new_cursor,
        scroll_region: new_scroll_region,
        width: new_width,
        height: new_height
    }
  end

  @doc """
  Gets whether the cursor is currently visible.

  ## Parameters

  * `emulator` - The emulator to check

  ## Returns

  Boolean indicating if cursor is visible
  """
  @spec get_cursor_visible(Raxol.Terminal.Emulator.t()) :: boolean()
  @impl Raxol.Terminal.EmulatorBehaviour
  def get_cursor_visible(%__MODULE__{} = emulator) do
    emulator.cursor.state != :hidden
  end

  # --- Private Helpers ---

  @doc false
  # Helper to calculate the position where the next character should be written
  # and the subsequent cursor position, considering autowrap mode.
  # Returns: {write_x, write_y, next_cursor_x, next_cursor_y, next_last_col_exceeded}
  defp calculate_write_position(%__MODULE__{} = emulator, width) do
    {cursor_x, cursor_y} = Raxol.Terminal.Emulator.get_cursor_position(emulator)
    autowrap_enabled = emulator.mode_manager.auto_wrap
    last_col_exceeded = emulator.last_col_exceeded
    buffer = get_active_buffer(emulator)
    %{width: buffer_width, height: buffer_height} = buffer

    Raxol.Core.Runtime.Log.debug(
      "[calc_write] Input: cursor={#{cursor_x}, #{cursor_y}}, width=#{width}, buffer_w=#{buffer_width}, wrap=#{autowrap_enabled}, last_exceeded=#{last_col_exceeded}"
    )

    result =
      cond do
        # Case 1: Previous character caused wrap flag to be set.
        last_col_exceeded ->
          Raxol.Core.Runtime.Log.debug("[calc_write] Case 1: Last col exceeded")
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
          Raxol.Core.Runtime.Log.debug(
            "[calc_write] Case 2: Exceeds right margin (cursor_x=#{cursor_x}, width=#{width}, buffer_w=#{buffer_width})"
          )

          if autowrap_enabled do
            Raxol.Core.Runtime.Log.debug("[calc_write] Case 2a: Autowrap enabled")
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
            Raxol.Core.Runtime.Log.debug("[calc_write] Case 2b: Autowrap disabled")

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
          Raxol.Core.Runtime.Log.debug("[calc_write] Case 3: Normal write")
          write_x = cursor_x
          write_y = cursor_y
          next_cursor_x = min(cursor_x + width, buffer_width)
          next_cursor_y = cursor_y

          next_last_col_exceeded =
            autowrap_enabled and cursor_x + width >= buffer_width

          {write_x, write_y, next_cursor_x, next_cursor_y,
           next_last_col_exceeded}
      end

    Raxol.Core.Runtime.Log.debug(
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
    BufferManager.maybe_scroll(emulator)
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

  # Delegate to BufferManager
  def get_active_buffer(emulator), do: BufferManager.get_active_buffer(emulator)

  def update_active_buffer(emulator, new_buffer),
    do: BufferManager.update_active_buffer(emulator, new_buffer)

  def maybe_scroll(emulator), do: BufferManager.maybe_scroll(emulator)

  # Delegate cursor operations to CursorManager
  defdelegate get_cursor_position(emulator),
    to: CursorManager,
    as: :get_position

  defdelegate set_cursor_position(emulator, position),
    to: CursorManager,
    as: :set_position

  defdelegate is_cursor_visible?(emulator), to: CursorManager, as: :is_visible?

  defdelegate set_cursor_visibility(emulator, visible),
    to: CursorManager,
    as: :set_visibility

  defdelegate get_cursor_style(emulator), to: CursorManager, as: :get_style

  defdelegate set_cursor_style(emulator, style),
    to: CursorManager,
    as: :set_style

  defdelegate save_cursor_state(emulator), to: CursorManager, as: :save_state

  defdelegate restore_cursor_state(emulator),
    to: CursorManager,
    as: :restore_state

  # Delegate cursor movement operations
  defdelegate move_cursor_up(emulator, lines \\ 1),
    to: CursorManager,
    as: :move_up

  defdelegate move_cursor_down(emulator, lines \\ 1),
    to: CursorManager,
    as: :move_down

  defdelegate move_cursor_left(emulator, columns \\ 1),
    to: CursorManager,
    as: :move_left

  defdelegate move_cursor_right(emulator, columns \\ 1),
    to: CursorManager,
    as: :move_right

  defdelegate move_cursor_to_line_start(emulator),
    to: CursorManager,
    as: :move_to_line_start

  defdelegate move_cursor_to_column(emulator, column),
    to: CursorManager,
    as: :move_to_column

  defdelegate move_cursor_to(emulator, position),
    to: CursorManager,
    as: :move_to

  # Delegate state management operations to StateManager
  defdelegate get_mode_manager(emulator),
    to: StateManager,
    as: :get_mode_manager

  defdelegate update_mode_manager(emulator, mode_manager),
    to: StateManager,
    as: :update_mode_manager

  defdelegate get_charset_state(emulator),
    to: StateManager,
    as: :get_charset_state

  defdelegate update_charset_state(emulator, charset_state),
    to: StateManager,
    as: :update_charset_state

  defdelegate get_state_stack(emulator), to: StateManager, as: :get_state_stack

  defdelegate update_state_stack(emulator, state_stack),
    to: StateManager,
    as: :update_state_stack

  defdelegate get_scroll_region(emulator),
    to: StateManager,
    as: :get_scroll_region

  defdelegate update_scroll_region(emulator, scroll_region),
    to: StateManager,
    as: :update_scroll_region

  defdelegate get_last_col_exceeded(emulator),
    to: StateManager,
    as: :get_last_col_exceeded

  defdelegate update_last_col_exceeded(emulator, last_col_exceeded),
    to: StateManager,
    as: :update_last_col_exceeded

  defdelegate get_hyperlink_url(emulator),
    to: StateManager,
    as: :get_hyperlink_url

  defdelegate update_hyperlink_url(emulator, url),
    to: StateManager,
    as: :update_hyperlink_url

  defdelegate get_window_title(emulator),
    to: StateManager,
    as: :get_window_title

  defdelegate update_window_title(emulator, title),
    to: StateManager,
    as: :update_window_title

  defdelegate get_icon_name(emulator), to: StateManager, as: :get_icon_name

  defdelegate update_icon_name(emulator, name),
    to: StateManager,
    as: :update_icon_name

  defdelegate save_state(emulator), to: StateManager, as: :save_state
  defdelegate restore_state(emulator), to: StateManager, as: :restore_state

  # Delegate command management operations to CommandManager
  defdelegate get_command_buffer(emulator),
    to: CommandManager,
    as: :get_command_buffer

  defdelegate update_command_buffer(emulator, buffer),
    to: CommandManager,
    as: :update_command_buffer

  defdelegate get_command_history(emulator),
    to: CommandManager,
    as: :get_command_history

  defdelegate add_to_history(emulator, command),
    to: CommandManager,
    as: :add_to_history

  defdelegate clear_history(emulator), to: CommandManager, as: :clear_history

  defdelegate get_last_key_event(emulator),
    to: CommandManager,
    as: :get_last_key_event

  defdelegate update_last_key_event(emulator, event),
    to: CommandManager,
    as: :update_last_key_event

  defdelegate process_key_event(emulator, key_event),
    to: CommandManager,
    as: :process_key_event

  defdelegate get_history_command(emulator, index),
    to: CommandManager,
    as: :get_history_command

  defdelegate search_history(emulator, prefix),
    to: CommandManager,
    as: :search_history

  defdelegate update_max_history(emulator, new_size),
    to: CommandManager,
    as: :update_max_history

  @doc """
  Clears the scrollback buffer.
  """
  @spec clear_scrollback(t()) :: t()
  def clear_scrollback(emulator) do
    %{emulator | scrollback_buffer: []}
  end
end
