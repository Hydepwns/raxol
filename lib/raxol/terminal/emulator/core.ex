defmodule Raxol.Terminal.Emulator.Core do
  @moduledoc """
  Core functionality for the terminal emulator.
  Handles basic initialization, state management, and fundamental operations.
  """

  require Logger

  alias Raxol.Terminal.{
    ScreenBuffer,
    Buffer.Manager,
    Cursor.Manager,
    ANSI.CharacterSets,
    ANSI.TextFormatting,
    ANSI.TerminalState,
    ModeManager,
    Parser,
    Plugins.PluginManager,
    State.Manager,
    Command.Manager
  }

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
          current_command_buffer: String.t(),
          last_key_event: map() | nil,
          width: non_neg_integer(),
          height: non_neg_integer(),
          state: StateManager.t(),
          command: CommandManager.t(),
          window_state: window_state()
        }

  @type cursor_style_type ::
          :blinking_block
          | :steady_block
          | :blinking_underline
          | :steady_underline
          | :blinking_bar
          | :steady_bar

  @type window_state :: %{
          title: String.t(),
          icon_name: String.t(),
          size: {non_neg_integer(), non_neg_integer()},
          position: {non_neg_integer(), non_neg_integer()},
          stacking_order: :normal | :maximized | :iconified,
          iconified: boolean(),
          maximized: boolean(),
          previous_size: {non_neg_integer(), non_neg_integer()} | nil
        }

  defstruct [
    :main_screen_buffer,
    :alternate_screen_buffer,
    :active_buffer_type,
    :cursor,
    :scroll_region,
    :style,
    :memory_limit,
    :charset_state,
    :mode_manager,
    :plugin_manager,
    :options,
    :current_hyperlink_url,
    :window_title,
    :icon_name,
    :tab_stops,
    :output_buffer,
    :cursor_style,
    :parser_state,
    :command_history,
    :max_command_history,
    :current_command_buffer,
    :last_key_event,
    :width,
    :height,
    :state,
    :command,
    :window_state
  ]

  @doc """
  Creates a new terminal emulator instance with the specified dimensions and options.
  """
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  def new(width \\ 80, height \\ 24, opts \\ []) do
    scrollback_limit = Keyword.get(opts, :scrollback, 1000)
    memory_limit = Keyword.get(opts, :memorylimit, 1_000_000)
    max_command_history_opt = Keyword.get(opts, :max_command_history, 100)
    plugin_manager = PluginManager.new()
    initial_cursor = Manager.new()
    initial_mode_manager = ModeManager.new()
    initial_charset_state = CharacterSets.new()
    initial_state_stack = TerminalState.new()
    initial_parser_state = %Parser.State{}
    command_manager = CommandManager.new()

    # Initialize buffers through BufferManager
    {main_buffer, alternate_buffer} =
      Manager.initialize_buffers(width, height, scrollback_limit)

    %__MODULE__{
      cursor: initial_cursor,
      style: TextFormatting.new(),
      charset_state: initial_charset_state,
      mode_manager: initial_mode_manager,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,
      active_buffer_type: :main,
      scroll_region: nil,
      memory_limit: memory_limit,
      tab_stops: Manager.default_tab_stops(width),
      plugin_manager: plugin_manager,
      parser_state: initial_parser_state,
      options: %{},
      current_hyperlink_url: nil,
      window_title: nil,
      icon_name: nil,
      output_buffer: "",
      cursor_style: :blinking_block,
      command_history: [],
      max_command_history: max_command_history_opt,
      current_command_buffer: "",
      last_key_event: nil,
      width: width,
      height: height,
      state: initial_state_stack,
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
      }
    }
  end

  @doc """
  Returns the currently active screen buffer.
  """
  @spec get_active_buffer(t()) :: ScreenBuffer.t()
  def get_active_buffer(%__MODULE__{active_buffer_type: :main} = emulator) do
    emulator.main_screen_buffer
  end

  def get_active_buffer(%__MODULE__{active_buffer_type: :alternate} = emulator) do
    emulator.alternate_screen_buffer
  end

  @doc """
  Returns the current cursor position.
  """
  @spec get_cursor_position(t()) :: {non_neg_integer(), non_neg_integer()}
  def get_cursor_position(%__MODULE__{} = emulator) do
    emulator.cursor.position
  end

  @doc """
  Returns the current window title.
  """
  @spec get_window_title(t()) :: String.t() | nil
  def get_window_title(%__MODULE__{} = emulator) do
    emulator.window_title
  end

  @doc """
  Returns the current icon name.
  """
  @spec get_icon_name(t()) :: String.t() | nil
  def get_icon_name(%__MODULE__{} = emulator) do
    emulator.icon_name
  end

  @doc """
  Returns the current window state.
  """
  @spec get_window_state(t()) :: window_state()
  def get_window_state(%__MODULE__{} = emulator) do
    emulator.window_state
  end

  @doc """
  Returns the current command history.
  """
  @spec get_command_history(t()) :: list()
  def get_command_history(%__MODULE__{} = emulator) do
    emulator.command_history
  end

  @doc """
  Returns the current command buffer.
  """
  @spec get_command_buffer(t()) :: String.t()
  def get_command_buffer(%__MODULE__{} = emulator) do
    emulator.current_command_buffer
  end

  @doc """
  Returns the current output buffer.
  """
  @spec get_output_buffer(t()) :: String.t()
  def get_output_buffer(%__MODULE__{} = emulator) do
    emulator.output_buffer
  end
end
