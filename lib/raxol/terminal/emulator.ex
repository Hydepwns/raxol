defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  The main terminal emulator module that coordinates all terminal operations.
  This module delegates to specialized manager modules for different aspects of terminal functionality.
  """

  import Raxol.Guards

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
    ScreenBuffer
  }

  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.FormattingManager, as: FormattingManager
  alias Raxol.Terminal.OutputManager, as: OutputManager
  alias Raxol.Terminal.Operations.ScrollOperations, as: ScrollOperations
  alias Raxol.Terminal.Operations.StateOperations, as: StateOperations
  alias Raxol.Terminal.Operations.ScreenOperations, as: Screen

  @behaviour Raxol.Terminal.OperationsBehaviour

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

    # Other fields
    output_buffer: "",
    style: Raxol.Terminal.ANSI.TextFormatting.new(),
    scrollback_limit: 1000,
    window_title: nil,
    plugin_manager: nil,
    saved_cursor: nil,
    scroll_region: nil,
    sixel_state: nil,
    last_col_exceeded: false
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
          output_buffer: String.t(),
          style: Raxol.Terminal.ANSI.TextFormatting.t(),
          scrollback_limit: non_neg_integer(),
          window_title: String.t() | nil,
          plugin_manager: any() | nil,
          saved_cursor: any() | nil,
          scroll_region: any() | nil,
          sixel_state: any() | nil
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

  defdelegate clear_scrollback(emulator), to: Raxol.Terminal.Buffer.Manager

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
  Creates a new terminal emulator instance with default dimensions.
  """
  @spec new() :: t()
  def new() do
    new(80, 24)
  end

  @doc """
  Creates a new terminal emulator instance with given width and height.
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(width, height) do
    main_buffer = Raxol.Terminal.ScreenBuffer.new(width, height)
    alternate_buffer = Raxol.Terminal.ScreenBuffer.new(width, height)
    mode_manager = Raxol.Terminal.ModeManager.new()

    cursor_result = Raxol.Terminal.Cursor.Manager.start_link([])
    cursor_pid = get_pid(cursor_result)

    emulator = %__MODULE__{
      width: width,
      height: height,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,
      mode_manager: mode_manager,
      cursor: cursor_pid,
      style: Raxol.Terminal.ANSI.TextFormatting.new(),
      charset_state: %{
        g0: :us_ascii,
        g1: :us_ascii,
        g2: :us_ascii,
        g3: :us_ascii,
        gl: :g0,
        gr: :g0,
        single_shift: nil
      }
    }

    emulator
  end

  @doc """
  Creates a new terminal emulator instance with given width, height, and options.
  """
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  def new(width, height, opts) do
    state_pid = get_pid(Raxol.Terminal.State.Manager.start_link(opts))
    event_pid = get_pid(Raxol.Terminal.Event.Handler.start_link(opts))

    buffer_pid =
      get_pid(
        Raxol.Terminal.Buffer.Manager.start_link(
          [width: width, height: height] ++ opts
        )
      )

    config_pid =
      get_pid(
        Raxol.Terminal.Config.Manager.start_link(
          [width: width, height: height] ++ opts
        )
      )

    command_pid = get_pid(Raxol.Terminal.Command.Manager.start_link(opts))
    cursor_pid = get_pid(Raxol.Terminal.Cursor.Manager.start_link(opts))
    window_manager_pid = get_pid(Raxol.Terminal.Window.Manager.start_link(opts))
    mode_manager = Raxol.Terminal.ModeManager.new()

    # Initialize screen buffers
    main_buffer = ScreenBuffer.new(width, height)
    alternate_buffer = ScreenBuffer.new(width, height)

    %__MODULE__{
      state: state_pid,
      event: event_pid,
      buffer: buffer_pid,
      config: config_pid,
      command: command_pid,
      cursor: cursor_pid,
      window_manager: window_manager_pid,
      mode_manager: mode_manager,
      active_buffer_type: :main,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,
      width: width,
      height: height,
      output_buffer: "",
      style: Raxol.Terminal.ANSI.TextFormatting.new(),
      scrollback_limit: Keyword.get(opts, :scrollback_limit, 1000)
    }
  end

  @doc """
  Creates a new terminal emulator instance with options map.
  """
  @spec new(map()) :: t()
  def new(%{width: width, height: height} = opts) do
    plugin_manager = Map.get(opts, :plugin_manager)
    emulator = new(width, height, [])

    if plugin_manager do
      %{emulator | plugin_manager: plugin_manager}
    else
      emulator
    end
  end

  defp get_pid({:ok, pid}), do: pid
  defp get_pid({:error, {:already_started, pid}}), do: pid

  defp get_pid({:error, reason}),
    do: raise("Failed to start process: #{inspect(reason)}")

  @doc """
  Processes input data and updates the terminal state accordingly.
  """
  @spec process_input(t(), binary()) :: {t(), binary()}
  def process_input(emulator, input) do
    # Handle character set commands first
    case get_charset_command(input) do
      {field, value} ->
        # If it's a charset command, handle it completely and return
        updated_emulator = %{
          emulator
          | charset_state: %{emulator.charset_state | field => value}
        }

        {updated_emulator, ""}

      :no_match ->
        # Not a charset command, proceed with normal processing
        # Handle ANSI sequences and get remaining text
        {updated_emulator, remaining_text} =
          handle_ansi_sequences(input, emulator)

        IO.puts(
          "DEBUG: After handle_ansi_sequences, scroll_region: #{inspect(updated_emulator.scroll_region)}"
        )

        if remaining_text == "" do
          IO.puts(
            "DEBUG: No remaining text, returning emulator with scroll_region: #{inspect(updated_emulator.scroll_region)}"
          )

          {updated_emulator, ""}
        else
          updated_emulator = handle_text_input(remaining_text, updated_emulator)

          IO.puts(
            "DEBUG: After handle_text_input, scroll_region: #{inspect(updated_emulator.scroll_region)}"
          )

          {updated_emulator, ""}
        end
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
    case parse_ansi_sequence(rest) do
      {:osc, remaining, _} ->
        handle_ansi_sequences(remaining, emulator)

      {:dcs, remaining, _} ->
        handle_ansi_sequences(remaining, emulator)

      {:incomplete, _} ->
        {emulator, rest}

      parsed_sequence ->
        {new_emulator, remaining} =
          handle_parsed_sequence(parsed_sequence, rest, emulator)

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
    {handle_sgr(params, emulator), remaining}
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
         {:csi_general, params, final_byte, remaining},
         _rest,
         emulator
       ) do
    {handle_csi_general(params, final_byte, emulator), remaining}
  end

  defp parse_ansi_sequence(rest) do
    File.write!(
      "tmp/parse_ansi_sequence.log",
      "parse_ansi_sequence input: #{inspect(rest)}\n",
      [:append]
    )

    case find_matching_parser(rest) do
      nil ->
        File.write!(
          "tmp/parse_ansi_sequence.log",
          "parse_ansi_sequence result: nil\n",
          [:append]
        )

        {:incomplete, nil}

      result ->
        File.write!(
          "tmp/parse_ansi_sequence.log",
          "parse_ansi_sequence result: #{inspect(result)}\n",
          [:append]
        )

        result
    end
  end

  def parse_osc(<<0x1B, 0x5D, 0x30, 0x3B, remaining::binary>>) do
    case String.split(remaining, <<0x07>>, parts: 2) do
      [_title, rest] -> {:osc, rest, nil}
      _ -> nil
    end
  end

  def parse_osc(_), do: nil

  def parse_dcs(<<0x1B, 0x50, 0x30, 0x3B, remaining::binary>>) do
    case String.split(remaining, <<0x07>>, parts: 2) do
      [_params, rest] -> {:dcs, rest, nil}
      _ -> nil
    end
  end

  def parse_dcs(_), do: nil

  def parse_csi_cursor_pos(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, <<0x48>>, parts: 2) do
      [params, rest] -> {:csi_cursor_pos, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_cursor_pos(_), do: nil

  def parse_csi_cursor_up(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, <<0x41>>, parts: 2) do
      [params, rest] -> {:csi_cursor_up, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_cursor_up(_), do: nil

  def parse_csi_cursor_down(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, <<0x42>>, parts: 2) do
      [params, rest] -> {:csi_cursor_down, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_cursor_down(_), do: nil

  def parse_csi_cursor_forward(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, <<0x43>>, parts: 2) do
      [params, rest] -> {:csi_cursor_forward, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_cursor_forward(_), do: nil

  def parse_csi_cursor_back(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, <<0x44>>, parts: 2) do
      [params, rest] -> {:csi_cursor_back, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_cursor_back(_), do: nil

  def parse_csi_cursor_show(
        <<0x1B, 0x5B, 0x3F, 0x32, 0x35, 0x68, remaining::binary>>
      ),
      do: {:csi_cursor_show, remaining, nil}

  def parse_csi_cursor_show(_), do: nil

  def parse_csi_cursor_hide(
        <<0x1B, 0x5B, 0x3F, 0x32, 0x35, 0x6C, remaining::binary>>
      ),
      do: {:csi_cursor_hide, remaining, nil}

  def parse_csi_cursor_hide(_), do: nil

  def parse_csi_clear_screen(<<0x1B, 0x5B, 0x32, 0x4A, remaining::binary>>),
    do: {:csi_clear_screen, remaining, nil}

  def parse_csi_clear_screen(_), do: nil

  def parse_csi_clear_line(<<0x1B, 0x5B, 0x32, 0x4B, remaining::binary>>),
    do: {:csi_clear_line, remaining, nil}

  def parse_csi_clear_line(_), do: nil

  def parse_csi_set_mode(<<0x1B, 0x5B, 0x3F, remaining::binary>>) do
    case String.split(remaining, "h", parts: 2) do
      [params, rest] -> {:csi_set_mode, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_set_mode(_), do: nil

  def parse_csi_reset_mode(<<0x1B, 0x5B, 0x3F, remaining::binary>>) do
    case String.split(remaining, "l", parts: 2) do
      [params, rest] -> {:csi_reset_mode, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_reset_mode(_), do: nil

  def parse_csi_set_standard_mode(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, "h", parts: 2) do
      [params, rest] -> {:csi_set_standard_mode, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_set_standard_mode(_), do: nil

  def parse_csi_reset_standard_mode(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, "l", parts: 2) do
      [params, rest] -> {:csi_reset_standard_mode, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_reset_standard_mode(_), do: nil

  def parse_esc_equals(<<0x1B, 0x3D, remaining::binary>>),
    do: {:esc_equals, remaining, nil}

  def parse_esc_equals(_), do: nil

  def parse_esc_greater(<<0x1B, 0x3E, remaining::binary>>),
    do: {:esc_greater, remaining, nil}

  def parse_esc_greater(_), do: nil

  defp handle_cursor_position(params, emulator) do
    case String.split(params, ";") do
      [row_str, col_str] ->
        row = String.to_integer(row_str)
        col = String.to_integer(col_str)
        # Convert from 1-indexed to 0-indexed coordinates
        # Note: move_cursor_to expects (col, row) order
        move_cursor_to(emulator, col - 1, row - 1)

      [pos_str] ->
        pos = String.to_integer(pos_str)
        # Convert from 1-indexed to 0-indexed coordinates
        move_cursor_to(emulator, pos - 1, 0)

      _ ->
        emulator
    end
  end

  defp handle_cursor_up(params, emulator) do
    count =
      case params do
        "" -> 1
        count_str -> String.to_integer(count_str)
      end

    move_cursor_up(emulator, count)
  end

  defp handle_cursor_down(params, emulator) do
    count =
      case params do
        "" -> 1
        count_str -> String.to_integer(count_str)
      end

    move_cursor_down(emulator, count)
  end

  defp handle_cursor_forward(params, emulator) do
    count =
      case params do
        "" -> 1
        count_str -> String.to_integer(count_str)
      end

    move_cursor_forward(emulator, count)
  end

  defp handle_cursor_back(params, emulator) do
    count =
      case params do
        "" -> 1
        count_str -> String.to_integer(count_str)
      end

    move_cursor_back(emulator, count)
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

  defp sgr_code_mappings do
    %{
      0 => fn _style -> Raxol.Terminal.ANSI.TextFormatting.new() end,
      1 => &Raxol.Terminal.ANSI.TextFormatting.set_bold/1,
      4 => &Raxol.Terminal.ANSI.TextFormatting.set_underline/1,
      30 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :black),
      31 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :red),
      32 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :green),
      33 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :yellow),
      34 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :blue),
      35 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :magenta),
      36 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :cyan),
      37 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :white),
      39 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, nil)
    }
  end

  defp log_sgr_debug(msg) do
    File.write!("tmp/sgr_debug.log", msg <> "\n", [:append])
  end

  defp handle_sgr(params, emulator) do
    # Parse SGR parameters (e.g., "31;1;4")
    codes =
      params
      |> String.split(";")
      |> Enum.map(fn code ->
        case Integer.parse(code) do
          {int, _} -> int
          :error -> nil
        end
      end)
      |> Enum.filter(& &1)

    log_sgr_debug("DEBUG: SGR codes parsed: #{inspect(codes)}")

    # Start with current style
    style = emulator.style || Raxol.Terminal.ANSI.TextFormatting.new()

    # Apply each SGR code
    updated_style =
      Enum.reduce(codes, style, fn code, acc ->
        new_style = apply_sgr_code(code, acc)

        log_sgr_debug(
          "DEBUG: After applying SGR code #{code}, style: #{inspect(new_style)}"
        )

        new_style
      end)

    %{emulator | style: updated_style}
  end

  defp apply_sgr_code(code, style) do
    case Map.fetch(sgr_code_mappings(), code) do
      {:ok, update_fn} ->
        result = update_fn.(style)

        log_sgr_debug(
          "DEBUG: apply_sgr_code #{code} => style: #{inspect(result)}"
        )

        result

      :error ->
        style
    end
  end

  defp handle_set_scroll_region(params, emulator) do
    # Debug output
    IO.puts(
      "DEBUG: handle_set_scroll_region called with params: #{inspect(params)}"
    )

    # Parse scroll region parameters (e.g., "2;10")
    case String.split(params, ";") do
      [top_str, bottom_str] ->
        top = String.to_integer(top_str)
        bottom = String.to_integer(bottom_str)
        # Convert from 1-based to 0-based indexing
        result = %{emulator | scroll_region: {top - 1, bottom - 1}}

        IO.puts(
          "DEBUG: Setting scroll region to: #{inspect(result.scroll_region)}"
        )

        result

      [""] ->
        # Empty parameters (e.g., "\e[r") - reset to full viewport
        result = %{emulator | scroll_region: nil}
        IO.puts("DEBUG: Resetting scroll region to nil")
        result

      _ ->
        IO.puts("DEBUG: No valid scroll region parameters found")
        emulator
    end
  end

  defp handle_set_mode(params, emulator) do
    # Handle DEC private mode setting (CSI ?n h)
    case parse_mode_params(params) do
      [mode_code] ->
        case lookup_mode(mode_code) do
          {:ok, mode_name} ->
            set_mode_in_manager(emulator, mode_name, true)

          _ ->
            emulator
        end

      _ ->
        emulator
    end
  end

  defp handle_reset_mode(params, emulator) do
    # Handle DEC private mode resetting (CSI ?n l)
    case parse_mode_params(params) do
      [mode_code] ->
        case lookup_mode(mode_code) do
          {:ok, mode_name} ->
            set_mode_in_manager(emulator, mode_name, false)

          _ ->
            emulator
        end

      _ ->
        emulator
    end
  end

  defp handle_set_standard_mode(params, emulator) do
    # Handle standard mode setting (CSI n h)
    case parse_mode_params(params) do
      [mode_code] ->
        case lookup_standard_mode(mode_code) do
          {:ok, mode_name} ->
            set_mode_in_manager(emulator, mode_name, true)

          _ ->
            emulator
        end

      _ ->
        emulator
    end
  end

  defp handle_reset_standard_mode(params, emulator) do
    # Handle standard mode resetting (CSI n l)
    case parse_mode_params(params) do
      [mode_code] ->
        case lookup_standard_mode(mode_code) do
          {:ok, mode_name} ->
            set_mode_in_manager(emulator, mode_name, false)

          _ ->
            emulator
        end

      _ ->
        emulator
    end
  end

  defp handle_esc_equals(emulator) do
    # ESC = - Application Keypad Mode (DECKPAM)
    set_mode_in_manager(emulator, :decckm, true)
  end

  defp handle_esc_greater(emulator) do
    # ESC > - Normal Keypad Mode (DECKPNM)
    set_mode_in_manager(emulator, :decckm, false)
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
    case Map.fetch(mode_updates(), mode_name) do
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

  @doc """
  Moves the cursor to the specified position with optional width and height constraints.
  """
  @spec move_cursor_to(
          t(),
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer() | nil,
          non_neg_integer() | nil
        ) :: t()
  def move_cursor_to(emulator, {x, y}, _width, _height) do
    cursor = emulator.cursor

    if pid?(cursor) do
      GenServer.call(cursor, {:set_position, x, y})
    end

    emulator
  end

  defp move_cursor_up(emulator, count) do
    cursor = emulator.cursor

    if pid?(cursor) do
      GenServer.call(cursor, {:move_up, count})
    end

    emulator
  end

  defp move_cursor_down(emulator, count) do
    cursor = emulator.cursor

    if pid?(cursor) do
      GenServer.call(cursor, {:move_down, count})
    end

    emulator
  end

  @doc """
  Resets the terminal emulator to its initial state.
  """
  @spec reset(t()) :: t()
  def reset(emulator) do
    emulator
    |> reset_state()
    |> reset_event_handler()
    |> reset_buffer_manager()
    |> reset_config_manager()
    |> reset_command_manager()
    |> reset_window_manager()
  end

  defp reset_state(emulator) do
    %{emulator | state: nil}
  end

  defp reset_event_handler(emulator) do
    %{emulator | event: nil}
  end

  defp reset_buffer_manager(emulator) do
    %{emulator | buffer: nil}
  end

  defp reset_config_manager(emulator) do
    %{emulator | config: nil}
  end

  defp reset_command_manager(emulator) do
    %{emulator | command: nil}
  end

  defp reset_window_manager(emulator) do
    %{emulator | window_manager: nil}
  end

  def update_style(emulator, style_attrs) when is_map(style_attrs) do
    current_style = emulator.style || Raxol.Terminal.ANSI.TextFormatting.new()

    # Convert current_style to TextFormatting struct if it's a plain map
    current_style =
      if Map.has_key?(current_style, :__struct__) do
        current_style
      else
        Raxol.Terminal.ANSI.TextFormatting.new(current_style)
      end

    updated_style =
      Enum.reduce(style_attrs, current_style, &apply_style_attribute/2)

    %{emulator | style: updated_style}
  end

  defp apply_style_attribute({attr, value}, style) do
    case get_style_update_function(attr, value) do
      {:ok, update_fn} -> update_fn.(style)
      :error -> style
    end
  end

  defp get_style_update_function(attr, value) do
    case Map.fetch(get_style_updates(), {attr, value}) do
      {:ok, update_fn} -> {:ok, update_fn}
      :error -> :error
    end
  end

  @style_updates [
    {{:bold, true}, &Raxol.Terminal.ANSI.TextFormatting.set_bold/1},
    {{:bold, false}, &Raxol.Terminal.ANSI.TextFormatting.reset_bold/1},
    {{:faint, true}, &Raxol.Terminal.ANSI.TextFormatting.set_faint/1},
    {{:italic, true}, &Raxol.Terminal.ANSI.TextFormatting.set_italic/1},
    {{:italic, false}, &Raxol.Terminal.ANSI.TextFormatting.reset_italic/1},
    {{:underline, true}, &Raxol.Terminal.ANSI.TextFormatting.set_underline/1},
    {{:underline, false},
     &Raxol.Terminal.ANSI.TextFormatting.reset_underline/1},
    {{:blink, true}, &Raxol.Terminal.ANSI.TextFormatting.set_blink/1},
    {{:blink, false}, &Raxol.Terminal.ANSI.TextFormatting.reset_blink/1},
    {{:reverse, true}, &Raxol.Terminal.ANSI.TextFormatting.set_reverse/1},
    {{:reverse, false}, &Raxol.Terminal.ANSI.TextFormatting.reset_reverse/1},
    {{:conceal, true}, &Raxol.Terminal.ANSI.TextFormatting.set_conceal/1},
    {{:conceal, false}, &Raxol.Terminal.ANSI.TextFormatting.reset_conceal/1},
    {{:crossed_out, true},
     &Raxol.Terminal.ANSI.TextFormatting.set_strikethrough/1},
    {{:crossed_out, false},
     &Raxol.Terminal.ANSI.TextFormatting.reset_strikethrough/1}
  ]

  defp get_style_updates do
    @style_updates |> Map.new()
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

  def cursor_visible?(%__MODULE__{cursor: pid} = emulator) when pid?(pid) do
    cursor = get_cursor_struct(emulator)
    cursor.visible
  end

  def cursor_visible?(%__MODULE__{} = emulator) do
    CursorOperations.cursor_visible?(emulator)
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
        new_cursor = %{cursor | x: new_x, position: {new_x, y}}
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
  def set_mode(%__MODULE__{} = emulator, mode) do
    Raxol.Terminal.ModeManager.set_mode(emulator, [mode])
    emulator
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
    move_cursor_to(emulator, current_y, column)
  end

  def move_cursor_to_line_start(emulator) do
    {_current_x, current_y} = get_cursor_position(emulator)
    move_cursor_to(emulator, current_y, 0)
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

  defp handle_text_input(input, emulator) do
    if printable_text?(input) do
      # Process each codepoint through the character processor for charset translation
      String.to_charlist(input)
      |> Enum.reduce(emulator, fn codepoint, emu ->
        Raxol.Terminal.Input.CharacterProcessor.process_character(
          emu,
          codepoint
        )
      end)
    else
      emulator
    end
  end

  defp printable_text?(input) do
    String.valid?(input) and
      String.length(input) > 0 and
      not String.contains?(input, "\e") and
      String.graphemes(input) |> Enum.all?(&printable_char?/1)
  end

  defp printable_char?(char) do
    # Check if character is printable (not control characters)
    case char do
      <<code::utf8>> when code >= 32 and code <= 126 -> true
      # Extended ASCII and Unicode
      <<code::utf8>> when code >= 160 -> true
      # Allow newline character for command input
      <<10::utf8>> -> true
      _ -> false
    end
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
      :parse_sgr,
      :parse_csi_general,
      :parse_esc_equals,
      :parse_esc_greater,
      :parse_unknown
    ]
  end

  defp mode_updates do
    get_mode_update_mappings()
    |> Enum.map(fn {key, func} ->
      {key, Function.capture(__MODULE__, func, 2)}
    end)
    |> Map.new()
  end

  defp get_mode_update_mappings do
    [
      {:irm, :update_insert_mode_direct},
      {:lnm, :update_line_feed_mode_direct},
      {:decom, :update_origin_mode_direct},
      {:decawm, :update_auto_wrap_direct},
      {:dectcem, :update_cursor_visible_direct},
      {:decscnm, :update_screen_mode_reverse_direct},
      {:decarm, :update_auto_repeat_mode_direct},
      {:decinlm, :update_interlacing_mode_direct},
      {:bracketed_paste, :update_bracketed_paste_mode_direct},
      {:decckm, :update_cursor_keys_mode_direct},
      {:deccolm_132, :update_column_width_132_direct},
      {:deccolm_80, :update_column_width_80_direct},
      {:dec_alt_screen, :update_alternate_buffer_active_direct},
      {:dec_alt_screen_save, :update_alternate_buffer_active_direct},
      {:alt_screen_buffer, :update_alternate_buffer_active_direct}
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

  def parse_csi_set_scroll_region(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, "r", parts: 2) do
      [params, rest] when binary?(params) ->
        {:csi_set_scroll_region, params, rest, nil}

      _ ->
        nil
    end
  end

  def parse_csi_set_scroll_region(_), do: nil

  def parse_csi_general(<<0x1B, 0x5B, remaining::binary>>) do
    # Match any CSI sequence ending with a valid final byte (A-Z, a-z)
    case Regex.run(~r/^([0-9;:]*)([A-Za-z])(.*)/, remaining) do
      [_, params, final_byte, rest] ->
        {:csi_general, params, final_byte, rest}

      _ ->
        nil
    end
  end

  def parse_csi_general(_), do: nil

  def parse_sgr(<<0x1B, 0x5B, remaining::binary>>) do
    # Only match if the remaining part contains 'm' and has valid SGR parameters
    case String.split(remaining, "m", parts: 2) do
      [params, rest] when binary?(params) and byte_size(params) > 0 ->
        # Validate that params contains only digits, semicolons, and colons
        if String.match?(params, ~r/^[\d;:]*$/) do
          {:sgr, params, rest, nil}
        else
          nil
        end

      _ ->
        nil
    end
  end

  def parse_sgr(_), do: nil

  def parse_unknown(<<0x1B, remaining::binary>>) do
    # Skip one character after ESC
    case remaining do
      <<_char, rest::binary>> -> {:unknown, rest, nil}
      _ -> nil
    end
  end

  def parse_unknown(_), do: nil

  # Implement get_scroll_region directly to return the emulator's scroll_region field
  def get_scroll_region(%__MODULE__{} = emulator) do
    emulator.scroll_region
  end

  # Missing functions that are being called by tests
  # These should update the mode manager state

  @doc """
  Updates the insert mode in the mode manager.
  """
  @spec update_insert_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
          Raxol.Terminal.ModeManager.t()
  def update_insert_mode_direct(mode_manager, value) do
    %{mode_manager | insert_mode: value}
  end

  @doc """
  Updates the alternate buffer active state in the mode manager.
  """
  @spec update_alternate_buffer_active_direct(
          Raxol.Terminal.ModeManager.t(),
          boolean()
        ) :: Raxol.Terminal.ModeManager.t()
  def update_alternate_buffer_active_direct(mode_manager, value) do
    %{mode_manager | alternate_buffer_active: value}
  end

  @doc """
  Updates the cursor keys mode in the mode manager.
  """
  @spec update_cursor_keys_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
          Raxol.Terminal.ModeManager.t()
  def update_cursor_keys_mode_direct(mode_manager, value) do
    %{
      mode_manager
      | cursor_keys_mode: if(value, do: :application, else: :normal)
    }
  end

  @doc """
  Updates the origin mode in the mode manager.
  """
  @spec update_origin_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
          Raxol.Terminal.ModeManager.t()
  def update_origin_mode_direct(mode_manager, value) do
    %{mode_manager | origin_mode: value}
  end

  @doc """
  Updates the line feed mode in the mode manager.
  """
  @spec update_line_feed_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
          Raxol.Terminal.ModeManager.t()
  def update_line_feed_mode_direct(mode_manager, value) do
    %{mode_manager | line_feed_mode: value}
  end

  @doc """
  Updates the auto wrap mode in the mode manager.
  """
  @spec update_auto_wrap_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
          Raxol.Terminal.ModeManager.t()
  def update_auto_wrap_direct(mode_manager, value) do
    %{mode_manager | auto_wrap: value}
  end

  @doc """
  Updates the cursor visible mode in the mode manager.
  """
  @spec update_cursor_visible_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
          Raxol.Terminal.ModeManager.t()
  def update_cursor_visible_direct(mode_manager, value) do
    %{mode_manager | cursor_visible: value}
  end

  @doc """
  Updates the screen mode reverse in the mode manager.
  """
  @spec update_screen_mode_reverse_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
          Raxol.Terminal.ModeManager.t()
  def update_screen_mode_reverse_direct(mode_manager, value) do
    %{mode_manager | screen_mode_reverse: value}
  end

  @doc """
  Updates the auto repeat mode in the mode manager.
  """
  @spec update_auto_repeat_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
          Raxol.Terminal.ModeManager.t()
  def update_auto_repeat_mode_direct(mode_manager, value) do
    %{mode_manager | auto_repeat_mode: value}
  end

  @doc """
  Updates the interlacing mode in the mode manager.
  """
  @spec update_interlacing_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
          Raxol.Terminal.ModeManager.t()
  def update_interlacing_mode_direct(mode_manager, value) do
    %{mode_manager | interlacing_mode: value}
  end

  @doc """
  Updates the bracketed paste mode in the mode manager.
  """
  @spec update_bracketed_paste_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
          Raxol.Terminal.ModeManager.t()
  def update_bracketed_paste_mode_direct(mode_manager, value) do
    %{mode_manager | bracketed_paste_mode: value}
  end

  @doc """
  Updates the column width 132 mode in the mode manager.
  """
  @spec update_column_width_132_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
          Raxol.Terminal.ModeManager.t()
  def update_column_width_132_direct(mode_manager, value) do
    %{mode_manager | column_width_mode: if(value, do: :wide, else: :normal)}
  end

  @doc """
  Updates the column width 80 mode in the mode manager.
  """
  @spec update_column_width_80_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
          Raxol.Terminal.ModeManager.t()
  def update_column_width_80_direct(mode_manager, value) do
    %{mode_manager | column_width_mode: if(value, do: :normal, else: :wide)}
  end

  defp handle_csi_general(params, final_byte, emulator) do
    case final_byte do
      "J" ->
        # ED - Erase Display
        handle_ed_command(params, emulator)

      "K" ->
        # EL - Erase Line
        handle_el_command(params, emulator)

      "H" ->
        # CUP - Cursor Position
        handle_cursor_position(params, emulator)

      "A" ->
        # CUU - Cursor Up
        handle_cursor_up(params, emulator)

      "B" ->
        # CUD - Cursor Down
        handle_cursor_down(params, emulator)

      "C" ->
        # CUF - Cursor Forward
        handle_cursor_forward(params, emulator)

      "D" ->
        # CUB - Cursor Back
        handle_cursor_back(params, emulator)

      _ ->
        # Unknown CSI command, ignore
        emulator
    end
  end

  defp handle_ed_command(params, emulator) do
    # Parse the mode parameter (default to 0 if not specified)
    mode =
      case params do
        "" ->
          0

        mode_str ->
          case Integer.parse(mode_str) do
            {val, _} -> val
            :error -> 0
          end
      end

    IO.puts(
      "DEBUG: handle_ed_command called with params='#{params}', mode=#{mode}"
    )

    IO.puts(
      "DEBUG: cursor position: #{inspect(Raxol.Terminal.Emulator.get_cursor_position(emulator))}"
    )

    # Call the appropriate erase function based on mode
    case mode do
      # From cursor to end
      0 ->
        Raxol.Terminal.Operations.ScreenOperations.erase_in_display(emulator, 0)

      # From start to cursor
      1 ->
        Raxol.Terminal.Operations.ScreenOperations.erase_in_display(emulator, 1)

      # Entire screen
      2 ->
        Raxol.Terminal.Operations.ScreenOperations.erase_in_display(emulator, 2)

      _ ->
        emulator
    end
  end

  defp handle_el_command(params, emulator) do
    # Parse the mode parameter (default to 0 if not specified)
    mode =
      case params do
        "" ->
          0

        mode_str ->
          case Integer.parse(mode_str) do
            {val, _} -> val
            :error -> 0
          end
      end

    # Call the appropriate erase function based on mode
    case mode do
      # From cursor to end of line
      0 -> Raxol.Terminal.Operations.ScreenOperations.erase_in_line(emulator, 0)
      # From start of line to cursor
      1 -> Raxol.Terminal.Operations.ScreenOperations.erase_in_line(emulator, 1)
      # Entire line
      2 -> Raxol.Terminal.Operations.ScreenOperations.erase_in_line(emulator, 2)
      _ -> emulator
    end
  end

  @doc """
  Moves the cursor to the specified position.
  """
  @spec move_cursor_to(t(), non_neg_integer(), non_neg_integer()) :: t()
  def move_cursor_to(emulator, x, y) do
    move_cursor_to(emulator, {x, y}, nil, nil)
  end
end
