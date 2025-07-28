defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  The main terminal emulator module that coordinates all terminal operations.
  This module has been refactored to delegate complex operations to specialized modules.
  """

  alias Raxol.Terminal.Emulator.Coordinator
  alias Raxol.Terminal.Emulator.ModeOperations

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

    # Buffer manager storage
    active: nil,
    alternate: nil,

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
    max_command_history: 100,

    # Scrollback buffer
    scrollback_buffer: [],

    # Output buffer
    output_buffer: [],
    current_command_buffer: "",

    # Manager PIDs
    screen_buffer_manager: nil,
    output_manager: nil,
    cursor_manager: nil,
    scrollback_manager: nil,
    selection_manager: nil,
    mode_manager_pid: nil,
    style_manager: nil,

    # Additional state
    damage_tracker: nil,
    mode_state: %{},
    style: nil,
    cursor_style: :block,
    saved_cursor: nil,
    scroll_region: {0, 23},
    scrollback_limit: 1000,
    memory_limit: 10_000_000,
    session_id: "",
    client_options: %{},
    window_title: nil,
    last_col_exceeded: false,
    icon_name: nil,
    tab_stops: [],
    color_palette: %{},
    last_key_event: nil,
    current_hyperlink: nil,
    active_buffer: nil,
    alternate_screen_buffer: nil,
    sixel_state: nil,
    cursor_blink_rate: 500,
    
    # Device status flags
    device_status_reported: false,
    cursor_position_reported: false,
    notification_manager: nil,
    clipboard_manager: nil,
    hyperlink_manager: nil,
    font_manager: nil,
    color_manager: nil,
    capabilities_manager: nil,
    device_status_manager: nil,
    graphics_manager: nil,
    input_manager: nil,
    metrics_manager: nil,
    mouse_manager: nil,
    plugin_manager: nil,
    registry: nil,
    renderer: nil,
    scroll_manager: nil,
    session_manager: nil,
    state_manager: nil,
    supervisor: nil,
    sync_manager: nil,
    tab_manager: nil,
    terminal_state_manager: nil,
    theme_manager: nil,
    validation_service: nil,
    window_registry: nil
  ]

  @type t :: %__MODULE__{
          state: any(),
          event: any(),
          buffer: any(),
          config: any(),
          command: any(),
          cursor: any(),
          window_manager: any(),
          mode_manager: any(),
          active_buffer_type: atom(),
          main_screen_buffer: any(),
          active: any(),
          alternate: any(),
          charset_state: map(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          window_state: map(),
          state_stack: list(),
          parser_state: any(),
          command_history: list(),
          max_command_history: non_neg_integer(),
          scrollback_buffer: list(),
          output_buffer: list(),
          current_command_buffer: String.t(),
          screen_buffer_manager: any(),
          output_manager: any(),
          cursor_manager: any(),
          scrollback_manager: any(),
          selection_manager: any(),
          mode_manager_pid: any(),
          style_manager: any(),
          damage_tracker: any(),
          mode_state: map(),
          style: any(),
          cursor_style: atom(),
          saved_cursor: any(),
          scroll_region: tuple(),
          scrollback_limit: non_neg_integer(),
          memory_limit: non_neg_integer(),
          session_id: String.t(),
          client_options: map(),
          window_title: String.t() | nil,
          last_col_exceeded: boolean(),
          icon_name: String.t() | nil,
          tab_stops: list(),
          color_palette: map(),
          last_key_event: any(),
          current_hyperlink: any(),
          active_buffer: any(),
          alternate_screen_buffer: any(),
          sixel_state: any(),
          cursor_blink_rate: non_neg_integer(),
          device_status_reported: boolean(),
          cursor_position_reported: boolean(),
          notification_manager: any(),
          clipboard_manager: any(),
          hyperlink_manager: any(),
          font_manager: any(),
          color_manager: any(),
          capabilities_manager: any(),
          device_status_manager: any(),
          graphics_manager: any(),
          input_manager: any(),
          metrics_manager: any(),
          mouse_manager: any(),
          plugin_manager: any(),
          registry: any(),
          renderer: any(),
          scroll_manager: any(),
          session_manager: any(),
          state_manager: any(),
          supervisor: any(),
          sync_manager: any(),
          tab_manager: any(),
          terminal_state_manager: any(),
          theme_manager: any(),
          validation_service: any(),
          window_registry: any()
        }

  # Cursor operations
  def get_cursor_position(emulator),
    do: Raxol.Terminal.Operations.CursorOperations.get_cursor_position(emulator)

  def set_cursor_position(emulator, x, y),
    do:
      Raxol.Terminal.Operations.CursorOperations.set_cursor_position(
        emulator,
        x,
        y
      )

  def get_cursor_style(emulator),
    do: Raxol.Terminal.Operations.CursorOperations.get_cursor_style(emulator)

  def set_cursor_style(emulator, style),
    do:
      Raxol.Terminal.Operations.CursorOperations.set_cursor_style(
        emulator,
        style
      )

  def cursor_visible?(emulator),
    do: Raxol.Terminal.Operations.CursorOperations.cursor_visible?(emulator)

  def get_cursor_visible(emulator),
    do: Raxol.Terminal.Operations.CursorOperations.cursor_visible?(emulator)

  def get_cursor_position_struct(emulator),
    do: Raxol.Terminal.Emulator.Helpers.get_cursor_position_struct(emulator)

  def get_mode_manager_cursor_visible(emulator),
    do: Raxol.Terminal.Emulator.Helpers.get_mode_manager_cursor_visible(emulator)

  def set_cursor_visibility(emulator, visible),
    do:
      Raxol.Terminal.Operations.CursorOperations.set_cursor_visibility(
        emulator,
        visible
      )

  def cursor_blinking?(emulator),
    do: Raxol.Terminal.Operations.CursorOperations.cursor_blinking?(emulator)

  def set_cursor_blink(emulator, blinking),
    do:
      Raxol.Terminal.Operations.CursorOperations.set_cursor_blink(
        emulator,
        blinking
      )

  def blinking?(emulator),
    do: Raxol.Terminal.Operations.CursorOperations.cursor_blinking?(emulator)

  # Screen operations
  def clear_screen(emulator),
    do: Raxol.Terminal.Operations.ScreenOperations.clear_screen(emulator)

  def clear_line(emulator, line),
    do: Raxol.Terminal.Operations.ScreenOperations.clear_line(emulator, line)

  def erase_display(emulator, mode),
    do: Raxol.Terminal.Operations.ScreenOperations.erase_display(emulator, mode)

  def erase_in_display(emulator, mode),
    do:
      Raxol.Terminal.Operations.ScreenOperations.erase_in_display(
        emulator,
        mode
      )

  def erase_line(emulator, mode),
    do: Raxol.Terminal.Operations.ScreenOperations.erase_line(emulator, mode)

  def erase_in_line(emulator, mode),
    do: Raxol.Terminal.Operations.ScreenOperations.erase_in_line(emulator, mode)

  def erase_from_cursor_to_end(emulator),
    do:
      Raxol.Terminal.Operations.ScreenOperations.erase_from_cursor_to_end(
        emulator
      )

  def erase_from_start_to_cursor(emulator),
    do:
      Raxol.Terminal.Operations.ScreenOperations.erase_from_start_to_cursor(
        emulator
      )

  def erase_chars(emulator, count),
    do: Raxol.Terminal.Operations.ScreenOperations.erase_chars(emulator, count)

  # Text operations
  def insert_char(emulator, char),
    do: Raxol.Terminal.Operations.TextOperations.insert_char(emulator, char)

  def insert_chars(emulator, count),
    do: Raxol.Terminal.Operations.TextOperations.insert_chars(emulator, count)

  def delete_char(emulator),
    do: Raxol.Terminal.Operations.TextOperations.delete_char(emulator)

  def delete_chars(emulator, count),
    do: Raxol.Terminal.Operations.TextOperations.delete_chars(emulator, count)

  def write_text(emulator, text),
    do: Raxol.Terminal.Operations.TextOperations.write_text(emulator, text)

  # Selection operations
  def start_selection(emulator, x, y),
    do:
      Raxol.Terminal.Operations.SelectionOperations.start_selection(
        emulator,
        x,
        y
      )

  def update_selection(emulator, x, y),
    do:
      Raxol.Terminal.Operations.SelectionOperations.update_selection(
        emulator,
        x,
        y
      )

  def end_selection(emulator),
    do: Raxol.Terminal.Operations.SelectionOperations.end_selection(emulator)

  def clear_selection(emulator),
    do: Raxol.Terminal.Operations.SelectionOperations.clear_selection(emulator)

  def get_selection(emulator),
    do: Raxol.Terminal.Operations.SelectionOperations.get_selection(emulator)

  def has_selection?(emulator),
    do: Raxol.Terminal.Operations.SelectionOperations.has_selection?(emulator)

  # Scroll operations
  def scroll_up(emulator, lines),
    do: Raxol.Terminal.Operations.ScrollOperations.scroll_up(emulator, lines)

  def scroll_down(emulator, lines),
    do: Raxol.Terminal.Operations.ScrollOperations.scroll_down(emulator, lines)

  # State operations
  def save_state(emulator),
    do: Raxol.Terminal.Operations.StateOperations.save_state(emulator)

  def restore_state(emulator),
    do: Raxol.Terminal.Operations.StateOperations.restore_state(emulator)

  # Buffer operations
  def switch_to_alternate_screen(emulator),
    do:
      Raxol.Terminal.Emulator.BufferOperations.switch_to_alternate_screen(
        emulator
      )

  def switch_to_normal_screen(emulator),
    do:
      Raxol.Terminal.Emulator.BufferOperations.switch_to_normal_screen(emulator)

  def clear_scrollback(emulator),
    do: Raxol.Terminal.Emulator.BufferOperations.clear_scrollback(emulator)

  def update_active_buffer(emulator, buffer),
    do:
      Raxol.Terminal.Emulator.BufferOperations.update_active_buffer(
        emulator,
        buffer
      )

  def write_to_output(emulator, data),
    do: Raxol.Terminal.Emulator.BufferOperations.write_to_output(emulator, data)

  # Dimension and property operations
  def get_width(emulator),
    do: Raxol.Terminal.Emulator.Dimensions.get_width(emulator)

  def get_height(emulator),
    do: Raxol.Terminal.Emulator.Dimensions.get_height(emulator)

  def get_scroll_region(emulator),
    do: Raxol.Terminal.Emulator.Dimensions.get_scroll_region(emulator)

  def visible?(emulator),
    do: Raxol.Terminal.Operations.CursorOperations.cursor_visible?(emulator)

  # Constructor functions - delegate to Coordinator
  def new(width \\ 80, height \\ 24), do: Coordinator.new(width, height)
  def new(width, height, opts), do: Coordinator.new(width, height, opts)

  def new(width, height, session_id, client_options) do
    opts = [session_id: session_id, client_options: client_options]
    {:ok, Coordinator.new(width, height, opts)}
  end

  # Reset and cleanup functions - delegate to Coordinator
  def reset(emulator), do: Coordinator.reset(emulator)

  # Resize function - delegate to Coordinator
  def resize(emulator, new_width, new_height) do
    Coordinator.resize(emulator, new_width, new_height)
  end

  # Complex coordination operations
  def move_cursor(emulator, x, y), do: Coordinator.move_cursor(emulator, x, y)

  def clear_screen_and_home(emulator),
    do: Coordinator.clear_screen_and_home(emulator)

  def validate_dimensions(width, height),
    do: Coordinator.validate_dimensions(width, height)

  # Mode update functions - simplified implementations
  def update_insert_mode(emulator, enabled) do
    mode_state = Map.put(emulator.mode_state, :insert_mode, enabled)
    {:ok, %{emulator | mode_state: mode_state}}
  end

  def update_auto_wrap_mode(emulator, enabled) do
    mode_state = Map.put(emulator.mode_state, :auto_wrap, enabled)
    {:ok, %{emulator | mode_state: mode_state}}
  end

  # Helper functions for tests and backwards compatibility
  def get_screen_buffer(%{active_buffer_type: :alternate, alternate_screen_buffer: buffer}) when buffer != nil, do: buffer
  def get_screen_buffer(%{main_screen_buffer: buffer}), do: buffer
  def get_screen_buffer(_), do: nil

  # Note: get_cursor_position/1 is already defined by cursor_delegations() macro

  def set_dimensions(emulator, width, height) do
    case Coordinator.validate_dimensions(width, height) do
      {:ok, _} -> {:ok, %{emulator | width: width, height: height}}
      error -> error
    end
  end

  # Legacy compatibility functions
  def get_output_buffer(_emulator), do: {:ok, []}
  def apply_color_changes(emulator), do: {:ok, emulator}
  def update_blink_state(emulator), do: {:ok, emulator}

  @doc """
  Processes input and returns updated emulator with output.
  """
  def process_input(emulator, input) do
    # Delegate to input processor
    case Raxol.Terminal.Input.CoreHandler.process_terminal_input(
           emulator,
           input
         ) do
      {updated_emulator, output} when is_binary(output) ->
        {updated_emulator, output}

      {updated_emulator, _} ->
        {updated_emulator, ""}

      updated_emulator when is_map(updated_emulator) ->
        {updated_emulator, ""}

      _ ->
        {emulator, ""}
    end
  end

  # Additional missing functions needed by various modules
  def get_scrollback(emulator), do: emulator.scrollback_buffer || []
  def maybe_scroll(emulator), do: emulator
  def set_mode(emulator, mode), do: ModeOperations.set_mode(emulator, mode)
  def reset_mode(emulator, mode), do: ModeOperations.reset_mode(emulator, mode)
  def set_attribute(emulator, _attr, _value), do: emulator
  def get_mode_manager(emulator), do: emulator.mode_manager
  def get_config_struct(emulator),
    do: Raxol.Terminal.Emulator.Helpers.get_config_struct(emulator)
  def move_cursor_to(emulator, x, y), do: move_cursor(emulator, x, y)
  def move_cursor_to(emulator, x, y, _opts), do: move_cursor(emulator, x, y)
  def move_cursor_up(emulator, _count), do: emulator
  def move_cursor_down(emulator, _count), do: emulator
  def move_cursor_forward(emulator, _count), do: emulator
  def move_cursor_back(emulator, _count), do: emulator
  def handle_esc_equals(emulator) do
    # DECKPAM - Enable application keypad mode (ESC =)
    require Logger
    Logger.debug("Emulator.handle_esc_equals called - setting decckm mode")
    Logger.debug("Initial cursor_keys_mode: #{inspect(emulator.mode_manager.cursor_keys_mode)}")
    
    result = ModeOperations.set_mode(emulator, :decckm)
    
    case result do
      {:ok, new_emulator} ->
        Logger.debug("ModeOperations.set_mode succeeded")
        Logger.debug("Final cursor_keys_mode: #{inspect(new_emulator.mode_manager.cursor_keys_mode)}")
        new_emulator
      {:error, reason} ->
        Logger.debug("ModeOperations.set_mode failed: #{inspect(reason)}")
        emulator
    end
  end
  
  def handle_esc_greater(emulator) do
    # DECKPNM - Disable application keypad mode (ESC >)
    require Logger
    Logger.debug("Emulator.handle_esc_greater called - resetting decckm mode")
    Logger.debug("Initial cursor_keys_mode: #{inspect(emulator.mode_manager.cursor_keys_mode)}")
    
    result = ModeOperations.reset_mode(emulator, :decckm)
    
    case result do
      {:ok, new_emulator} ->
        Logger.debug("ModeOperations.reset_mode succeeded")
        Logger.debug("Final cursor_keys_mode: #{inspect(new_emulator.mode_manager.cursor_keys_mode)}")
        new_emulator
      {:error, reason} ->
        Logger.debug("ModeOperations.reset_mode failed: #{inspect(reason)}")
        emulator
    end
  end
end
