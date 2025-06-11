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
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ANSI.TerminalState
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.ModeManager
  alias Raxol.Plugins.Manager.Core
  alias Raxol.Terminal.Buffer.Manager, as: BufferManager
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ANSI.CharacterSets.StateManager
  alias Raxol.Terminal.Command.Manager, as: CommandManager
  alias Raxol.Terminal.Buffer.Operations, as: BufferOps
  alias Raxol.Terminal.Tab.Manager, as: TabManager
  alias Raxol.Terminal.Output.Manager, as: OutputManager
  alias Raxol.Terminal.Window.Manager, as: WindowManager
  alias Raxol.Terminal.Hyperlink.Manager, as: HyperlinkManager
  alias Raxol.Terminal.Color.Manager, as: ColorManager
  alias Raxol.Terminal.History.Manager, as: HistoryManager
  alias Raxol.Terminal.State.Manager, as: StateManager
  alias Raxol.Terminal.Scrollback.Manager, as: ScrollbackManager
  alias Raxol.Terminal.Screen.Manager, as: ScreenManager
  alias Raxol.Terminal.Parser.StateManager, as: ParserStateManager
  alias Raxol.Terminal.Plugin.Manager, as: PluginManager
  alias Raxol.Terminal.Mode.Manager, as: ModeManager
  alias Raxol.Terminal.Charset.Manager, as: CharsetManager
  alias Raxol.Terminal.Formatting.Manager, as: FormattingManager
  alias Raxol.Terminal.TerminalState.Manager, as: TerminalStateManager
  alias Raxol.Terminal.Buffer.UnifiedManager

  require Raxol.Core.Runtime.Log
  require Logger

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
  Creates a new terminal emulator instance.

  Can be called with:
  - `new(opts_map)` where `opts_map` is a map containing `:width`, `:height`, and other options.
  - `new(width, height, opts_keyword_list)`
  - `new(width, height, session_id, client_options)` (delegates to the keyword list version)

  ## Options (Keyword list or Map)

    * `:width` - Terminal width (default: 80)
    * `:height` - Terminal height (default: 24)
    * `:scrollback` - Maximum number of scrollback lines (default: from config or 1000)
    * `:memorylimit` - Memory limit (default: 1_000_000)
    * `:max_command_history` - Max command history (default: 100)
    * `:plugin_manager` - A pre-initialized `Raxol.Plugins.Manager.Core` struct.
    * `:session_id` - A session identifier string.
    * `:client_options` - A map of client-specific options.

  """
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  @impl Raxol.Terminal.EmulatorBehaviour
  def new() do
    new(80, 24)
  end

  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  @impl Raxol.Terminal.EmulatorBehaviour
  def new(width, height) do
    new(width, height, [])
  end

  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  @impl Raxol.Terminal.EmulatorBehaviour
  def new(width, height, opts)
      when is_integer(width) and is_integer(height) and is_list(opts) do
    # Get default scrollback from config if not provided in opts
    config_scrollback_limit =
      Application.get_env(:raxol, :terminal, [])
      |> Keyword.get(:scrollback_lines, 1000)

    # Resolve options, ensuring correct types and defaults
    actual_width = if is_integer(width) and width > 0, do: width, else: 80
    actual_height = if is_integer(height) and height > 0, do: height, else: 24
    scrollback_limit = Keyword.get(opts, :scrollback, config_scrollback_limit)
    memory_limit = Keyword.get(opts, :memorylimit, 1_000_000)
    max_command_history_opt = Keyword.get(opts, :max_command_history, 100)
    session_id = Keyword.get(opts, :session_id)
    client_options = Keyword.get(opts, :client_options, %{})

    # Allow plugin_manager to be passed in via opts
    plugin_manager_struct =
      case Keyword.get(opts, :plugin_manager) do
        nil ->
          pm_struct = Core.new()
          pm_struct

        passed_pm_struct
        when is_struct(passed_pm_struct, Raxol.Plugins.Manager.Core) ->
          passed_pm_struct

        _invalid_pm ->
          # Fallback or raise error if an invalid :plugin_manager was passed
          Raxol.Core.Runtime.Log.warning(
            "Invalid :plugin_manager passed to Emulator.new/3, using default."
          )

          pm_struct = Core.new()
          pm_struct
      end

    initial_cursor = Manager.new()
    initial_mode_manager = ModeManager.new()
    initial_charset_state = CharacterSets.new()
    initial_parser_state = %Raxol.Terminal.Parser.State{state: :ground}
    command_manager = CommandManager.new()

    # Initialize buffers through BufferManager, using actual_width and actual_height
    {main_buffer, alternate_buffer} =
      initialize_buffers(
        actual_width,
        actual_height,
        scrollback_limit
      )

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
      tab_stops: BufferManager.default_tab_stops(actual_width),
      last_col_exceeded: false,
      plugin_manager: plugin_manager_struct,
      parser_state: initial_parser_state,
      # Store remaining opts
      options:
        Enum.reduce(
          [
            :session_id,
            :client_options,
            :scrollback,
            :memorylimit,
            :max_command_history,
            :plugin_manager
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
      width: actual_width,
      height: actual_height,
      state: StateManager.new(),
      command: command_manager,
      window_state: %{
        title: "",
        icon_name: "",
        size: {actual_width, actual_height},
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

  @impl true
  def new(width, height, session_id, client_options) do
    new(width, height, session_id: session_id, client_options: client_options)
  end

  # Delegate screen operations to ScreenManager
  defdelegate get_active_buffer(emulator), to: ScreenManager
  defdelegate update_active_buffer(emulator, new_buffer), to: ScreenManager
  defdelegate switch_buffer(emulator), to: ScreenManager
  defdelegate initialize_buffers(width, height, scrollback_limit), to: ScreenManager
  defdelegate resize_buffers(emulator, new_width, new_height), to: ScreenManager
  defdelegate get_buffer_type(emulator), to: ScreenManager
  defdelegate set_buffer_type(emulator, type), to: ScreenManager

  # Delegate parser state operations to ParserStateManager
  defdelegate get_parser_state(emulator), to: ParserStateManager, as: :get_state
  defdelegate update_parser_state(emulator, state), to: ParserStateManager, as: :update_state
  defdelegate get_parser_state_name(emulator), to: ParserStateManager, as: :get_state_name
  defdelegate set_parser_state_name(emulator, state_name), to: ParserStateManager, as: :set_state_name
  defdelegate reset_parser_to_ground(emulator), to: ParserStateManager, as: :reset_to_ground
  defdelegate in_ground_state?(emulator), to: ParserStateManager
  defdelegate in_escape_state?(emulator), to: ParserStateManager
  defdelegate in_control_sequence_state?(emulator), to: ParserStateManager

  @doc """
  Processes input from the user, handling both regular characters and escape sequences.
  Delegates to Raxol.Terminal.InputHandler.process_terminal_input/2.
  """
  @spec process_input(t(), String.t()) :: {t(), String.t()}
  @impl Raxol.Terminal.EmulatorBehaviour
  def process_input(%__MODULE__{} = emulator, input) when is_binary(input) do
    Raxol.Terminal.InputHandler.process_terminal_input(emulator, input)
  end

  def process_input(emulator, input) do
    require Logger

    Logger.error(
      "Invalid arguments to process_input/2: emulator=#{inspect(emulator)}, input=#{inspect(input)}"
    )

    {emulator, "[ERROR: Invalid input to process_input]"}
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
    IO.inspect(emulator, label: "DEBUG: emulator IN update_active_buffer")
    IO.inspect(new_buffer, label: "DEBUG: new_buffer IN update_active_buffer")

    result =
      %{emulator | main_screen_buffer: new_buffer}

    IO.inspect(result, label: "DEBUG: result FROM update_active_buffer")
    result
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
    {cur_x, cur_y} = get_cursor_position(emulator)
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

  @impl true
  def get_cursor_visible(%__MODULE__{cursor: cursor}),
    do: CursorManager.is_visible?(cursor)

  # --- Private Helpers ---

  @doc """
  Checks if the cursor is below the scroll region and scrolls up if necessary.
  Called after operations like LF, IND, NEL that might move the cursor off-screen.
  Version called with no specific target Y - checks current cursor position.
  """
  @spec maybe_scroll(t()) :: t()
  def maybe_scroll(%__MODULE__{} = emulator) do
    BufferOps.maybe_scroll(emulator)
  end

  @doc """
  Moves the cursor down one line (index operation).

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  Updated emulator with cursor moved down
  """
  @spec index(t()) :: t()
  def index(%__MODULE__{} = emulator) do
    {x, y} = get_cursor_position(emulator)
    new_y = y + 1

    # Check if we need to scroll
    if new_y >= emulator.height do
      maybe_scroll(emulator)
    else
      set_cursor_position(emulator, {x, new_y}, emulator.width, emulator.height)
    end
  end

  @doc """
  Moves the cursor to the next line.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  Updated emulator with cursor moved to next line
  """
  @spec next_line(t()) :: t()
  def next_line(%__MODULE__{} = emulator) do
    {_x, _y} = get_cursor_position(emulator)
    # Implementation
  end

  @doc """
  Sets a horizontal tab stop at the current cursor position.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  Updated emulator with new tab stop
  """
  @spec set_horizontal_tab(t()) :: t()
  def set_horizontal_tab(%__MODULE__{} = emulator) do
    {x, _y} = get_cursor_position(emulator)
    new_tab_stops = MapSet.put(emulator.tab_stops, x)
    %{emulator | tab_stops: new_tab_stops}
  end

  @doc """
  Moves the cursor up one line (reverse index operation).

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  Updated emulator with cursor moved up
  """
  @spec reverse_index(t()) :: t()
  def reverse_index(%__MODULE__{} = emulator) do
    {x, y} = get_cursor_position(emulator)
    new_y = max(0, y - 1)
    set_cursor_position(emulator, {x, new_y}, emulator.width, emulator.height)
  end

  @doc """
  Enqueues output to be sent to the terminal.

  ## Parameters

  * `emulator` - The emulator instance
  * `output` - The output string to enqueue

  ## Returns

  Updated emulator with output enqueued
  """
  @spec enqueue_output(t(), String.t()) :: t()
  def enqueue_output(%__MODULE__{} = emulator, output) when is_binary(output) do
    new_output_buffer = emulator.output_buffer <> output
    %{emulator | output_buffer: new_output_buffer}
  end

  # Delegate cursor operations to CursorManager
  @impl Raxol.Terminal.EmulatorBehaviour
  def get_cursor_position(%__MODULE__{cursor: cursor}),
    do: CursorManager.get_position(cursor)

  defdelegate set_cursor_position(emulator, position, width, height),
    to: CursorManager,
    as: :move_to

  defdelegate move_cursor_up(emulator, lines \\ 1, width, height),
    to: CursorManager,
    as: :move_up

  defdelegate move_cursor_down(emulator, lines \\ 1, width, height),
    to: CursorManager,
    as: :move_down

  defdelegate move_cursor_left(emulator, columns \\ 1, width, height),
    to: CursorManager,
    as: :move_left

  defdelegate move_cursor_right(emulator, columns \\ 1, width, height),
    to: CursorManager,
    as: :move_right

  defdelegate move_cursor_to_line_start(emulator),
    to: CursorManager,
    as: :move_to_line_start

  defdelegate move_cursor_to_column(emulator, column, width, height),
    to: CursorManager,
    as: :move_to

  defdelegate move_cursor_to(emulator, position, width, height),
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

  def get_state_stack(%__MODULE__{state_stack: stack}), do: stack

  def update_state_stack(%__MODULE__{} = emulator, state_stack) do
    %{emulator | state_stack: state_stack}
  end

  # scroll_region
  def get_scroll_region(%__MODULE__{scroll_region: scroll_region}),
    do: scroll_region

  def update_scroll_region(%__MODULE__{} = emulator, scroll_region) do
    %{emulator | scroll_region: scroll_region}
  end

  # last_col_exceeded
  def get_last_col_exceeded(%__MODULE__{last_col_exceeded: last_col_exceeded}),
    do: last_col_exceeded

  def update_last_col_exceeded(%__MODULE__{} = emulator, last_col_exceeded) do
    %{emulator | last_col_exceeded: last_col_exceeded}
  end

  # hyperlink_url
  def get_hyperlink_url(%__MODULE__{current_hyperlink_url: url}), do: url

  def update_hyperlink_url(%__MODULE__{} = emulator, url) do
    %{emulator | current_hyperlink_url: url}
  end

  # window_title
  def get_window_title(%__MODULE__{window_title: title}), do: title

  def update_window_title(%__MODULE__{} = emulator, title) do
    %{emulator | window_title: title}
  end

  # icon_name
  def get_icon_name(%__MODULE__{icon_name: name}), do: name

  def update_icon_name(%__MODULE__{} = emulator, name) do
    %{emulator | icon_name: name}
  end

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

  @doc """
  Designates a character set for the specified G-set.
  """
  def designate_charset(emulator, g_set, charset) do
    %{
      emulator
      | designated_charsets:
          Map.put(emulator.designated_charsets, g_set, charset)
    }
  end

  @doc """
  Resets the emulator to its initial state.
  """
  def reset_to_initial_state(emulator) do
    %{
      emulator
      | cursor: %{x: 0, y: 0},
        scroll_region: {0, emulator.height - 1},
        tab_stops: default_tab_stops(emulator.width),
        designated_charsets: %{},
        single_shift: nil,
        final_byte: nil,
        intermediates_buffer: [],
        params_buffer: [],
        payload_buffer: []
    }
  end

  @doc """
  Clears the scrollback buffer.
  """
  def clear_scrollback(emulator) do
    %{emulator | scrollback_buffer: []}
  end

  defp default_tab_stops(width) do
    # Generate tab stops every 8 columns
    for i <- 0..(width - 1), rem(i, 8) == 0, do: i
  end

  def get_dimensions(%__MODULE__{width: width, height: height}),
    do: {width, height}

  @doc """
  Updates the emulator's color palette with new colors.
  """
  def set_colors(emulator, colors) do
    %{emulator | color_palette: colors}
  end

  @doc """
  Gets the current color palette.
  """
  def get_colors(emulator) do
    emulator.color_palette
  end

  # Delegate buffer operations to BufferOps
  defdelegate resize(emulator, new_width, new_height), to: BufferOps
  defdelegate maybe_scroll(emulator), to: BufferOps
  defdelegate index(emulator), to: BufferOps
  defdelegate next_line(emulator), to: BufferOps
  defdelegate reverse_index(emulator), to: BufferOps

  # Delegate tab operations to TabManager
  defdelegate set_horizontal_tab(emulator), to: TabManager
  defdelegate clear_tab_stop(emulator), to: TabManager
  defdelegate clear_all_tab_stops(emulator), to: TabManager
  defdelegate get_next_tab_stop(emulator), to: TabManager

  # Delegate output operations to OutputManager
  defdelegate enqueue_output(emulator, output), to: OutputManager
  defdelegate flush_output(emulator), to: OutputManager
  defdelegate clear_output_buffer(emulator), to: OutputManager
  defdelegate get_output_buffer(emulator), to: OutputManager
  defdelegate enqueue_control_sequence(emulator, sequence), to: OutputManager

  # Delegate window operations to WindowManager
  defdelegate set_window_title(emulator, title), to: WindowManager
  defdelegate set_icon_name(emulator, name), to: WindowManager
  defdelegate set_window_size(emulator, width, height), to: WindowManager
  defdelegate set_window_position(emulator, x, y), to: WindowManager
  defdelegate set_stacking_order(emulator, order), to: WindowManager
  defdelegate get_window_state(emulator), to: WindowManager
  defdelegate save_window_size(emulator), to: WindowManager
  defdelegate restore_window_size(emulator), to: WindowManager

  # Delegate hyperlink operations to HyperlinkManager
  defdelegate get_hyperlink_url(emulator), to: HyperlinkManager
  defdelegate update_hyperlink_url(emulator, url), to: HyperlinkManager
  defdelegate get_hyperlink_state(emulator), to: HyperlinkManager
  defdelegate update_hyperlink_state(emulator, state), to: HyperlinkManager
  defdelegate clear_hyperlink_state(emulator), to: HyperlinkManager
  defdelegate create_hyperlink(emulator, url, id, params), to: HyperlinkManager

  # Delegate color operations to ColorManager
  defdelegate set_colors(emulator, colors), to: ColorManager
  defdelegate get_colors(emulator), to: ColorManager
  defdelegate get_color(emulator, index), to: ColorManager
  defdelegate set_color(emulator, index, color), to: ColorManager
  defdelegate reset_colors(emulator), to: ColorManager
  defdelegate color_to_rgb(emulator, index), to: ColorManager

  # Delegate history operations to HistoryManager
  defdelegate get_command_history(emulator), to: HistoryManager
  defdelegate add_to_history(emulator, command), to: HistoryManager
  defdelegate clear_history(emulator), to: HistoryManager
  defdelegate get_history_command(emulator, index), to: HistoryManager
  defdelegate search_history(emulator, prefix), to: HistoryManager
  defdelegate get_command_buffer(emulator), to: HistoryManager
  defdelegate update_command_buffer(emulator, buffer), to: HistoryManager
  defdelegate get_max_history_size(emulator), to: HistoryManager
  defdelegate set_max_history_size(emulator, size), to: HistoryManager
  defdelegate get_last_key_event(emulator), to: HistoryManager
  defdelegate update_last_key_event(emulator, event), to: HistoryManager

  # Delegate state operations to StateManager
  defdelegate get_state_stack(emulator), to: StateManager
  defdelegate update_state_stack(emulator, state_stack), to: StateManager
  defdelegate get_mode_manager(emulator), to: StateManager
  defdelegate update_mode_manager(emulator, mode_manager), to: StateManager
  defdelegate get_charset_state(emulator), to: StateManager
  defdelegate update_charset_state(emulator, charset_state), to: StateManager
  defdelegate get_scroll_region(emulator), to: StateManager
  defdelegate update_scroll_region(emulator, scroll_region), to: StateManager
  defdelegate get_last_col_exceeded(emulator), to: StateManager
  defdelegate update_last_col_exceeded(emulator, last_col_exceeded), to: StateManager
  defdelegate reset_to_initial_state(emulator), to: StateManager

  # Delegate scrollback operations to ScrollbackManager
  defdelegate get_scrollback_buffer(emulator), to: ScrollbackManager
  defdelegate add_to_scrollback(emulator, line), to: ScrollbackManager
  defdelegate clear_scrollback(emulator), to: ScrollbackManager
  defdelegate get_scrollback_limit(emulator), to: ScrollbackManager
  defdelegate set_scrollback_limit(emulator, limit), to: ScrollbackManager
  defdelegate get_scrollback_range(emulator, start, count), to: ScrollbackManager
  defdelegate get_scrollback_size(emulator), to: ScrollbackManager
  defdelegate scrollback_empty?(emulator), to: ScrollbackManager

  # Delegate plugin operations to PluginManager
  defdelegate get_plugin_manager(emulator), to: PluginManager, as: :get_manager
  defdelegate update_plugin_manager(emulator, manager), to: PluginManager, as: :update_manager
  defdelegate initialize_plugin(emulator, plugin_name, config), to: PluginManager
  defdelegate call_plugin_hook(emulator, plugin_name, hook_name, args), to: PluginManager, as: :call_hook
  defdelegate plugin_loaded?(emulator, plugin_name), to: PluginManager
  defdelegate get_loaded_plugins(emulator), to: PluginManager
  defdelegate unload_plugin(emulator, plugin_name), to: PluginManager
  defdelegate get_plugin_config(emulator, plugin_name), to: PluginManager
  defdelegate update_plugin_config(emulator, plugin_name, config), to: PluginManager

  # Delegate mode operations to ModeManager
  defdelegate get_mode_manager(emulator), to: ModeManager, as: :get_manager
  defdelegate update_mode_manager(emulator, manager), to: ModeManager, as: :update_manager
  defdelegate set_mode(emulator, mode), to: ModeManager
  defdelegate reset_mode(emulator, mode), to: ModeManager
  defdelegate mode_set?(emulator, mode), to: ModeManager
  defdelegate get_set_modes(emulator), to: ModeManager
  defdelegate reset_all_modes(emulator), to: ModeManager
  defdelegate save_modes(emulator), to: ModeManager
  defdelegate restore_modes(emulator), to: ModeManager

  # Delegate charset operations to CharsetManager
  defdelegate get_charset_state(emulator), to: CharsetManager, as: :get_state
  defdelegate update_charset_state(emulator, state), to: CharsetManager, as: :update_state
  defdelegate designate_charset(emulator, g_set, charset), to: CharsetManager
  defdelegate invoke_g_set(emulator, g_set), to: CharsetManager
  defdelegate get_current_g_set(emulator), to: CharsetManager
  defdelegate get_designated_charset(emulator, g_set), to: CharsetManager
  defdelegate reset_charset_state(emulator), to: CharsetManager, as: :reset_state
  defdelegate apply_single_shift(emulator, g_set), to: CharsetManager
  defdelegate get_single_shift(emulator), to: CharsetManager

  # Delegate formatting operations to FormattingManager
  defdelegate get_style(emulator), to: FormattingManager
  defdelegate update_style(emulator, style), to: FormattingManager
  defdelegate set_attribute(emulator, attribute), to: FormattingManager
  defdelegate reset_attribute(emulator, attribute), to: FormattingManager
  defdelegate set_foreground(emulator, color), to: FormattingManager
  defdelegate set_background(emulator, color), to: FormattingManager
  defdelegate reset_all_attributes(emulator), to: FormattingManager
  defdelegate get_foreground(emulator), to: FormattingManager
  defdelegate get_background(emulator), to: FormattingManager
  defdelegate attribute_set?(emulator, attribute), to: FormattingManager
  defdelegate get_set_attributes(emulator), to: FormattingManager

  # Delegate terminal state operations to TerminalStateManager
  defdelegate get_state_stack(emulator), to: TerminalStateManager
  defdelegate update_state_stack(emulator, state_stack), to: TerminalStateManager
  defdelegate save_state(emulator), to: TerminalStateManager
  defdelegate restore_state(emulator), to: TerminalStateManager
  defdelegate has_saved_states?(emulator), to: TerminalStateManager
  defdelegate get_saved_states_count(emulator), to: TerminalStateManager
  defdelegate clear_saved_states(emulator), to: TerminalStateManager
  defdelegate get_current_state(emulator), to: TerminalStateManager
  defdelegate update_current_state(emulator, state), to: TerminalStateManager

  defp initialize_buffers(width, height, scrollback_limit) do
    {:ok, main_buffer} = UnifiedManager.new(width, height, scrollback_limit)
    {:ok, alt_buffer} = UnifiedManager.new(width, height, scrollback_limit)
    {main_buffer, alt_buffer}
  end
end
