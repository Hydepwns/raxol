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
  alias Raxol.Terminal.Buffer.Operations, as: BufferOps
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.Tab.Manager, as: TabManager
  alias Raxol.Terminal.OutputManager
  alias Raxol.Terminal.WindowManager
  alias Raxol.Terminal.HyperlinkManager
  alias Raxol.Terminal.ColorManager
  alias Raxol.Terminal.FormattingManager
  alias Raxol.Terminal.CharsetManager
  alias Raxol.Terminal.State.Manager, as: TerminalStateManager
  alias Raxol.Terminal.ScrollbackManager
  alias Raxol.Terminal.ScreenManager
  alias Raxol.Terminal.Parser.StateManager, as: ParserStateManager
  alias Raxol.Terminal.Emulator.Struct

  @type cursor_style_type ::
          :blinking_block
          | :steady_block
          | :blinking_underline
          | :steady_underline
          | :blinking_bar
          | :steady_bar

  @type t :: Struct.t()

  # NOTE: The `:position` field is NOT a top-level field of the Emulator struct.
  # To access the window position, use `emulator.window_state.position`.
  # Do NOT use `emulator.position` -- this will cause a KeyError.

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
    opts = if Keyword.keyword?(opts), do: Map.new(opts), else: opts
    scrollback_limit = parse_scrollback_limit(opts)
    {main_buffer, alt_buffer} = initialize_buffers(width, height)

    create_emulator(
      width,
      height,
      scrollback_limit,
      opts,
      main_buffer,
      alt_buffer
    )
  end

  defp parse_scrollback_limit(opts) do
    opts[:scrollback] ||
      Application.get_env(:raxol, :terminal, %{})[:scrollback_lines] ||
      1000
  end

  defp initialize_buffers(width, height) do
    main_buffer = ScreenBuffer.new(width, height)
    alt_buffer = ScreenBuffer.new(width, height)
    {main_buffer, alt_buffer}
  end

  defp create_emulator(
         width,
         height,
         scrollback_limit,
         opts,
         main_buffer,
         alt_buffer
       ) do
    %Struct{
      width: width,
      height: height,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alt_buffer,
      active_buffer_type: :main,
      scrollback_limit: scrollback_limit,
      memory_limit: opts[:memorylimit] || 1_000_000,
      max_command_history: opts[:max_command_history] || 100,
      plugin_manager: opts[:plugin_manager] || Core.new(),
      session_id: opts[:session_id],
      client_options: opts[:client_options] || %{},
      state: Raxol.Terminal.State.Manager.new(),
      command: Command.Manager.new(),
      window_title: nil,
      state_stack: [],
      last_col_exceeded: false,
      icon_name: nil,
      current_hyperlink_url: nil
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

  defdelegate initialize_buffers(width, height, scrollback_limit),
    to: ScreenManager

  defdelegate resize_buffers(emulator, new_width, new_height), to: ScreenManager
  defdelegate get_buffer_type(emulator), to: ScreenManager
  defdelegate set_buffer_type(emulator, type), to: ScreenManager

  # Delegate parser state operations to ParserStateManager
  defdelegate get_parser_state(emulator), to: ParserStateManager, as: :get_state

  defdelegate update_parser_state(emulator, state),
    to: ParserStateManager,
    as: :update_state

  defdelegate get_parser_state_name(emulator),
    to: ParserStateManager,
    as: :get_state_name

  defdelegate set_parser_state_name(emulator, state_name),
    to: ParserStateManager,
    as: :set_state_name

  defdelegate reset_parser_to_ground(emulator),
    to: ParserStateManager,
    as: :reset_to_ground

  defdelegate in_ground_state?(emulator), to: ParserStateManager
  defdelegate in_escape_state?(emulator), to: ParserStateManager
  defdelegate in_control_sequence_state?(emulator), to: ParserStateManager

  @doc """
  Processes input from the user, handling both regular characters and escape sequences.
  Delegates to Raxol.Terminal.InputHandler.process_terminal_input/2.
  """
  @spec process_input(t(), String.t()) :: {t(), String.t()}
  @impl Raxol.Terminal.EmulatorBehaviour
  def process_input(%Struct{} = emulator, input) when is_binary(input) do
    Raxol.Terminal.InputHandler.process_terminal_input(emulator, input)
  end

  def process_input(_emulator, _input) do
    Raxol.Core.Runtime.Log.error(
      "Invalid input to process_input: emulator=#{inspect(_emulator)}, input=#{inspect(_input)}"
    )

    {_emulator, "[ERROR: Invalid input to process_input]"}
  end

  # --- Active Buffer Helpers ---

  @doc "Updates the currently active screen buffer."
  @spec update_active_buffer(
          Raxol.Terminal.Emulator.t(),
          Raxol.Terminal.ScreenBuffer.t()
        ) :: Raxol.Terminal.Emulator.t()
  @impl Raxol.Terminal.EmulatorBehaviour
  def update_active_buffer(
        %Struct{active_buffer_type: :main} = emulator,
        new_buffer
      ) do
    %{emulator | main_screen_buffer: new_buffer}
  end

  def update_active_buffer(
        %Struct{active_buffer_type: :alternate} = emulator,
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
  def resize(%Struct{} = emulator, new_width, new_height) do
    new_main_buffer =
      ScreenBuffer.resize(emulator.main_screen_buffer, new_width, new_height)

    new_alt_buffer =
      ScreenBuffer.resize(
        emulator.alternate_screen_buffer,
        new_width,
        new_height
      )

    new_tab_stops = Raxol.Terminal.Buffer.Manager.default_tab_stops(new_width)
    new_cursor = update_cursor_position(emulator, new_width, new_height)
    new_scroll_region = update_scroll_region_for_resize(emulator, new_height)

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

  defp update_cursor_position(emulator, new_width, new_height) do
    {cur_x, cur_y} = get_cursor_position(emulator)
    clamped_x = min(max(cur_x, 0), new_width - 1)
    clamped_y = min(max(cur_y, 0), new_height - 1)
    %{emulator.cursor | position: {clamped_x, clamped_y}}
  end

  defp update_scroll_region_for_resize(emulator, new_height) do
    case emulator.scroll_region do
      {top, bottom}
      when is_integer(top) and is_integer(bottom) and top < bottom and
             top >= 0 and bottom < new_height ->
        {top, bottom}

      _ ->
        nil
    end
  end

  @impl true
  def get_cursor_visible(%Struct{cursor: cursor}),
    do: CursorManager.is_visible?(cursor)

  # --- Private Helpers ---

  # Delegate buffer operations to BufferOps
  defdelegate resize(emulator, new_width, new_height), to: BufferOps
  defdelegate maybe_scroll(emulator), to: BufferOps
  defdelegate index(emulator), to: BufferOps
  defdelegate next_line(emulator), to: BufferOps
  defdelegate reverse_index(emulator), to: BufferOps

  # Delegate cursor operations to Raxol.Terminal.Cursor.Manager
  defdelegate get_cursor_position(emulator),
    to: Raxol.Terminal.Cursor.Manager,
    as: :get_position

  defdelegate set_cursor_position(emulator, position, width, height),
    to: Raxol.Terminal.Cursor.Manager,
    as: :move_to

  defdelegate move_cursor_up(emulator, lines \\ 1, width, height),
    to: Raxol.Terminal.Cursor.Manager,
    as: :move_up

  defdelegate move_cursor_down(emulator, lines \\ 1, width, height),
    to: Raxol.Terminal.Cursor.Manager,
    as: :move_down

  defdelegate move_cursor_left(emulator, columns \\ 1, width, height),
    to: Raxol.Terminal.Cursor.Manager,
    as: :move_left

  defdelegate move_cursor_right(emulator, columns \\ 1, width, height),
    to: Raxol.Terminal.Cursor.Manager,
    as: :move_right

  defdelegate move_cursor_to_line_start(emulator),
    to: Raxol.Terminal.Cursor.Manager,
    as: :move_to_line_start

  defdelegate move_cursor_to_column(emulator, column, width, height),
    to: Raxol.Terminal.Cursor.Manager,
    as: :move_to

  defdelegate move_cursor_to(emulator, position, width, height),
    to: Raxol.Terminal.Cursor.Manager,
    as: :move_to

  # Delegate state management operations to Raxol.Terminal.State.Manager
  defdelegate get_mode_manager(emulator),
    to: Raxol.Terminal.State.Manager,
    as: :get_mode_manager

  defdelegate update_mode_manager(emulator, mode_manager),
    to: Raxol.Terminal.State.Manager,
    as: :update_mode_manager

  defdelegate get_charset_state(emulator),
    to: Raxol.Terminal.State.Manager,
    as: :get_charset_state

  defdelegate update_charset_state(emulator, charset_state),
    to: Raxol.Terminal.State.Manager,
    as: :update_charset_state

  defdelegate get_state_stack(emulator), to: Raxol.Terminal.State.Manager

  defdelegate update_state_stack(emulator, state_stack),
    to: Raxol.Terminal.State.Manager

  defdelegate get_scroll_region(emulator), to: Raxol.Terminal.State.Manager

  defdelegate update_scroll_region(emulator, scroll_region),
    to: Raxol.Terminal.State.Manager

  defdelegate get_last_col_exceeded(emulator), to: Raxol.Terminal.State.Manager

  defdelegate update_last_col_exceeded(emulator, last_col_exceeded),
    to: Raxol.Terminal.State.Manager

  defdelegate reset_to_initial_state(emulator), to: Raxol.Terminal.State.Manager

  # Delegate command management operations to Raxol.Terminal.Command.Manager
  defdelegate get_command_buffer(emulator),
    to: Raxol.Terminal.Command.Manager,
    as: :get_command_buffer

  defdelegate update_command_buffer(emulator, buffer),
    to: Raxol.Terminal.Command.Manager,
    as: :update_command_buffer

  defdelegate get_command_history(emulator),
    to: Raxol.Terminal.Command.Manager,
    as: :get_command_history

  defdelegate add_to_history(emulator, command),
    to: Raxol.Terminal.Command.Manager,
    as: :add_to_history

  defdelegate clear_history(emulator),
    to: Raxol.Terminal.Command.Manager,
    as: :clear_history

  defdelegate get_last_key_event(emulator),
    to: Raxol.Terminal.Command.Manager,
    as: :get_last_key_event

  defdelegate update_last_key_event(emulator, event),
    to: Raxol.Terminal.Command.Manager,
    as: :update_last_key_event

  defdelegate process_key_event(emulator, key_event),
    to: Raxol.Terminal.Command.Manager,
    as: :process_key_event

  defdelegate get_history_command(emulator, index),
    to: Raxol.Terminal.Command.Manager,
    as: :get_history_command

  defdelegate search_history(emulator, prefix),
    to: Raxol.Terminal.Command.Manager,
    as: :search_history

  # Delegate tab operations to Tab.Manager
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

  # Delegate scrollback operations to ScrollbackManager
  defdelegate get_scrollback_buffer(emulator), to: ScrollbackManager
  defdelegate add_to_scrollback(emulator, line), to: ScrollbackManager
  defdelegate clear_scrollback(emulator), to: ScrollbackManager
  defdelegate get_scrollback_limit(emulator), to: ScrollbackManager
  defdelegate set_scrollback_limit(emulator, limit), to: ScrollbackManager

  defdelegate get_scrollback_range(emulator, start, count),
    to: ScrollbackManager

  defdelegate get_scrollback_size(emulator), to: ScrollbackManager
  defdelegate scrollback_empty?(emulator), to: ScrollbackManager

  # Delegate plugin operations to PluginManager
  defdelegate get_plugin_manager(emulator),
    to: Raxol.Core.Runtime.Plugins.Manager,
    as: :get_manager

  defdelegate update_plugin_manager(emulator, manager),
    to: Raxol.Core.Runtime.Plugins.Manager,
    as: :update_manager

  defdelegate initialize_plugin(emulator, plugin_name, config),
    to: Raxol.Core.Runtime.Plugins.Manager

  defdelegate call_plugin_hook(emulator, plugin_name, hook_name, args),
    to: Raxol.Core.Runtime.Plugins.Manager,
    as: :call_hook

  defdelegate plugin_loaded?(emulator, plugin_name),
    to: Raxol.Core.Runtime.Plugins.Manager

  defdelegate get_loaded_plugins(emulator),
    to: Raxol.Core.Runtime.Plugins.Manager

  defdelegate unload_plugin(emulator, plugin_name),
    to: Raxol.Core.Runtime.Plugins.Manager

  defdelegate get_plugin_config(emulator, plugin_name),
    to: Raxol.Core.Runtime.Plugins.Manager

  defdelegate update_plugin_config(emulator, plugin_name, config),
    to: Raxol.Core.Runtime.Plugins.Manager

  # Delegate mode operations to ModeManager
  defdelegate get_mode_manager(emulator), to: ModeManager, as: :get_manager

  defdelegate update_mode_manager(emulator, manager),
    to: ModeManager,
    as: :update_manager

  defdelegate set_mode(emulator, mode), to: ModeManager
  defdelegate reset_mode(emulator, mode), to: ModeManager
  defdelegate mode_set?(emulator, mode), to: ModeManager
  defdelegate get_set_modes(emulator), to: ModeManager
  defdelegate reset_all_modes(emulator), to: ModeManager
  defdelegate save_modes(emulator), to: ModeManager
  defdelegate restore_modes(emulator), to: ModeManager

  # Delegate charset operations to CharsetManager
  defdelegate get_charset_state(emulator), to: CharsetManager, as: :get_state

  defdelegate update_charset_state(emulator, state),
    to: CharsetManager,
    as: :update_state

  defdelegate designate_charset(emulator, g_set, charset), to: CharsetManager
  defdelegate invoke_g_set(emulator, g_set), to: CharsetManager
  defdelegate get_current_g_set(emulator), to: CharsetManager
  defdelegate get_designated_charset(emulator, g_set), to: CharsetManager

  defdelegate reset_charset_state(emulator),
    to: CharsetManager,
    as: :reset_state

  defdelegate apply_single_shift(emulator, g_set), to: CharsetManager
  defdelegate get_single_shift(emulator), to: CharsetManager

  @doc """
  Sets the character set for the specified G-set.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  def set_charset(emulator, charset) do
    case CharsetManager.designate_charset(emulator, :g0, charset) do
      {:ok, updated_emulator} -> {:ok, updated_emulator}
      {:error, reason} -> {:error, reason}
    end
  end

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

  defdelegate update_state_stack(emulator, state_stack),
    to: TerminalStateManager

  defdelegate save_state(emulator), to: TerminalStateManager
  defdelegate restore_state(emulator), to: TerminalStateManager
  defdelegate has_saved_states?(emulator), to: TerminalStateManager
  defdelegate get_saved_states_count(emulator), to: TerminalStateManager
  defdelegate clear_saved_states(emulator), to: TerminalStateManager
  defdelegate get_current_state(emulator), to: TerminalStateManager
  defdelegate update_current_state(emulator, state), to: TerminalStateManager

  @doc """
  Writes data to the terminal output.
  """
  @spec write(t(), String.t()) :: t()
  def write(emulator, data) do
    Output.Manager.write(emulator, data)
  end

  @doc """
  Writes output to the terminal.
  """
  @spec write_to_output(t(), String.t()) :: t()
  def write_to_output(%Struct{} = emulator, output) when is_binary(output) do
    {new_emulator, _} = process_input(emulator, output)
    new_emulator
  end

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def move_cursor(pid \\ __MODULE__, direction, count \\ 1) do
    GenServer.call(pid, {:move_cursor, direction, count})
  end

  def get_cursor_position(pid \\ __MODULE__) do
    GenServer.call(pid, :get_cursor_position)
  end

  def set_cursor_position(pid \\ __MODULE__, {row, col}) do
    GenServer.call(pid, {:set_cursor_position, row, col})
  end

  def get_cursor_visibility(pid \\ __MODULE__) do
    GenServer.call(pid, :get_cursor_visibility)
  end

  def set_cursor_visibility(pid \\ __MODULE__, visible) do
    GenServer.call(pid, {:set_cursor_visibility, visible})
  end

  def get_cursor_style(pid \\ __MODULE__) do
    GenServer.call(pid, :get_cursor_style)
  end

  def set_cursor_style(pid \\ __MODULE__, style) do
    GenServer.call(pid, {:set_cursor_style, style})
  end

  def get_cursor_blink(pid \\ __MODULE__) do
    GenServer.call(pid, :get_cursor_blink)
  end

  def set_cursor_blink(pid \\ __MODULE__, blink) do
    GenServer.call(pid, {:set_cursor_blink, blink})
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    buffer = ScreenBuffer.new(width, height)
    cursor = CursorManager.new()
    screen = ScreenBuffer.new(width, height)

    state = %{
      buffer: buffer,
      cursor: cursor,
      screen: screen,
      width: width,
      height: height
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:move_cursor, direction, count}, _from, state) do
    {new_cursor, new_buffer} = case direction do
      :up -> move_up(state.cursor, state.buffer, count)
      :down -> move_down(state.cursor, state.buffer, count)
      :left -> move_left(state.cursor, state.buffer, count)
      :right -> move_right(state.cursor, state.buffer, count)
      _ -> {state.cursor, state.buffer}
    end

    new_state = %{state | cursor: new_cursor, buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_cursor_position, _from, state) do
    position = CursorManager.get_position(state.cursor)
    {:reply, position, state}
  end

  @impl true
  def handle_call({:set_cursor_position, row, col}, _from, state) do
    new_cursor = CursorManager.move_to(state.cursor, {row, col})
    new_state = %{state | cursor: new_cursor}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_cursor_visibility, _from, state) do
    visible = CursorManager.is_visible?(state.cursor)
    {:reply, visible, state}
  end

  @impl true
  def handle_call({:set_cursor_visibility, visible}, _from, state) do
    new_cursor = CursorManager.set_visibility(state.cursor, visible)
    new_state = %{state | cursor: new_cursor}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_cursor_style, _from, state) do
    style = CursorManager.get_style(state.cursor)
    {:reply, style, state}
  end

  @impl true
  def handle_call({:set_cursor_style, style}, _from, state) do
    new_cursor = CursorManager.set_style(state.cursor, style)
    new_state = %{state | cursor: new_cursor}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_cursor_blink, _from, state) do
    blink = CursorManager.get_blink(state.cursor)
    {:reply, blink, state}
  end

  @impl true
  def handle_call({:set_cursor_blink, blink}, _from, state) do
    new_cursor = CursorManager.set_blink(state.cursor, blink)
    new_state = %{state | cursor: new_cursor}
    {:reply, :ok, new_state}
  end

  # --- Private Functions ---

  defp move_up(cursor, buffer, count) do
    {row, col} = CursorManager.get_position(cursor)
    new_row = max(0, row - count)
    new_cursor = CursorManager.move_to(cursor, {new_row, col})
    {new_cursor, buffer}
  end

  defp move_down(cursor, buffer, count) do
    {row, col} = CursorManager.get_position(cursor)
    new_row = min(buffer.height - 1, row + count)
    new_cursor = CursorManager.move_to(cursor, {new_row, col})
    {new_cursor, buffer}
  end

  defp move_left(cursor, buffer, count) do
    {row, col} = CursorManager.get_position(cursor)
    new_col = max(0, col - count)
    new_cursor = CursorManager.move_to(cursor, {row, new_col})
    {new_cursor, buffer}
  end

  defp move_right(cursor, buffer, count) do
    {row, col} = CursorManager.get_position(cursor)
    new_col = min(buffer.width - 1, col + count)
    new_cursor = CursorManager.move_to(cursor, {row, new_col})
    {new_cursor, buffer}
  end
end
