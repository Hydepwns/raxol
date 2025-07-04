defmodule Raxol.Terminal.Cursor.Manager do
  @moduledoc """
  Manages cursor state and operations in the terminal.
  Handles cursor position, visibility, style, and blinking state.
  """

  use GenServer
  require Logger

  alias Raxol.Terminal.Emulator
  require Raxol.Core.Runtime.Log

  defstruct row: 0,
            col: 0,
            visible: true,
            blinking: true,
            style: :block,
            color: nil,
            saved_row: nil,
            saved_col: nil,
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
          row: non_neg_integer(),
          col: non_neg_integer(),
          visible: boolean(),
          blinking: boolean(),
          style: cursor_style(),
          color: color(),
          saved_row: non_neg_integer() | nil,
          saved_col: non_neg_integer() | nil,
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
    name = Keyword.get(opts, :name)
    gen_server_opts = Keyword.delete(opts, :name)

    if name do
      GenServer.start_link(__MODULE__, gen_server_opts, name: name)
    else
      GenServer.start_link(__MODULE__, gen_server_opts)
    end
  end

  @doc """
  Creates a new cursor manager instance.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new cursor manager.
  """
  def new(opts) when is_map(opts) do
    struct!(__MODULE__, opts)
  end

  def new(opts) when is_list(opts) do
    struct!(__MODULE__, Map.new(opts))
  end

  def new(row, col) when is_integer(row) and is_integer(col) do
    %__MODULE__{
      row: row,
      col: col,
      position: {row, col}
    }
  end

  @doc """
  Gets the current cursor position.
  """
  def get_position(pid \\ __MODULE__)

  def get_position(pid) when is_pid(pid) do
    GenServer.call(pid, :get_position)
  end

  def get_position(%__MODULE__{} = cursor) do
    {cursor.row, cursor.col}
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
  def move_to(cursor, {row, col}) do
    %{cursor | row: row, col: col, position: {row, col}}
  end

  @doc """
  Moves the cursor to a specific position.
  """
  def move_to(cursor, row, col) do
    %{cursor | row: row, col: col, position: {row, col}}
  end

  @doc """
  Moves the cursor to a specific position with bounds clamping.
  """
  def move_to(cursor, row, col, width, height) do
    clamped_row = max(0, min(row, height - 1))
    clamped_col = max(0, min(col, width - 1))

    %{
      cursor
      | row: clamped_row,
        col: clamped_col,
        position: {clamped_row, clamped_col}
    }
  end

  @doc """
  Moves the cursor up by the specified number of lines.
  """
  def move_up(cursor, lines, _width, _height) do
    new_row = max(cursor.top_margin, cursor.row - lines)
    %{cursor | row: new_row, position: {new_row, cursor.col}}
  end

  @doc """
  Moves the cursor down by the specified number of lines.
  """
  def move_down(cursor, lines, _width, _height) do
    new_row = min(cursor.bottom_margin, cursor.row + lines)
    %{cursor | row: new_row, position: {new_row, cursor.col}}
  end

  @doc """
  Moves the cursor left by the specified number of columns.
  """
  def move_left(cursor, cols, _width, _height) do
    new_col = max(0, cursor.col - cols)
    %{cursor | col: new_col, position: {cursor.row, new_col}}
  end

  @doc """
  Moves the cursor right by the specified number of columns.
  """
  def move_right(cursor, cols, _width, _height) do
    new_col = cursor.col + cols
    %{cursor | col: new_col, position: {cursor.row, new_col}}
  end

  @doc """
  Moves the cursor to the beginning of the line.
  """
  def move_to_line_start(cursor) do
    %{cursor | col: 0, position: {cursor.row, 0}}
  end

  @doc """
  Moves the cursor to the end of the line.
  """
  def move_to_line_end(cursor, line_width) do
    %{cursor | col: line_width - 1, position: {cursor.row, line_width - 1}}
  end

  @doc """
  Moves the cursor to the specified column.
  """
  def move_to_column(cursor, column) do
    %{cursor | col: column, position: {cursor.row, column}}
  end

  @doc """
  Moves the cursor to the specified column with bounds clamping.
  """
  @spec move_to_column(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: t()
  def move_to_column(cursor, column, width, _height) do
    clamped_col = max(0, min(column, width - 1))
    %{cursor | col: clamped_col, position: {cursor.row, clamped_col}}
  end

  @doc """
  Constrains the cursor position to within the specified bounds.
  """
  @spec constrain_position(t(), non_neg_integer(), non_neg_integer()) :: t()
  def constrain_position(cursor, width, height) do
    clamped_row = max(0, min(cursor.row, height - 1))
    clamped_col = max(0, min(cursor.col, width - 1))

    %{
      cursor
      | row: clamped_row,
        col: clamped_col,
        position: {clamped_row, clamped_col}
    }
  end

  @doc """
  Moves the cursor to the specified line.
  """
  def move_to_line(cursor, line) do
    %{cursor | row: line, position: {line, cursor.col}}
  end

  @doc """
  Moves the cursor to the home position (0, 0).
  """
  def move_home(cursor, _width, _height) do
    %{cursor | col: 0, row: 0, position: {0, 0}}
  end

  @doc """
  Moves the cursor to the next tab stop.
  """
  def move_to_next_tab(cursor, tab_size, width, _height) do
    next_tab = div(cursor.col + tab_size, tab_size) * tab_size
    new_col = min(next_tab, width - 1)
    %{cursor | col: new_col, position: {cursor.row, new_col}}
  end

  @doc """
  Moves the cursor to the previous tab stop.
  """
  def move_to_prev_tab(cursor, tab_size, _width, _height) do
    prev_tab = div(cursor.col - 1, tab_size) * tab_size
    new_col = max(prev_tab, 0)
    %{cursor | col: new_col, position: {cursor.row, new_col}}
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
      | saved_row: state.row,
        saved_col: state.col,
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
      | row: state.saved_row || state.row,
        col: state.saved_col || state.col,
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
      | row: 0,
        col: 0,
        visible: true,
        blinking: true,
        style: :block,
        color: nil,
        saved_row: nil,
        saved_col: nil,
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
  def update_blink(%__MODULE__{state: :visible} = state), do: {state, true}
  def update_blink(%__MODULE__{state: :hidden} = state), do: {state, false}

  def update_blink(%__MODULE__{state: :blinking, blink: blink} = state) do
    new_blink = !blink
    {%{state | blink: new_blink}, new_blink}
  end

  def update_blink(pid), do: GenServer.call(pid, :update_blink)
  def update_blink(), do: update_blink(__MODULE__)

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
    col = min(cursor.col, new_width - 1)
    row = min(cursor.row, new_height - 1)
    %{emulator | cursor: %{cursor | col: col, row: row}}
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
    row = max(0, cursor.row - count)
    %{emulator | cursor: %{cursor | row: row}}
  end

  @doc """
  Moves the cursor down by the specified number of lines.
  Returns the updated emulator.
  """
  @spec move_down(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_down(emulator, count \\ 1) do
    cursor = emulator.cursor
    row = min(emulator.height - 1, cursor.row + count)
    %{emulator | cursor: %{cursor | row: row}}
  end

  @doc """
  Moves the cursor left by the specified number of columns.
  Returns the updated emulator.
  """
  @spec move_left(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_left(emulator, count \\ 1) do
    cursor = emulator.cursor
    col = max(0, cursor.col - count)
    %{emulator | cursor: %{cursor | col: col}}
  end

  @doc """
  Moves the cursor right by the specified number of columns.
  Returns the updated emulator.
  """
  @spec move_right(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_right(emulator, count \\ 1) do
    cursor = emulator.cursor
    col = min(emulator.width - 1, cursor.col + count)
    %{emulator | cursor: %{cursor | col: col}}
  end

  @spec get_emulator_position(Emulator.t()) :: {integer(), integer()}
  def get_emulator_position(emulator) do
    emulator.cursor.position
  end

  @spec set_emulator_position(
          Emulator.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Emulator.t()
  def set_emulator_position(emulator, x, y) do
    x = max(0, min(x, emulator.width - 1))
    y = max(0, min(y, emulator.height - 1))
    %{emulator | cursor: %{emulator.cursor | position: {x, y}}}
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
    emulator.cursor.blink_state
  end

  @spec set_emulator_blink(Emulator.t(), boolean()) :: Emulator.t()
  def set_emulator_blink(emulator, blinking) do
    %{emulator | cursor: %{emulator.cursor | blink_state: blinking}}
  end

  @doc """
  Saves the current cursor position.
  """
  def save_position(%__MODULE__{} = state) do
    %{
      state
      | saved_row: state.row,
        saved_col: state.col,
        saved_position: {state.row, state.col}
    }
  end

  @doc """
  Restores the saved cursor position.
  """
  def restore_position(%__MODULE__{} = state) do
    if state.saved_row && state.saved_col do
      %{
        state
        | row: state.saved_row,
          col: state.saved_col,
          position: {state.saved_row, state.saved_col}
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
      row: state.row,
      col: state.col,
      style: state.style,
      visible: state.visible,
      blinking: state.blinking,
      state: state.state,
      position: {state.row, state.col}
    }

    %{
      state
      | history: [history_entry | state.history],
        history_index: state.history_index + 1
    }
  end

  @doc """
  Restores cursor state from history.
  """
  def restore_from_history(%__MODULE__{} = state) do
    case state.history do
      [entry | rest] ->
        %{
          state
          | row: entry.row,
            col: entry.col,
            style: entry.style,
            visible: entry.visible,
            blinking: entry.blinking,
            state: entry.state,
            position: {entry.row, entry.col},
            history: rest
        }

      [] ->
        state
    end
  end

  # Server Callbacks

  @impl GenServer
  def init(_opts) do
    {:ok, new()}
  end

  @impl GenServer
  def handle_call(:get_position, _from, state) do
    Raxol.Core.Runtime.Log.debug(
      "Getting cursor position: {#{state.row}, #{state.col}}"
    )

    {:reply, {state.row, state.col}, state}
  end

  @impl GenServer
  def handle_call({:set_position, row, col}, _from, state) do
    Raxol.Core.Runtime.Log.debug(
      "Setting cursor position from {#{state.row}, #{state.col}} to {#{row}, #{col}}"
    )

    new_state = %{state | row: row, col: col, position: {row, col}}
    {:reply, :ok, new_state}
  end

  @impl GenServer
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

  @impl GenServer
  def handle_call(:get_visibility, _from, state) do
    {:reply, state.visible, state}
  end

  @impl GenServer
  def handle_call({:set_visibility, visible}, _from, state) do
    new_state = %{
      state
      | visible: visible,
        state: if(visible, do: :visible, else: :hidden)
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_style, _from, state) do
    {:reply, state.style, state}
  end

  @impl GenServer
  def handle_call({:set_style, style}, _from, state) do
    {:reply, :ok, %{state | style: style}}
  end

  @impl GenServer
  def handle_call(:get_blink, _from, state) do
    {:reply, state.blinking, state}
  end

  @impl GenServer
  def handle_call({:set_blink, blink}, _from, state) do
    new_state = %{state | blinking: blink}

    if blink do
      schedule_blink()
    else
      cancel_blink(state.blink_timer)
    end

    {:reply, :ok, new_state}
  end

  @impl GenServer
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

  @impl GenServer
  def handle_call({:update_position, row, col}, _from, state) do
    {:reply, :ok, %{state | row: row, col: col, position: {row, col}}}
  end

  @impl GenServer
  def handle_call(:reset_position, _from, state) do
    {:reply, :ok, %{state | row: 0, col: 0}}
  end

  @impl GenServer
  def handle_call(:update_blink, _from, state) do
    new_blink_state = !state.blink
    new_state = %{state | blink: new_blink_state}
    {:reply, new_blink_state, new_state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_call(request, _from, state) do
    Logger.warning("Unknown request: #{inspect(request)}")
    {:reply, {:error, :unknown_request}, state}
  end

  @impl GenServer
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
  Gets the cursor position as a tuple {row, col}.
  """
  def get_position_tuple(cursor) do
    {cursor.row, cursor.col}
  end
end
