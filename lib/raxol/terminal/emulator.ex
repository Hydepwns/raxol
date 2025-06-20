defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  The main terminal emulator module that coordinates all terminal operations.
  This module delegates to specialized manager modules for different aspects of terminal functionality.
  """

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

    # Dimensions
    width: 80,
    height: 24,

    # Other fields
    output_buffer: "",
    style: %{},
    scrollback_limit: 1000
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
    width: non_neg_integer(),
    height: non_neg_integer(),
    output_buffer: String.t(),
    style: map(),
    scrollback_limit: non_neg_integer()
  }

  # Cursor Operations
  defdelegate get_cursor_position(emulator), to: CursorOperations
  defdelegate set_cursor_position(emulator, x, y), to: CursorOperations
  defdelegate get_cursor_style(emulator), to: CursorOperations
  defdelegate set_cursor_style(emulator, style), to: CursorOperations
  defdelegate cursor_visible?(emulator), to: CursorOperations
  defdelegate get_cursor_visible(emulator), to: CursorOperations, as: :cursor_visible?
  defdelegate set_cursor_visibility(emulator, visible), to: CursorOperations
  defdelegate cursor_blinking?(emulator), to: CursorOperations
  defdelegate set_cursor_blink(emulator, blinking), to: CursorOperations

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
  defdelegate write_string(emulator, x, y, string, style), to: TextOperations
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
  defdelegate get_scroll_region(emulator), to: ScrollOperations
  defdelegate set_scroll_region(emulator, region), to: ScrollOperations

  # State Operations
  defdelegate get_state(emulator), to: StateOperations
  defdelegate get_style(emulator), to: StateOperations
  defdelegate get_style_at(emulator, x, y), to: StateOperations
  defdelegate get_style_at_cursor(emulator), to: StateOperations

  # Buffer Operations
  defdelegate get_active_buffer(emulator), to: Buffer.Manager
  defdelegate update_active_buffer(emulator, new_buffer), to: Buffer.Manager

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
    state_pid = get_pid(Raxol.Terminal.State.Manager.start_link())
    event_pid = get_pid(Raxol.Terminal.Event.Handler.start_link())
    buffer_pid = get_pid(Raxol.Terminal.Buffer.Manager.start_link(width: width, height: height))
    config_pid = get_pid(Raxol.Terminal.Config.Manager.start_link(width: width, height: height))
    command_pid = get_pid(Raxol.Terminal.Command.Manager.start_link())
    cursor_pid = get_pid(Raxol.Terminal.Cursor.Manager.start_link())
    window_manager_pid = get_pid(Raxol.Terminal.Window.Manager.start_link())
    mode_manager_pid = get_pid(Raxol.Terminal.ModeManager.start_link([]))

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
      mode_manager: mode_manager_pid,
      active_buffer_type: :main,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,
      width: width,
      height: height,
      output_buffer: "",
      style: %{},
      scrollback_limit: 1000
    }
  end

  @doc """
  Creates a new terminal emulator instance with given width, height, and options.
  """
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  def new(width, height, opts) do
    state_pid = get_pid(Raxol.Terminal.State.Manager.start_link(opts))
    event_pid = get_pid(Raxol.Terminal.Event.Handler.start_link(opts))
    buffer_pid = get_pid(Raxol.Terminal.Buffer.Manager.start_link([width: width, height: height] ++ opts))
    config_pid = get_pid(Raxol.Terminal.Config.Manager.start_link([width: width, height: height] ++ opts))
    command_pid = get_pid(Raxol.Terminal.Command.Manager.start_link(opts))
    cursor_pid = get_pid(Raxol.Terminal.Cursor.Manager.start_link(opts))
    window_manager_pid = get_pid(Raxol.Terminal.Window.Manager.start_link(opts))
    mode_manager_pid = get_pid(Raxol.Terminal.ModeManager.start_link(opts))

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
      mode_manager: mode_manager_pid,
      active_buffer_type: :main,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,
      width: width,
      height: height,
      output_buffer: "",
      style: %{},
      scrollback_limit: Keyword.get(opts, :scrollback_limit, 1000)
    }
  end

  defp get_pid({:ok, pid}), do: pid
  defp get_pid({:error, {:already_started, pid}}), do: pid
  defp get_pid({:error, reason}), do: raise "Failed to start process: #{inspect(reason)}"

  @doc """
  Processes input data and updates the terminal state accordingly.
  """
  @spec process_input(t(), binary()) :: t()
  def process_input(emulator, input) do
    # Example: write input at cursor position (0, 0) with default style
    write_string(emulator, 0, 0, input, %{})
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

  def move_cursor_to(emulator, {x, y}, width, height) do
    set_cursor_position(emulator, x, y)
  end

  def update_style(emulator, style) do
    %{emulator | style: FormattingManager.update_style(emulator.style || %{}, style).style}
  end

  def write_to_output(emulator, data) do
    OutputManager.write(emulator, data)
  end

  def update_scroll_region(emulator, {top, bottom}) do
    ScrollOperations.set_scroll_region(emulator, {top, bottom})
  end

  def clear_from_cursor_to_end(emulator, x, y) do
    ScreenOperations.erase_from_cursor_to_end(emulator)
  end

  def clear_from_start_to_cursor(emulator, x, y) do
    ScreenOperations.erase_from_start_to_cursor(emulator)
  end

  def clear_entire_screen(emulator) do
    ScreenOperations.clear_screen(emulator)
  end

  def clear_entire_screen_and_scrollback(emulator) do
    emulator = clear_entire_screen(emulator)
    %{emulator | scrollback_buffer: []}
  end

  def clear_from_cursor_to_end_of_line(emulator, x, y) do
    Screen.clear_line(emulator, 0)
  end

  def clear_from_start_of_line_to_cursor(emulator, x, y) do
    Screen.clear_line(emulator, 1)
  end

  def clear_entire_line(emulator, y) do
    Screen.clear_line(emulator, 2)
  end

  # Helper functions to fetch state from GenServer-based managers
  @spec get_config_struct(t()) :: any()
  def get_config_struct(%__MODULE__{config: pid}) when is_pid(pid) do
    GenServer.call(pid, :get_state)
  end

  @spec get_window_manager_struct(t()) :: any()
  def get_window_manager_struct(%__MODULE__{window_manager: pid}) when is_pid(pid) do
    GenServer.call(pid, :get_state)
  end

  @spec get_cursor_struct(t()) :: any()
  def get_cursor_struct(%__MODULE__{cursor: pid}) when is_pid(pid) do
    GenServer.call(pid, :get_state)
  end

  def move_cursor(emulator, x, y) do
    buffer = emulator.main_screen_buffer || emulator.active_buffer
    width = if buffer, do: buffer.width || 80, else: emulator.width || 80
    height = if buffer, do: buffer.height || 24, else: emulator.height || 24
    clamped_x = max(0, min(x, width - 1))
    clamped_y = max(0, min(y, height - 1))
    do_move_cursor(emulator, clamped_x, clamped_y)
  end

  defp do_move_cursor(%{cursor: pid} = emulator, x, y) when is_pid(pid),
    do: set_cursor_position(emulator, x, y)
  defp do_move_cursor(%{cursor: %{} = cursor} = emulator, x, y),
    do: %{emulator | cursor: Map.put(cursor, :position, {x, y})}
  defp do_move_cursor(emulator, x, y),
    do: %{emulator | cursor: %{position: {x, y}}}

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
  def resize(%__MODULE__{} = emulator, width, height) when width > 0 and height > 0 do
    # Resize main screen buffer
    main_buffer = if emulator.main_screen_buffer do
      ScreenBuffer.resize(emulator.main_screen_buffer, width, height)
    else
      ScreenBuffer.new(width, height)
    end

    # Resize alternate screen buffer
    alternate_buffer = if emulator.alternate_screen_buffer do
      ScreenBuffer.resize(emulator.alternate_screen_buffer, width, height)
    else
      ScreenBuffer.new(width, height)
    end

    # Update emulator with new dimensions and buffers
    %{emulator |
      width: width,
      height: height,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer
    }
  end
end
