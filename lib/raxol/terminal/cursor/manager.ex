defmodule Raxol.Terminal.Cursor.Manager do
  @moduledoc """
  Manages cursor state and operations in the terminal.
  Handles cursor position, visibility, style, and blinking state.
  """

  use GenServer
  @behaviour GenServer
  require Logger

  alias Raxol.Terminal.Emulator
  require Raxol.Core.Runtime.Log

  defstruct x: 0,
            y: 0,
            visible: true,
            blinking: true,
            style: :block,
            color: nil,
            saved_x: nil,
            saved_y: nil,
            saved_style: nil,
            saved_visible: nil,
            saved_blinking: nil,
            saved_color: nil,
            top_margin: 0,
            bottom_margin: 24,
            blink_timer: nil,
            state: :visible,
            position: {0, 0},
            blink: true,
            custom_shape: nil,
            custom_dimensions: nil,
            blink_rate: 530,
            saved_position: nil,
            history: [],
            history_index: 0,
            history_limit: 100,
            shape: {1, 1}

  @type cursor_style :: :block | :underline | :bar
  @type color :: {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil

  @type t :: %__MODULE__{
          x: non_neg_integer(),
          y: non_neg_integer(),
          visible: boolean(),
          blinking: boolean(),
          style: cursor_style(),
          color: color(),
          saved_x: non_neg_integer() | nil,
          saved_y: non_neg_integer() | nil,
          saved_style: cursor_style() | nil,
          saved_visible: boolean() | nil,
          saved_blinking: boolean() | nil,
          saved_color: color() | nil,
          top_margin: non_neg_integer(),
          bottom_margin: non_neg_integer(),
          blink_timer: non_neg_integer() | nil,
          state: atom(),
          position: {non_neg_integer(), non_neg_integer()},
          blink: boolean(),
          custom_shape: atom() | nil,
          custom_dimensions: {non_neg_integer(), non_neg_integer()} | nil,
          blink_rate: non_neg_integer(),
          saved_position: {non_neg_integer(), non_neg_integer()} | nil,
          history: list(),
          history_index: non_neg_integer(),
          history_limit: non_neg_integer(),
          shape: {non_neg_integer(), non_neg_integer()}
        }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a new cursor manager instance.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new cursor struct with the given options.
  """
  def new(opts) when is_map(opts) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Creates a new cursor manager with specified x and y coordinates.
  """
  def new(x, y) when is_integer(x) and is_integer(y) do
    %__MODULE__{
      x: x,
      y: y,
      position: {x, y}
    }
  end

  @doc """
  Gets the current cursor position.
  """
  def get_position(pid \\ __MODULE__) do
    GenServer.call(pid, :get_position)
  end

  @doc """
  Sets the cursor position.
  """
  def set_position(pid \\ __MODULE__, {row, col}) do
    GenServer.call(pid, {:set_position, row, col})
  end

  @doc """
  Moves the cursor relative to its current position.
  """
  def move_cursor(pid \\ __MODULE__, direction, count \\ 1) do
    GenServer.call(pid, {:move_cursor, direction, count})
  end

  @doc """
  Gets the cursor visibility state.
  """
  def get_visibility(pid \\ __MODULE__) do
    GenServer.call(pid, :get_visibility)
  end

  @doc """
  Sets the cursor visibility state.
  """
  def set_visibility(pid \\ __MODULE__, visible) do
    GenServer.call(pid, {:set_visibility, visible})
  end

  @doc """
  Moves the cursor to a specific position.
  """
  def move_to(cursor, {x, y}) do
    %{cursor | x: x, y: y, position: {x, y}}
  end

  @doc """
  Moves the cursor to a specific position.
  """
  def move_to(cursor, row, col) do
    %{cursor | x: row, y: col, position: {row, col}}
  end

  @doc """
  Moves the cursor to a specific position with bounds clamping.
  """
  def move_to(cursor, row, col, width, height) do
    clamped_row = max(0, min(row, height - 1))
    clamped_col = max(0, min(col, width - 1))

    %{
      cursor
      | x: clamped_row,
        y: clamped_col,
        position: {clamped_row, clamped_col}
    }
  end

  @doc """
  Moves the cursor up by the specified number of lines.
  """
  def move_up(cursor, lines, _width, _height) do
    new_y = max(cursor.top_margin, cursor.y - lines)
    %{cursor | y: new_y}
  end

  @doc """
  Moves the cursor down by the specified number of lines.
  """
  def move_down(cursor, lines, _width, _height) do
    new_y = min(cursor.bottom_margin, cursor.y + lines)
    %{cursor | y: new_y}
  end

  @doc """
  Moves the cursor left by the specified number of columns.
  """
  def move_left(cursor, cols, _width, _height) do
    new_x = max(0, cursor.x - cols)
    %{cursor | x: new_x}
  end

  @doc """
  Moves the cursor right by the specified number of columns.
  """
  def move_right(cursor, cols, _width, _height) do
    new_x = cursor.x + cols
    %{cursor | x: new_x}
  end

  @doc """
  Moves the cursor to the beginning of the line.
  """
  def move_to_line_start(cursor) do
    %{cursor | x: 0}
  end

  @doc """
  Moves the cursor to the end of the line.
  """
  def move_to_line_end(cursor, line_width) do
    %{cursor | x: line_width - 1}
  end

  @doc """
  Moves the cursor to the specified column.
  """
  def move_to_column(cursor, column) do
    %{cursor | x: column}
  end

  @doc """
  Moves the cursor to the specified line.
  """
  def move_to_line(cursor, line) do
    %{cursor | y: line}
  end

  @doc """
  Moves the cursor to the home position (0, 0).
  """
  def move_home(cursor, _width, _height) do
    %{cursor | x: 0, y: 0}
  end

  @doc """
  Moves the cursor to the next tab stop.
  """
  def move_to_next_tab(cursor, tab_size, width, _height) do
    next_tab = div(cursor.x + tab_size, tab_size) * tab_size
    new_x = min(next_tab, width - 1)
    %{cursor | x: new_x}
  end

  @doc """
  Moves the cursor to the previous tab stop.
  """
  def move_to_prev_tab(cursor, tab_size, _width, _height) do
    prev_tab = div(cursor.x - 1, tab_size) * tab_size
    new_x = max(prev_tab, 0)
    %{cursor | x: new_x}
  end

  @doc """
  Sets the cursor margins.
  """
  def set_margins(cursor, top, bottom) do
    %{cursor | top_margin: top, bottom_margin: bottom}
  end

  @doc """
  Gets the cursor margins.
  """
  def get_margins(cursor) do
    {cursor.top_margin, cursor.bottom_margin}
  end

  @doc """
  Gets the cursor blinking state.
  """
  def get_blink(pid \\ __MODULE__) do
    GenServer.call(pid, :get_blink)
  end

  @doc """
  Sets the cursor blinking state.
  """
  def set_blink(pid \\ __MODULE__, blink) do
    GenServer.call(pid, {:set_blink, blink})
  end

  @doc """
  Gets the cursor style.
  """
  def get_style(pid \\ __MODULE__) do
    GenServer.call(pid, :get_style)
  end

  @doc """
  Sets the cursor style.
  """
  def set_style(%__MODULE__{} = state, style), do: %{state | style: style}
  def set_style(pid, style), do: GenServer.call(pid, {:set_style, style})
  def set_style(style), do: set_style(__MODULE__, style)

  @doc """
  Gets the cursor color.
  """
  def get_color(%__MODULE__{} = state) do
    state.color
  end

  @doc """
  Sets the cursor color.
  """
  def set_color(%__MODULE__{} = state, color) do
    %{state | color: color}
  end

  @doc """
  Resets the cursor color to default.
  """
  def reset_color(%__MODULE__{} = state) do
    %{state | color: nil}
  end

  @doc """
  Saves the current cursor state.
  """
  def save_state(%__MODULE__{} = state) do
    %{
      state
      | saved_x: state.x,
        saved_y: state.y,
        saved_style: state.style,
        saved_visible: state.visible,
        saved_blinking: state.blinking,
        saved_color: state.color
    }
  end

  @doc """
  Restores the saved cursor state.
  """
  def restore_state(%__MODULE__{} = state) do
    %{
      state
      | x: state.saved_x || state.x,
        y: state.saved_y || state.y,
        style: state.saved_style || state.style,
        visible: state.saved_visible || state.visible,
        blinking: state.saved_blinking || state.blinking,
        color: state.saved_color || state.color
    }
  end

  @doc """
  Resets the cursor state to default values.
  """
  def reset(%__MODULE__{} = state) do
    %{
      state
      | x: 0,
        y: 0,
        visible: true,
        blinking: true,
        style: :block,
        color: nil,
        saved_x: nil,
        saved_y: nil,
        saved_style: nil,
        saved_visible: nil,
        saved_blinking: nil,
        saved_color: nil
    }
  end

  @doc """
  Sets the cursor state based on a state atom.
  Supported states: :visible, :hidden, :blinking
  """
  def set_state(%__MODULE__{} = state, :visible) do
    %{state | visible: true, state: :visible}
  end

  def set_state(%__MODULE__{} = state, :hidden) do
    %{state | visible: false, state: :hidden}
  end

  def set_state(%__MODULE__{} = state, :blinking) do
    %{state | blinking: true, blink: true, state: :blinking}
  end

  @doc """
  Sets a custom cursor shape.
  """
  def set_custom_shape(%__MODULE__{} = state, shape, params),
    do: %{
      state
      | style: :custom,
        custom_shape: shape,
        custom_dimensions: params,
        shape: params
    }

  def set_custom_shape(pid, shape, params),
    do: GenServer.call(pid, {:set_custom_shape, shape, params})

  def set_custom_shape(shape, params),
    do: set_custom_shape(__MODULE__, shape, params)

  def update_position(pid \\ __MODULE__, {row, col}) do
    GenServer.call(pid, {:update_position, row, col})
  end

  def reset_position(pid \\ __MODULE__) do
    GenServer.call(pid, :reset_position)
  end

  @doc """
  Updates the cursor blink state.
  """
  def update_blink(%__MODULE__{} = state) do
    new_blink_state = !state.blink
    new_state = %{state | blink: new_blink_state}
    {new_state, new_state.visible}
  end

  def update_blink(pid), do: GenServer.call(pid, :update_blink)
  def update_blink(), do: update_blink(__MODULE__)

  # Struct-based version for tests (should match before GenServer version)
  def update_blink(%__MODULE__{} = state) do
    new_blink_state = !state.blink
    new_state = %{state | blink: new_blink_state}
    {new_state, new_state.visible}
  end

  @doc """
  Updates the cursor position after a resize operation.
  Returns the updated emulator.
  """
  @spec update_cursor_position(
          Emulator.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Emulator.t()
  def update_cursor_position(emulator, new_width, new_height) do
    cursor = emulator.cursor
    x = min(cursor.x, new_width - 1)
    y = min(cursor.y, new_height - 1)
    %{emulator | cursor: %{cursor | x: x, y: y}}
  end

  @doc """
  Updates the scroll region after a resize operation.
  Returns the updated emulator.
  """
  @spec update_scroll_region_for_resize(Emulator.t(), non_neg_integer()) ::
          Emulator.t()
  def update_scroll_region_for_resize(emulator, new_height) do
    scroll_region = emulator.scroll_region
    top = min(scroll_region.top, new_height - 1)
    bottom = min(scroll_region.bottom, new_height - 1)
    %{emulator | scroll_region: %{scroll_region | top: top, bottom: bottom}}
  end

  @doc """
  Moves the cursor up by the specified number of lines.
  Returns the updated emulator.
  """
  @spec move_up(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_up(emulator, count \\ 1) do
    cursor = emulator.cursor
    y = max(0, cursor.y - count)
    %{emulator | cursor: %{cursor | y: y}}
  end

  @doc """
  Moves the cursor down by the specified number of lines.
  Returns the updated emulator.
  """
  @spec move_down(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_down(emulator, count \\ 1) do
    cursor = emulator.cursor
    y = min(emulator.height - 1, cursor.y + count)
    %{emulator | cursor: %{cursor | y: y}}
  end

  @doc """
  Moves the cursor left by the specified number of columns.
  Returns the updated emulator.
  """
  @spec move_left(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_left(emulator, count \\ 1) do
    cursor = emulator.cursor
    x = max(0, cursor.x - count)
    %{emulator | cursor: %{cursor | x: x}}
  end

  @doc """
  Moves the cursor right by the specified number of columns.
  Returns the updated emulator.
  """
  @spec move_right(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_right(emulator, count \\ 1) do
    cursor = emulator.cursor
    x = min(emulator.width - 1, cursor.x + count)
    %{emulator | cursor: %{cursor | x: x}}
  end

  @spec get_emulator_position(Emulator.t()) ::
          {non_neg_integer(), non_neg_integer()}
  def get_emulator_position(emulator) do
    {emulator.cursor.x, emulator.cursor.y}
  end

  @spec set_emulator_position(
          Emulator.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Emulator.t()
  def set_emulator_position(emulator, x, y) do
    x = max(0, min(x, emulator.width - 1))
    y = max(0, min(y, emulator.height - 1))
    %{emulator | cursor: %{emulator.cursor | x: x, y: y}}
  end

  @spec get_emulator_style(Emulator.t()) :: atom()
  def get_emulator_style(emulator) do
    emulator.cursor.style
  end

  @spec set_emulator_style(Emulator.t(), atom()) :: Emulator.t()
  def set_emulator_style(emulator, style) do
    %{emulator | cursor: %{emulator.cursor | style: style}}
  end

  @spec emulator_visible?(Emulator.t()) :: boolean()
  def emulator_visible?(emulator) do
    emulator.cursor.visible
  end

  @spec set_emulator_visibility(Emulator.t(), boolean()) :: Emulator.t()
  def set_emulator_visibility(emulator, visible) do
    %{emulator | cursor: %{emulator.cursor | visible: visible}}
  end

  @spec emulator_blinking?(Emulator.t()) :: boolean()
  def emulator_blinking?(emulator) do
    emulator.cursor.blinking
  end

  @spec set_emulator_blink(Emulator.t(), boolean()) :: Emulator.t()
  def set_emulator_blink(emulator, blinking) do
    %{emulator | cursor: %{emulator.cursor | blinking: blinking}}
  end

  @doc """
  Saves the current cursor position.
  """
  def save_position(%__MODULE__{} = state) do
    %{
      state
      | saved_x: state.x,
        saved_y: state.y,
        saved_position: state.position
    }
  end

  @doc """
  Restores the saved cursor position.
  """
  def restore_position(%__MODULE__{} = state) do
    if state.saved_x && state.saved_y do
      %{
        state
        | x: state.saved_x,
          y: state.saved_y,
          position: {state.saved_x, state.saved_y}
      }
    else
      state
    end
  end

  @doc """
  Adds the current cursor state to history.
  """
  def add_to_history(%__MODULE__{} = state) do
    history_entry = %{
      x: state.x,
      y: state.y,
      style: state.style,
      visible: state.visible,
      blinking: state.blinking,
      state: state.state,
      position: state.position
    }

    %{state | history: [history_entry | state.history]}
  end

  @doc """
  Restores cursor state from history.
  """
  def restore_from_history(%__MODULE__{} = state) do
    case state.history do
      [entry | rest] ->
        %{
          state
          | x: entry.x,
            y: entry.y,
            style: entry.style,
            visible: entry.visible,
            blinking: entry.blinking,
            state: entry.state,
            position: entry.position,
            history: rest
        }

      [] ->
        state
    end
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, new()}
  end

  @impl true
  def handle_call(:get_position, _from, state) do
    {:reply, {state.x, state.y}, state}
  end

  @impl true
  def handle_call({:set_position, row, col}, _from, state) do
    new_state = %{state | x: row, y: col}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:move_cursor, direction, count}, _from, state) do
    new_state =
      case direction do
        :up -> move_up(state, count, 80, 24)
        :down -> move_down(state, count, 80, 24)
        :left -> move_left(state, count, 80, 24)
        :right -> move_right(state, count, 80, 24)
      end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_visibility, _from, state) do
    {:reply, state.visible, state}
  end

  @impl true
  def handle_call({:set_visibility, visible}, _from, state) do
    new_state = %{state | visible: visible}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_style, _from, state) do
    {:reply, state.style, state}
  end

  @impl true
  def handle_call({:set_style, style}, _from, state) do
    {:reply, :ok, %{state | style: style}}
  end

  @impl true
  def handle_call(:get_blink, _from, state) do
    {:reply, state.blinking, state}
  end

  @impl true
  def handle_call({:set_blink, blink}, _from, state) do
    new_state = %{state | blinking: blink}

    if blink do
      schedule_blink()
    else
      cancel_blink(state.blink_timer)
    end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_custom_shape, shape, params}, _from, state) do
    {:reply, :ok,
     %{
       state
       | style: :custom,
         custom_shape: shape,
         custom_dimensions: params,
         shape: params
     }}
  end

  @impl true
  def handle_call({:update_position, row, col}, _from, state) do
    {:reply, :ok, %{state | x: row, y: col}}
  end

  @impl true
  def handle_call(:reset_position, _from, state) do
    {:reply, :ok, %{state | x: 0, y: 0}}
  end

  @impl true
  def handle_call(:update_blink, _from, state) do
    new_blink_state = !state.blink
    new_state = %{state | blink: new_blink_state}
    {:reply, new_blink_state, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(request, _from, state) do
    Logger.warning("Unknown request: #{inspect(request)}")
    {:reply, {:error, :unknown_request}, state}
  end

  @impl true
  def handle_info({:blink, _timer_id}, state) do
    if state.blinking do
      new_blink_state = !state.blink
      new_state = %{state | blink: new_blink_state}
      schedule_blink()
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  # --- Private Functions ---

  defp schedule_blink do
    timer_id = System.unique_integer([:positive])
    Process.send_after(self(), {:blink, timer_id}, 500)
  end

  defp cancel_blink(nil), do: :ok
  defp cancel_blink(timer_id), do: Process.cancel_timer(timer_id)

  @doc """
  Gets the cursor position as a tuple {x, y}.
  """
  def get_position_tuple(cursor) do
    {cursor.x, cursor.y}
  end

  @doc """
  Gets the current cursor position as a tuple.
  """
  def get_position(%__MODULE__{} = cursor) do
    cursor.position
  end
end
