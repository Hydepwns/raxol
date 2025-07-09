defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  The main terminal emulator module that coordinates all terminal operations.
  This module delegates to specialized manager modules for different aspects of terminal functionality.
  """

  import Raxol.Guards
  import Logger

  alias Raxol.Terminal.{
    Event.Handler,
    Buffer.Manager,
    Config.Manager,
    Command.Manager,
    Operations.CursorOperations,
    Operations.ScreenOperations,
    Operations.TextOperations,
    Operations.SelectionOperations,
    Operations.ScrollOperations,
    Operations.StateOperations,
    Cursor.Manager,
    FormattingManager,
    OutputManager,
    Window.Manager,
    ScreenBuffer,
    ANSI.SequenceHandlers,
    ANSI.SGRProcessor,
    ModeHandlers,
    CursorHandlers,
    Input.TextProcessor,
    Style.StyleProcessor,
    Plugin.DependencyResolver,
    Emulator.Constructors,
    Emulator.Reset,
    Emulator.CommandHandlers,
    Commands.CursorHandlers
  }

  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.FormattingManager, as: FormattingManager
  alias Raxol.Terminal.OutputManager, as: OutputManager
  alias Raxol.Terminal.Operations.ScrollOperations, as: ScrollOperations
  alias Raxol.Terminal.Operations.StateOperations, as: StateOperations
  alias Raxol.Terminal.Operations.ScreenOperations, as: Screen

  @behaviour Raxol.Terminal.OperationsBehaviour
  @behaviour Raxol.Terminal.EmulatorBehaviour

  defstruct [
    # Core managers
    state: nil,
    event: nil,
    buffer: nil,
    config: nil,
    command: nil,
    cursor: nil,
    window_manager: nil,
    mode_manager: nil,

    # Screen buffers
    active_buffer_type: :main,
    main_screen_buffer: nil,
    alternate_screen_buffer: nil,

    # Character set state
    charset_state: %{
      g0: :us_ascii,
      g1: :us_ascii,
      g2: :us_ascii,
      g3: :us_ascii,
      gl: :g0,
      gr: :g0,
      single_shift: nil
    },

    # Dimensions
    width: 80,
    height: 24,

    # Window state
    window_state: %{
      iconified: false,
      maximized: false,
      position: {0, 0},
      size: {80, 24},
      size_pixels: {640, 384},
      stacking_order: :normal,
      previous_size: {80, 24},
      saved_size: {80, 24},
      icon_name: ""
    },

    # State stack for terminal state management
    state_stack: [],

    # Parser state
    parser_state: %Raxol.Terminal.Parser.State{state: :ground},

    # Command history
    command_history: [],
    current_command_buffer: "",
    max_command_history: 100,

    # Other fields
    output_buffer: "",
    style: Raxol.Terminal.ANSI.TextFormatting.new(),
    scrollback_limit: 1000,
    scrollback_buffer: [],
    window_title: nil,
    plugin_manager: nil,
    saved_cursor: nil,
    scroll_region: nil,
    sixel_state: nil,
    last_col_exceeded: false,
    cursor_blink_rate: 0,
    cursor_style: :block,
    session_id: nil,
    client_options: %{}
  ]

  @type t :: %__MODULE__{
          state: pid() | nil,
          event: pid() | nil,
          buffer: pid() | nil,
          config: pid() | nil,
          command: pid() | nil,
          cursor: pid() | nil,
          window_manager: pid() | nil,
          mode_manager: pid() | nil,
          active_buffer_type: :main | :alternate,
          main_screen_buffer: ScreenBuffer.t() | nil,
          alternate_screen_buffer: ScreenBuffer.t() | nil,
          charset_state: map(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          window_state: map(),
          state_stack: list(),
          parser_state: Raxol.Terminal.Parser.State.t(),
          command_history: list(),
          current_command_buffer: String.t(),
          max_command_history: non_neg_integer(),
          output_buffer: String.t(),
          style: Raxol.Terminal.ANSI.TextFormatting.t(),
          scrollback_limit: non_neg_integer(),
          scrollback_buffer: list(),
          window_title: String.t() | nil,
          plugin_manager: any() | nil,
          saved_cursor: any() | nil,
          scroll_region: any() | nil,
          sixel_state: any() | nil,
          last_col_exceeded: boolean(),
          cursor_blink_rate: non_neg_integer(),
          cursor_style: atom(),
          session_id: any() | nil,
          client_options: map()
        }

  # Cursor Operations
  defdelegate get_cursor_position(emulator), to: CursorOperations
  defdelegate set_cursor_position(emulator, x, y), to: CursorOperations
  defdelegate get_cursor_style(emulator), to: CursorOperations
  defdelegate set_cursor_style(emulator, style), to: CursorOperations
  defdelegate cursor_visible?(emulator), to: CursorOperations

  defdelegate get_cursor_visible(emulator),
    to: CursorOperations,
    as: :cursor_visible?

  defdelegate set_cursor_visibility(emulator, visible), to: CursorOperations
  defdelegate cursor_blinking?(emulator), to: CursorOperations
  defdelegate set_cursor_blink(emulator, blinking), to: CursorOperations

  # Alias for blinking? to match expected interface
  defdelegate blinking?(emulator), to: CursorOperations, as: :cursor_blinking?

  # Screen Operations
  defdelegate clear_screen(emulator), to: ScreenOperations
  defdelegate clear_line(emulator, line), to: ScreenOperations
  defdelegate erase_display(emulator, mode), to: ScreenOperations
  defdelegate erase_in_display(emulator, mode), to: ScreenOperations
  defdelegate erase_line(emulator, mode), to: ScreenOperations
  defdelegate erase_in_line(emulator, mode), to: ScreenOperations
  defdelegate erase_from_cursor_to_end(emulator), to: ScreenOperations
  defdelegate erase_from_start_to_cursor(emulator), to: ScreenOperations
  defdelegate erase_chars(emulator, count), to: ScreenOperations
  defdelegate delete_chars(emulator, count), to: ScreenOperations
  defdelegate insert_chars(emulator, count), to: ScreenOperations
  defdelegate delete_lines(emulator, count), to: ScreenOperations
  defdelegate insert_lines(emulator, count), to: ScreenOperations
  defdelegate prepend_lines(emulator, count), to: ScreenOperations

  # Text Operations
  defdelegate get_text_in_region(emulator, x1, y1, x2, y2), to: TextOperations
  defdelegate get_content(emulator), to: TextOperations
  defdelegate get_line(emulator, line), to: TextOperations
  defdelegate get_cell_at(emulator, x, y), to: TextOperations

  # Selection Operations
  defdelegate get_selection(emulator), to: SelectionOperations
  defdelegate get_selection_start(emulator), to: SelectionOperations
  defdelegate get_selection_end(emulator), to: SelectionOperations
  defdelegate get_selection_boundaries(emulator), to: SelectionOperations
  defdelegate start_selection(emulator, x, y), to: SelectionOperations
  defdelegate update_selection(emulator, x, y), to: SelectionOperations
  defdelegate clear_selection(emulator), to: SelectionOperations
  defdelegate selection_active?(emulator), to: SelectionOperations
  defdelegate in_selection?(emulator, x, y), to: SelectionOperations

  # Scroll Operations
  defdelegate set_scroll_region(emulator, region), to: ScrollOperations

  # State Operations
  defdelegate get_state(emulator), to: StateOperations
  defdelegate get_style(emulator), to: StateOperations
  defdelegate get_style_at(emulator, x, y), to: StateOperations
  defdelegate get_style_at_cursor(emulator), to: StateOperations

  # Buffer Operations
  defdelegate update_active_buffer(emulator, new_buffer),
    to: Raxol.Terminal.BufferManager

  # Clear scrollback buffer
  defdelegate clear_scrollback(emulator), to: Reset

  # Constructor functions
  defdelegate new(), to: Constructors
  defdelegate new(width, height), to: Constructors
  defdelegate new(width, height, opts), to: Constructors
  defdelegate new(opts), to: Constructors
  defdelegate new(width, height, config, options), to: Constructors

  # Reset and cleanup functions
  defdelegate reset(emulator), to: Reset
  defdelegate cleanup(emulator), to: Reset
  defdelegate stop(emulator), to: Reset
  defdelegate reset_charset_state(emulator), to: Reset

  # Style management
  defdelegate update_style(emulator, style_attrs), to: StyleProcessor

  # Plugin dependency resolution
  defdelegate resolve_plugin_dependencies(plugin_manager),
    to: DependencyResolver

  # Text input processing
  defdelegate handle_text_input(input, emulator), to: TextProcessor
  defdelegate printable_text?(input), to: TextProcessor
  defdelegate printable_char?(char), to: TextProcessor

  # Cursor movement operations
  defdelegate move_cursor_up(emulator, count),
    to: Raxol.Terminal.Commands.CursorHandlers

  defdelegate move_cursor_down(emulator, count),
    to: Raxol.Terminal.Commands.CursorHandlers

  defdelegate move_cursor_forward(emulator, count),
    to: Raxol.Terminal.Commands.CursorHandlers

  defdelegate move_cursor_back(emulator, count),
    to: Raxol.Terminal.Commands.CursorHandlers

  defdelegate move_cursor_to_column(emulator, column, width, height),
    to: Raxol.Terminal.Commands.CursorHandlers

  defdelegate move_cursor_to_line_start(emulator),
    to: Raxol.Terminal.Commands.CursorHandlers

  defdelegate move_cursor_up(emulator, count, width, height),
    to: Raxol.Terminal.Commands.CursorHandlers

  defdelegate move_cursor_down(emulator, count, width, height),
    to: Raxol.Terminal.Commands.CursorHandlers

  defdelegate move_cursor_left(emulator, count, width, height),
    to: Raxol.Terminal.Commands.CursorHandlers

  defdelegate move_cursor_right(emulator, count, width, height),
    to: Raxol.Terminal.Commands.CursorHandlers

  defdelegate move_cursor_to(emulator, x, y),
    to: Raxol.Terminal.Commands.CursorHandlers

  defdelegate move_cursor_to(emulator, position, width, height),
    to: Raxol.Terminal.Commands.CursorHandlers

  # Mode management functions
  defdelegate update_insert_mode_direct(mode_manager, value), to: ModeHandlers

  defdelegate update_alternate_buffer_active_direct(mode_manager, value),
    to: ModeHandlers

  defdelegate update_cursor_keys_mode_direct(mode_manager, value),
    to: ModeHandlers

  defdelegate update_origin_mode_direct(mode_manager, value), to: ModeHandlers

  defdelegate update_line_feed_mode_direct(mode_manager, value),
    to: ModeHandlers

  defdelegate update_auto_wrap_direct(mode_manager, value), to: ModeHandlers

  defdelegate update_cursor_visible_direct(mode_manager, value),
    to: ModeHandlers

  defdelegate update_screen_mode_reverse_direct(mode_manager, value),
    to: ModeHandlers

  defdelegate update_auto_repeat_mode_direct(mode_manager, value),
    to: ModeHandlers

  defdelegate update_interlacing_mode_direct(mode_manager, value),
    to: ModeHandlers

  defdelegate update_bracketed_paste_mode_direct(mode_manager, value),
    to: ModeHandlers

  defdelegate update_column_width_132_direct(mode_manager, value),
    to: ModeHandlers

  defdelegate update_column_width_80_direct(mode_manager, value),
    to: ModeHandlers

  defdelegate mode_updates(), to: ModeHandlers

  # ANSI sequence parsing
  defdelegate parse_ansi_sequence(rest), to: SequenceHandlers
  defdelegate parse_osc(binary), to: SequenceHandlers
  defdelegate parse_dcs(binary), to: SequenceHandlers
  defdelegate parse_csi_cursor_pos(binary), to: SequenceHandlers
  defdelegate parse_csi_cursor_up(binary), to: SequenceHandlers
  defdelegate parse_csi_cursor_down(binary), to: SequenceHandlers
  defdelegate parse_csi_cursor_forward(binary), to: SequenceHandlers
  defdelegate parse_csi_cursor_back(binary), to: SequenceHandlers
  defdelegate parse_csi_cursor_show(binary), to: SequenceHandlers
  defdelegate parse_csi_cursor_hide(binary), to: SequenceHandlers
  defdelegate parse_csi_clear_screen(binary), to: SequenceHandlers
  defdelegate parse_csi_clear_line(binary), to: SequenceHandlers
  defdelegate parse_csi_set_mode(binary), to: SequenceHandlers
  defdelegate parse_csi_reset_mode(binary), to: SequenceHandlers
  defdelegate parse_csi_set_standard_mode(binary), to: SequenceHandlers
  defdelegate parse_csi_reset_standard_mode(binary), to: SequenceHandlers
  defdelegate parse_esc_equals(binary), to: SequenceHandlers
  defdelegate parse_esc_greater(binary), to: SequenceHandlers
  defdelegate parse_csi_set_scroll_region(binary), to: SequenceHandlers
  defdelegate parse_csi_general(binary), to: SequenceHandlers
  defdelegate parse_sgr(binary), to: SequenceHandlers
  defdelegate parse_unknown(binary), to: SequenceHandlers

  # SGR processing
  defdelegate process_sgr_codes(codes, style), to: SGRProcessor
  defdelegate sgr_code_mappings(), to: SGRProcessor

  # Command handlers
  defdelegate handle_cursor_position(params, emulator), to: CommandHandlers
  defdelegate handle_cursor_up(params, emulator), to: CommandHandlers
  defdelegate handle_cursor_down(params, emulator), to: CommandHandlers
  defdelegate handle_cursor_forward(params, emulator), to: CommandHandlers
  defdelegate handle_cursor_back(params, emulator), to: CommandHandlers
  defdelegate handle_ed_command(params, emulator), to: CommandHandlers
  defdelegate handle_el_command(params, emulator), to: CommandHandlers
  defdelegate handle_set_scroll_region(params, emulator), to: CommandHandlers
  defdelegate handle_set_mode(params, emulator), to: CommandHandlers
  defdelegate handle_reset_mode(params, emulator), to: CommandHandlers
  defdelegate handle_set_standard_mode(params, emulator), to: CommandHandlers
  defdelegate handle_reset_standard_mode(params, emulator), to: CommandHandlers
  defdelegate handle_esc_equals(emulator), to: CommandHandlers
  defdelegate handle_esc_greater(emulator), to: CommandHandlers
  defdelegate handle_sgr(params, emulator), to: CommandHandlers

  defdelegate handle_csi_general(params, final_byte, emulator),
    to: CommandHandlers

  defdelegate handle_csi_general(params, final_byte, emulator, intermediates),
    to: CommandHandlers

  # Get scrollback buffer
  def get_scrollback(emulator) do
    emulator.scrollback_buffer
  end

  # Dimension getters
  def get_width(emulator) do
    emulator.width
  end

  def get_height(emulator) do
    emulator.height
  end

  # Scroll region getter
  def get_scroll_region(emulator) do
    emulator.scroll_region
  end

  # Cursor visibility getter (alias for cursor_visible?)
  def get_cursor_visible(emulator) do
    cursor_visible?(emulator)
  end

  # Mode update functions
  defdelegate update_insert_mode(emulator, value),
    to: Raxol.Terminal.ModeManager

  defdelegate update_line_feed_mode(emulator, value),
    to: Raxol.Terminal.ModeManager

  defdelegate update_origin_mode(emulator, value),
    to: Raxol.Terminal.ModeManager

  defdelegate update_auto_wrap_mode(emulator, value),
    to: Raxol.Terminal.ModeManager

  defdelegate update_cursor_visible(emulator, value),
    to: Raxol.Terminal.ModeManager

  defdelegate update_screen_mode_reverse(emulator, value),
    to: Raxol.Terminal.ModeManager

  defdelegate update_auto_repeat_mode(emulator, value),
    to: Raxol.Terminal.ModeManager

  defdelegate update_interlacing_mode(emulator, value),
    to: Raxol.Terminal.ModeManager

  defdelegate update_bracketed_paste_mode(emulator, value),
    to: Raxol.Terminal.ModeManager

  defdelegate update_column_width_132(emulator, value),
    to: Raxol.Terminal.ModeManager

  @doc """
  Sets an attribute on the emulator.
  """
  @spec set_attribute(t(), atom(), any()) :: t()
  def set_attribute(emulator, attribute, _value) do
    updated_style =
      Raxol.Terminal.ANSI.TextFormatting.apply_attribute(
        emulator.style,
        attribute
      )

    %{emulator | style: updated_style}
  end

  @doc """
  Gets the active buffer from the emulator.
  """
  @spec get_active_buffer(t()) :: ScreenBuffer.t()
  def get_active_buffer(%__MODULE__{} = emulator) do
    case emulator.active_buffer_type do
      :main -> emulator.main_screen_buffer
      :alternate -> emulator.alternate_screen_buffer
    end
  end

  @doc """
  Checks if scrolling is needed and performs it if necessary.
  """
  @spec maybe_scroll(t()) :: t()
  def maybe_scroll(%__MODULE__{} = emulator) do
    {_x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    if y >= emulator.height do
      # Need to scroll
      active_buffer = get_active_buffer(emulator)
      {scrolled_buffer, _scrolled_lines} = Raxol.Terminal.ScreenBuffer.scroll_up(active_buffer, 1)

      # Update the appropriate buffer
      case emulator.active_buffer_type do
        :main -> %{emulator | main_screen_buffer: scrolled_buffer}
        :alternate -> %{emulator | alternate_screen_buffer: scrolled_buffer}
      end
    else
      emulator
    end
  end

  @spec process_input(t(), binary()) :: {t(), binary()}
  def process_input(emulator, input) do
    IO.puts("DEBUG: process_input called with input: #{inspect(input)}")

    # Handle character set commands first
    case get_charset_command(input) do
      {field, value} ->
        IO.puts(
          "DEBUG: process_input matched charset command: #{field} = #{value}"
        )

        # If it's a charset command, handle it completely and return
        updated_emulator = %{
          emulator
          | charset_state: %{emulator.charset_state | field => value}
        }

        {updated_emulator, ""}

      :no_match ->
        IO.puts(
          "DEBUG: process_input no charset match, using parser-based processing"
        )

        # Use parser-based input processing for all other input
        {updated_emulator, output} = Raxol.Terminal.Input.CoreHandler.process_terminal_input(emulator, input)

        IO.puts(
          "DEBUG: After parser processing, style: #{inspect(updated_emulator.style)}"
        )

        IO.puts(
          "DEBUG: After parser processing, scroll_region: #{inspect(updated_emulator.scroll_region)}"
        )

        {updated_emulator, output}
    end
  end

  defp get_charset_command(input) do
    charset_commands = %{
      "\e)0" => {:g1, :dec_special_graphics},
      "\e(B" => {:g0, :us_ascii},
      "\e*0" => {:g2, :dec_special_graphics},
      "\x0E" => {:gl, :g1},
      "\x0F" => {:gl, :g0},
      "\en" => {:gl, :g2},
      "\eo" => {:gl, :g3},
      "\e~" => {:gr, :g2},
      "\e}" => {:gr, :g1},
      "\e|" => {:gr, :g3}
    }

    Map.get(charset_commands, input, :no_match)
  end

  defp handle_ansi_sequences(<<>>, emulator), do: {emulator, <<>>}

  defp handle_ansi_sequences(rest, emulator) do
    IO.puts("DEBUG: handle_ansi_sequences input: #{inspect(rest)}")

    case parse_ansi_sequence(rest) do
      {:osc, remaining, _} ->
        IO.puts("DEBUG: handle_ansi_sequences parsed: {:osc, ...}")
        handle_ansi_sequences(remaining, emulator)

      {:dcs, remaining, _} ->
        IO.puts("DEBUG: handle_ansi_sequences parsed: {:dcs, ...}")
        handle_ansi_sequences(remaining, emulator)

      {:incomplete, _} ->
        IO.puts("DEBUG: handle_ansi_sequences parsed: {:incomplete, ...}")
        {emulator, rest}

      parsed_sequence ->
        IO.puts(
          "DEBUG: handle_ansi_sequences parsed: #{inspect(parsed_sequence)}"
        )

        {new_emulator, remaining} =
          handle_parsed_sequence(parsed_sequence, rest, emulator)

        IO.puts(
          "DEBUG: handle_ansi_sequences updated emulator: #{inspect(new_emulator.style)}"
        )

        handle_ansi_sequences(remaining, new_emulator)
    end
  end

  defp handle_parsed_sequence(
         {:osc, remaining, _},
         _rest,
         emulator
       ) do
    handle_ansi_sequences(remaining, emulator)
  end

  defp handle_parsed_sequence(
         {:dcs, remaining, _},
         _rest,
         emulator
       ) do
    handle_ansi_sequences(remaining, emulator)
  end

  defp handle_parsed_sequence(
         {:incomplete, _},
         _rest,
         emulator
       ) do
    {emulator, <<>>}
  end

  defp handle_parsed_sequence(
         {:csi_cursor_pos, params, remaining, _},
         _rest,
         emulator
       ) do
    {handle_cursor_position(params, emulator), remaining}
  end

  defp handle_parsed_sequence(
         {:csi_cursor_up, params, remaining, _},
         _rest,
         emulator
       ) do
    {handle_cursor_up(params, emulator), remaining}
  end

  defp handle_parsed_sequence(
         {:csi_cursor_down, params, remaining, _},
         _rest,
         emulator
       ) do
    {handle_cursor_down(params, emulator), remaining}
  end

  defp handle_parsed_sequence(
         {:csi_cursor_forward, params, remaining, _},
         _rest,
         emulator
       ) do
    {handle_cursor_forward(params, emulator), remaining}
  end

  defp handle_parsed_sequence(
         {:csi_cursor_back, params, remaining, _},
         _rest,
         emulator
       ) do
    {handle_cursor_back(params, emulator), remaining}
  end

  defp handle_parsed_sequence({:csi_cursor_show, remaining, _}, _rest, emulator) do
    {set_cursor_visible(true, emulator), remaining}
  end

  defp handle_parsed_sequence({:csi_cursor_hide, remaining, _}, _rest, emulator) do
    {set_cursor_visible(false, emulator), remaining}
  end

  defp handle_parsed_sequence(
         {:csi_clear_screen, remaining, _},
         _rest,
         emulator
       ) do
    {clear_screen(emulator), remaining}
  end

  defp handle_parsed_sequence({:csi_clear_line, remaining, _}, _rest, emulator) do
    {clear_line(emulator), remaining}
  end

  defp handle_parsed_sequence(
         {:csi_set_mode, params, remaining, _},
         _rest,
         emulator
       ) do
    {handle_set_mode(params, emulator), remaining}
  end

  defp handle_parsed_sequence(
         {:csi_reset_mode, params, remaining, _},
         _rest,
         emulator
       ) do
    {handle_reset_mode(params, emulator), remaining}
  end

  defp handle_parsed_sequence(
         {:csi_set_standard_mode, params, remaining, _},
         _rest,
         emulator
       ) do
    {handle_set_standard_mode(params, emulator), remaining}
  end

  defp handle_parsed_sequence(
         {:csi_reset_standard_mode, params, remaining, _},
         _rest,
         emulator
       ) do
    {handle_reset_standard_mode(params, emulator), remaining}
  end

  defp handle_parsed_sequence({:esc_equals, remaining, _}, _rest, emulator) do
    {handle_esc_equals(emulator), remaining}
  end

  defp handle_parsed_sequence({:esc_greater, remaining, _}, _rest, emulator) do
    {handle_esc_greater(emulator), remaining}
  end

  defp handle_parsed_sequence({:sgr, params, remaining, _}, _rest, emulator) do
    IO.puts(
      "DEBUG: SGR handler called with params=#{inspect(params)}, remaining=#{inspect(remaining)}"
    )

    IO.puts(
      "DEBUG: SGR handler emulator.style before=#{inspect(emulator.style)}"
    )

    result = {handle_sgr(params, emulator), remaining}

    IO.puts(
      "DEBUG: SGR handler result emulator.style after=#{inspect(elem(result, 0).style)}"
    )

    result
  end

  defp handle_parsed_sequence({:unknown, remaining, _}, _rest, emulator) do
    handle_ansi_sequences(remaining, emulator)
  end

  defp handle_parsed_sequence(
         {:csi_set_scroll_region, params, remaining, _},
         _rest,
         emulator
       ) do
    {handle_set_scroll_region(params, emulator), remaining}
  end

  defp handle_parsed_sequence(
         {:csi_general, params, intermediates, final_byte, remaining},
         _rest,
         emulator
       ) do
    {handle_csi_general(params, final_byte, emulator, intermediates), remaining}
  end

  defp set_cursor_visible(visible, emulator) do
    mode_manager = emulator.mode_manager

    # Update the mode manager struct directly
    new_mode_manager = %{mode_manager | cursor_visible: visible}
    emulator = %{emulator | mode_manager: new_mode_manager}

    # Also update the cursor manager
    cursor = emulator.cursor

    if pid?(cursor) do
      GenServer.call(cursor, {:set_visibility, visible})
    end

    emulator
  end

  defp log_sgr_debug(msg) do
    File.write!("tmp/sgr_debug.log", msg <> "\n", [:append])
  end

  defp parse_mode_params(params) do
    params
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&String.to_integer/1)
  end

  defp lookup_mode(mode_code) do
    case Raxol.Terminal.ModeManager.lookup_private(mode_code) do
      nil -> :error
      mode_name -> {:ok, mode_name}
    end
  end

  defp lookup_standard_mode(mode_code) do
    case Raxol.Terminal.ModeManager.lookup_standard(mode_code) do
      nil -> :error
      mode_name -> {:ok, mode_name}
    end
  end

  defp set_mode_in_manager(emulator, mode_name, value) do
    mode_manager = emulator.mode_manager

    # Update the mode manager struct directly
    new_mode_manager = update_mode_manager_state(mode_manager, mode_name, value)
    emulator = %{emulator | mode_manager: new_mode_manager}

    # Handle screen buffer switching
    emulator = handle_screen_buffer_switch(emulator, mode_name, value)

    emulator
  end

  defp update_mode_manager_state(mode_manager, mode_name, value) do
    case get_mode_update_function(mode_name, value) do
      {:ok, update_fn} -> update_fn.(mode_manager)
      :error -> mode_manager
    end
  end

  defp get_mode_update_function(mode_name, value) do
    case Map.fetch(ModeHandlers.mode_updates(), mode_name) do
      {:ok, update_fn} ->
        {:ok, fn mode_manager -> update_fn.(mode_manager, value) end}

      :error ->
        :error
    end
  end

  defp handle_screen_buffer_switch(emulator, mode, true)
       when mode in [:alt_screen_buffer, :dec_alt_screen_save] do
    alt_buf =
      emulator.alternate_screen_buffer ||
        Raxol.Terminal.ScreenBuffer.new(emulator.width, emulator.height)

    # Reset cursor position to (0, 0) when switching to alternate buffer
    Raxol.Terminal.Cursor.Manager.set_position(emulator.cursor, {0, 0})

    %{
      emulator
      | active_buffer_type: :alternate,
        alternate_screen_buffer: alt_buf
    }
  end

  defp handle_screen_buffer_switch(emulator, mode, false)
       when mode in [:alt_screen_buffer, :dec_alt_screen_save] do
    # Reset cursor position to (0, 0) when switching back to main buffer
    Raxol.Terminal.Cursor.Manager.set_position(emulator.cursor, {0, 0})

    %{emulator | active_buffer_type: :main}
  end

  defp handle_screen_buffer_switch(emulator, _mode, _value) do
    emulator
  end

  def write_to_output(emulator, data) do
    OutputManager.write(emulator, data)
  end

  def update_scroll_region(emulator, {top, bottom}) do
    ScrollOperations.set_scroll_region(emulator, {top, bottom})
  end

  def clear_from_cursor_to_end(emulator, _x, _y) do
    ScreenOperations.erase_from_cursor_to_end(emulator)
  end

  def clear_from_start_to_cursor(emulator, _x, _y) do
    ScreenOperations.erase_from_start_to_cursor(emulator)
  end

  def clear_entire_screen(emulator) do
    ScreenOperations.clear_screen(emulator)
  end

  def clear_entire_screen_and_scrollback(emulator) do
    emulator = clear_entire_screen(emulator)
    %{emulator | scrollback_buffer: []}
  end

  def clear_from_cursor_to_end_of_line(emulator, _x, _y) do
    Screen.clear_line(emulator, 0)
  end

  def clear_from_start_of_line_to_cursor(emulator, _x, _y) do
    Screen.clear_line(emulator, 1)
  end

  def clear_entire_line(emulator, _y) do
    Screen.clear_line(emulator, 2)
  end

  # Helper functions to fetch state from GenServer-based managers
  @spec get_config_struct(t()) :: any()
  def get_config_struct(%__MODULE__{config: pid}) when pid?(pid) do
    GenServer.call(pid, :get_state)
  end

  @spec get_window_manager_struct(t()) :: any()
  def get_window_manager_struct(%__MODULE__{window_manager: pid})
      when pid?(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Gets the cursor struct from the emulator.
  """
  @spec get_cursor_struct(t()) :: Cursor.t()
  def get_cursor_struct(%__MODULE__{cursor: cursor}) do
    if is_pid(cursor) do
      GenServer.call(cursor, :get_state)
    else
      cursor
    end
  end

  @spec get_mode_manager_struct(t()) :: any()
  def get_mode_manager_struct(%__MODULE__{mode_manager: mode_manager}) do
    mode_manager
  end

  # Override the delegate functions to handle PIDs properly
  def get_cursor_position(%__MODULE__{cursor: cursor} = emulator) do
    if is_pid(cursor) do
      cursor_struct = get_cursor_struct(emulator)
      cursor_struct.position
    else
      cursor.position
    end
  end

  def cursor_visible?(%__MODULE__{} = emulator) do
    # Check cursor manager first (authoritative source)
    if pid?(emulator.cursor) do
      CursorManager.get_visibility(emulator.cursor)
    else
      # Fallback to mode manager if cursor is not a PID
      mode_manager = get_mode_manager_struct(emulator)
      mode_manager.cursor_visible
    end
  end

  @doc """
  Gets the mode manager from the emulator.
  """
  @spec get_mode_manager(t()) :: term()
  def get_mode_manager(%__MODULE__{} = emulator) do
    emulator.mode_manager
  end

  @doc """
  Resizes the terminal emulator to new dimensions.
  """
  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  def resize(%__MODULE__{} = emulator, width, height)
      when width > 0 and height > 0 do
    # Resize main screen buffer
    main_buffer =
      if emulator.main_screen_buffer do
        ScreenBuffer.resize(emulator.main_screen_buffer, width, height)
      else
        ScreenBuffer.new(width, height)
      end

    # Resize alternate screen buffer
    alternate_buffer =
      if emulator.alternate_screen_buffer do
        ScreenBuffer.resize(emulator.alternate_screen_buffer, width, height)
      else
        ScreenBuffer.new(width, height)
      end

    # Update emulator with new dimensions and buffers
    %{
      emulator
      | width: width,
        height: height,
        main_screen_buffer: main_buffer,
        alternate_screen_buffer: alternate_buffer
    }
  end

  # Patch: Write string with charset translation
  def write_string(%__MODULE__{} = emulator, x, y, string, style \\ %{}) do
    translated =
      Raxol.Terminal.ANSI.CharacterSets.translate_string(
        string,
        emulator.charset_state
      )

    # Get the active buffer
    buffer = get_active_buffer(emulator)

    # Write the string to the buffer
    updated_buffer =
      Raxol.Terminal.ScreenBuffer.write_string(buffer, x, y, translated, style)

    # Update cursor position after writing
    cursor = get_cursor_struct(emulator)
    new_x = x + String.length(translated)
    new_cursor = %{cursor | x: new_x, position: {new_x, y}}

    # Update the appropriate buffer
    emulator =
      case emulator.active_buffer_type do
        :main ->
          %{emulator | main_screen_buffer: updated_buffer, cursor: new_cursor}

        :alternate ->
          %{
            emulator
            | alternate_screen_buffer: updated_buffer,
              cursor: new_cursor
          }
      end

    emulator
  end

  # Helper function to write text at current cursor position
  defp write_text_at_cursor(emulator, text) do
    cursor = get_cursor_struct(emulator)
    {x, y} = cursor.position

    # Get the active buffer
    buffer = get_active_buffer(emulator)

    # Write the text to the buffer
    updated_buffer = ScreenBuffer.write_string(buffer, x, y, text, %{})

    # Update cursor position after writing
    new_x = x + String.length(text)

    # Update the cursor through GenServer if it's a PID
    emulator =
      if pid?(emulator.cursor) do
        GenServer.call(emulator.cursor, {:update_position, new_x, y})
        emulator
      else
        new_cursor = %{cursor | col: new_x, row: y, position: {new_x, y}}
        %{emulator | cursor: new_cursor}
      end

    # Update the appropriate buffer
    case emulator.active_buffer_type do
      :main ->
        %{emulator | main_screen_buffer: updated_buffer}

      :alternate ->
        %{emulator | alternate_screen_buffer: updated_buffer}
    end
  end

  @doc """
  Sets a terminal mode using the mode manager.
  """
  @spec set_mode(t(), atom()) :: t()
  def set_mode(emulator, mode) do
    require Logger
    Logger.debug("Emulator.set_mode/2 called with mode=#{inspect(mode)}")
    Logger.debug("Emulator.set_mode/2: about to call ModeManager.set_mode")
    result = Raxol.Terminal.ModeManager.set_mode(emulator, [mode])
    Logger.debug("Emulator.set_mode/2: ModeManager.set_mode returned #{inspect(result)}")
    case result do
      {:ok, new_emulator} ->
        Logger.debug("Emulator.set_mode/2: returning new_emulator")
        new_emulator
      {:error, reason} ->
        Logger.debug("Emulator.set_mode/2: ModeManager.set_mode returned {:error, #{inspect(reason)}}")
        emulator
    end
  end

  @doc """
  Resets a terminal mode using the mode manager.
  """
  @spec reset_mode(t(), atom()) :: t()
  def reset_mode(emulator, mode) do
    require Logger
    Logger.debug("Emulator.reset_mode/2 called with mode=#{inspect(mode)}")
    case Raxol.Terminal.ModeManager.reset_mode(emulator, [mode]) do
      {:ok, new_emulator} -> new_emulator
      {:error, _} -> emulator
    end
  end

  # Add helper functions for tests that expect struct access
  def get_cursor_struct_for_test(%__MODULE__{cursor: pid} = emulator)
      when pid?(pid) do
    get_cursor_struct(emulator)
  end

  def get_mode_manager_struct_for_test(%__MODULE__{} = emulator) do
    get_mode_manager_struct(emulator)
  end

  # Override cursor access for tests
  def get_cursor_position_struct(%__MODULE__{cursor: pid} = emulator)
      when pid?(pid) do
    cursor = get_cursor_struct(emulator)
    cursor.position
  end

  def get_cursor_visible_struct(%__MODULE__{cursor: pid} = emulator)
      when pid?(pid) do
    cursor = get_cursor_struct(emulator)
    cursor.visible
  end

  def get_mode_manager_cursor_visible(%__MODULE__{} = emulator) do
    mode_manager = get_mode_manager_struct(emulator)
    mode_manager.cursor_visible
  end

  def clear_line(emulator) do
    # Clear the current line from cursor to end
    Raxol.Terminal.Operations.ScreenOperations.clear_line(emulator)
  end

  def move_cursor_down(emulator, count, _width, _height) do
    move_cursor_down(emulator, count)
  end

  def move_cursor_left(emulator, count, _width, _height) do
    move_cursor_back(emulator, count)
  end

  def move_cursor_right(emulator, count, _width, _height) do
    move_cursor_forward(emulator, count)
  end

  def move_cursor_to_column(emulator, column, _width, _height) do
    {_current_x, current_y} = get_cursor_position(emulator)

    Raxol.Terminal.Commands.CursorHandlers.move_cursor_to(
      emulator,
      current_y,
      column
    )
  end

  def move_cursor_to_line_start(emulator) do
    {_current_x, current_y} = get_cursor_position(emulator)

    Raxol.Terminal.Commands.CursorHandlers.move_cursor_to(
      emulator,
      current_y,
      0
    )
  end

  def move_cursor_up(emulator, count, _width, _height) do
    move_cursor_up(emulator, count)
  end

  # Add missing cursor movement functions
  def move_cursor_forward(emulator, count) do
    cursor = emulator.cursor

    if pid?(cursor) do
      GenServer.call(cursor, {:move_forward, count})
    end

    emulator
  end

  def move_cursor_back(emulator, count) do
    cursor = emulator.cursor

    if pid?(cursor) do
      GenServer.call(cursor, {:move_back, count})
    end

    emulator
  end

  defp find_matching_parser(rest) do
    Enum.find_value(ansi_parsers(), & &1.(rest))
  end

  defp ansi_parsers do
    get_parser_functions()
    |> Enum.map(&Function.capture(__MODULE__, &1, 1))
  end

  defp get_parser_functions do
    [
      :parse_osc,
      :parse_dcs,
      :parse_sgr,
      :parse_csi_cursor_pos,
      :parse_csi_cursor_up,
      :parse_csi_cursor_down,
      :parse_csi_cursor_forward,
      :parse_csi_cursor_back,
      :parse_csi_cursor_show,
      :parse_csi_cursor_hide,
      :parse_csi_clear_screen,
      :parse_csi_clear_line,
      :parse_csi_set_scroll_region,
      :parse_csi_set_mode,
      :parse_csi_reset_mode,
      :parse_csi_set_standard_mode,
      :parse_csi_reset_standard_mode,
      :parse_csi_general,
      :parse_esc_equals,
      :parse_esc_greater,
      :parse_unknown
    ]
  end

  def update_active_buffer(emulator, new_buffer) do
    case emulator.active_buffer_type do
      :main ->
        %{emulator | main_screen_buffer: new_buffer}

      :alternate ->
        %{emulator | alternate_screen_buffer: new_buffer}

      _ ->
        %{emulator | main_screen_buffer: new_buffer}
    end
  end

  # Implement get_scroll_region directly to return the emulator's scroll_region field
  def get_scroll_region(%__MODULE__{} = emulator) do
    emulator.scroll_region
  end

  @doc """
  Moves the cursor to the specified position.
  """
  @spec move_cursor_to(t(), non_neg_integer(), non_neg_integer()) :: t()
  def move_cursor_to(emulator, x, y) do
    Raxol.Terminal.Commands.CursorHandlers.move_cursor_to(emulator, x, y)
  end

  @doc """
  Moves the cursor to the specified position (2-arity version).
  """
  @spec move_cursor_to(t(), {non_neg_integer(), non_neg_integer()}) :: t()
  def move_cursor_to(emulator, {x, y}) do
    move_cursor_to(emulator, x, y)
  end

  @doc """
  Moves the cursor to the specified position.
  """
  @spec move_cursor(t(), non_neg_integer(), non_neg_integer()) :: t()
  def move_cursor(emulator, x, y) do
    Raxol.Terminal.Commands.CursorHandlers.move_cursor_to(emulator, x, y)
  end

  # Missing Raxol.Terminal.OperationsBehaviour implementations

  @doc """
  Gets the bottom scroll position.
  """
  @spec get_scroll_bottom(t()) :: non_neg_integer()
  def get_scroll_bottom(emulator) do
    case emulator.scroll_region do
      {_top, bottom} -> bottom
      nil -> emulator.height - 1
    end
  end

  @doc """
  Gets the top scroll position.
  """
  @spec get_scroll_top(t()) :: non_neg_integer()
  def get_scroll_top(emulator) do
    case emulator.scroll_region do
      {top, _bottom} -> top
      nil -> 0
    end
  end

  @doc """
  Sets the blink rate for the cursor.
  """
  @spec set_blink_rate(t(), non_neg_integer()) :: t()
  def set_blink_rate(emulator, rate) do
    cursor = emulator.cursor

    if pid?(cursor) do
      # Set blink rate in cursor manager
      GenServer.call(cursor, {:set_blink_rate, rate})

      # Also set blink state based on rate
      blinking = rate > 0
      GenServer.call(cursor, {:set_blink, blinking})
    end

    # Store blink rate in emulator state for reference
    %{emulator | cursor_blink_rate: rate}
  end

  @doc """
  Toggles cursor blinking.
  """
  @spec toggle_blink(t()) :: t()
  def toggle_blink(emulator) do
    cursor = emulator.cursor

    if pid?(cursor) do
      current_blinking = GenServer.call(cursor, :get_blink)
      GenServer.call(cursor, {:set_blink, !current_blinking})
    end

    emulator
  end

  @doc """
  Toggles cursor visibility.
  """
  @spec toggle_visibility(t()) :: t()
  def toggle_visibility(emulator) do
    cursor = emulator.cursor

    if pid?(cursor) do
      current_visible = GenServer.call(cursor, :get_visibility)
      GenServer.call(cursor, {:set_visibility, !current_visible})
    end

    emulator
  end

  @doc """
  Updates cursor blinking state.
  """
  @spec update_blink(t()) :: t()
  def update_blink(emulator) do
    cursor = emulator.cursor

    if pid?(cursor) do
      # Update blink state based on timing
      GenServer.call(cursor, :update_blink)
    end

    emulator
  end

  @doc """
  Stops the emulator.
  """
  @spec stop(t()) :: t()
  def stop(emulator) do
    # Perform cleanup first
    emulator = cleanup(emulator)

    # Mark emulator as stopped
    %{emulator | state: :stopped}
  end
end
