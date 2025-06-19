defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  The main terminal emulator module that coordinates all terminal operations.
  This module delegates to specialized manager modules for different aspects of terminal functionality.
  """

  alias Raxol.Terminal.{
    State.Manager,
    Event.Handler,
    Buffer.Manager,
    Config.Manager,
    Command.Manager,
    Operations.CursorOperations,
    Operations.ScreenOperations,
    Operations.TextOperations,
    Operations.SelectionOperations,
    Operations.ScrollOperations,
    Operations.StateOperations
  }

  @behaviour Raxol.Terminal.OperationsBehaviour

  defstruct [
    state: State.Manager.new(),
    event: Event.Handler.new(),
    buffer: Buffer.Manager.new(),
    config: Config.Manager.new(),
    command: Command.Manager.new()
  ]

  @type t :: %__MODULE__{
    state: State.t(),
    event: Event.t(),
    buffer: Buffer.t(),
    config: Config.t(),
    command: Command.t()
  }

  # Cursor Operations
  defdelegate get_cursor_position(emulator), to: CursorOperations
  defdelegate set_cursor_position(emulator, x, y), to: CursorOperations
  defdelegate get_cursor_style(emulator), to: CursorOperations
  defdelegate set_cursor_style(emulator, style), to: CursorOperations
  defdelegate is_cursor_visible?(emulator), to: CursorOperations
  defdelegate set_cursor_visibility(emulator, visible), to: CursorOperations
  defdelegate is_cursor_blinking?(emulator), to: CursorOperations
  defdelegate set_cursor_blink(emulator, blinking), to: CursorOperations

  # Screen Operations
  defdelegate clear_screen(emulator), to: ScreenOperations
  defdelegate clear_line(emulator), to: ScreenOperations
  defdelegate erase_display(emulator), to: ScreenOperations
  defdelegate erase_in_display(emulator), to: ScreenOperations
  defdelegate erase_line(emulator), to: ScreenOperations
  defdelegate erase_in_line(emulator), to: ScreenOperations
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
  defdelegate set_scroll_region(emulator, top, bottom), to: ScrollOperations
  defdelegate clear_scroll_region(emulator), to: ScrollOperations
  defdelegate scroll_up(emulator, count), to: ScrollOperations
  defdelegate scroll_down(emulator, count), to: ScrollOperations
  defdelegate get_scrollback_size(emulator), to: ScrollOperations
  defdelegate set_scrollback_size(emulator, size), to: ScrollOperations
  defdelegate clear_scrollback(emulator), to: ScrollOperations

  # State Operations
  defdelegate get_mode(emulator, mode), to: StateOperations
  defdelegate set_mode(emulator, mode, value), to: StateOperations
  defdelegate get_attribute(emulator, attribute), to: StateOperations
  defdelegate set_attribute(emulator, attribute, value), to: StateOperations
  defdelegate push_state(emulator), to: StateOperations
  defdelegate pop_state(emulator), to: StateOperations
  defdelegate get_state_stack(emulator), to: StateOperations
  defdelegate clear_state_stack(emulator), to: StateOperations
  defdelegate reset_state(emulator), to: StateOperations

  @doc """
  Creates a new terminal emulator instance.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      state: State.Manager.new(),
      event: Event.Handler.new(),
      buffer: Buffer.Manager.new(),
      config: Config.Manager.new(),
      command: Command.Manager.new()
    }
  end

  @doc """
  Processes input data and updates the terminal state accordingly.
  """
  @spec process_input(t(), binary()) :: t()
  def process_input(emulator, input) do
    Command.Manager.process_input(emulator, input)
  end

  @doc """
  Resets the terminal emulator to its initial state.
  """
  @spec reset(t()) :: t()
  def reset(emulator) do
    emulator
    |> State.Manager.reset_state()
    |> Event.Handler.reset_event_handler()
    |> Buffer.Manager.reset_buffer_manager()
    |> Config.Manager.reset_config_manager()
    |> Command.Manager.reset_command_manager()
  end
end
