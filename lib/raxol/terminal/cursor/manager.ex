defmodule Raxol.Terminal.Cursor.Manager do
  @moduledoc """
  Manages cursor state and operations in the terminal.
  Handles cursor position, visibility, style, and blinking state.
  """

  use GenServer
  require Logger

  defstruct [
    x: 0,
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
  ]

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
    saved_color: color() | nil
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
  Gets the current cursor position.
  """
  def get_position(%__MODULE__{} = state) do
    {state.x, state.y}
  end

  @doc """
  Sets the cursor position.
  """
  def set_position(%__MODULE__{} = state, x, y)
      when is_integer(x) and x >= 0
      and is_integer(y) and y >= 0 do
    %{state | x: x, y: y}
  end

  @doc """
  Moves the cursor relative to its current position.
  """
  def move_cursor(%__MODULE__{} = state, dx, dy)
      when is_integer(dx) and is_integer(dy) do
    new_x = max(0, state.x + dx)
    new_y = max(0, state.y + dy)
    %{state | x: new_x, y: new_y}
  end

  @doc """
  Gets the cursor visibility state.
  """
  def is_visible?(%__MODULE__{} = state) do
    state.visible
  end

  @doc """
  Sets the cursor visibility.
  """
  def set_visibility(%__MODULE__{} = state, visible) when is_boolean(visible) do
    %{state | visible: visible}
  end

  @doc """
  Gets the cursor blinking state.
  """
  def is_blinking?(%__MODULE__{} = state) do
    state.blinking
  end

  @doc """
  Sets the cursor blinking state.
  """
  def set_blinking(%__MODULE__{} = state, blinking) when is_boolean(blinking) do
    %{state | blinking: blinking}
  end

  @doc """
  Gets the cursor style.
  """
  def get_style(%__MODULE__{} = state) do
    state.style
  end

  @doc """
  Sets the cursor style.
  """
  def set_style(%__MODULE__{} = state, style) when style in [:block, :underline, :bar] do
    %{state | style: style}
  end

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
    %{state |
      saved_x: state.x,
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
    %{state |
      x: state.saved_x || state.x,
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
    %{state |
      x: 0,
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

  # GenServer API functions
  def visible?(pid \\ __MODULE__) do
    GenServer.call(pid, :is_visible?)
  end

  def style(pid \\ __MODULE__) do
    GenServer.call(pid, :get_style)
  end

  def blinking?(pid \\ __MODULE__) do
    GenServer.call(pid, :is_blinking?)
  end

  def get_position(pid \\ __MODULE__) do
    GenServer.call(pid, :get_position)
  end

  def set_position(pid \\ __MODULE__, {row, col}) do
    GenServer.call(pid, {:set_position, row, col})
  end

  def set_visibility(pid \\ __MODULE__, visible) do
    GenServer.call(pid, {:set_visibility, visible})
  end

  def set_style(pid \\ __MODULE__, style) do
    GenServer.call(pid, {:set_style, style})
  end

  def set_blink(pid \\ __MODULE__, blinking) do
    GenServer.call(pid, {:set_blink, blinking})
  end

  def move_to(pid \\ __MODULE__, row, col)

  def move_to(pid, row, col) do
    GenServer.call(pid, {:move_to, row, col})
  end

  def move_to(pid \\ __MODULE__, row, col, min_row, max_row)

  def move_to(pid, row, col, min_row, max_row) do
    GenServer.call(pid, {:move_to, row, col, min_row, max_row})
  end

  def move_to(pid \\ __MODULE__, row, col, min_row, max_row, min_col, max_col)

  def move_to(pid, row, col, min_row, max_row, min_col, max_col) do
    GenServer.call(
      pid,
      {:move_to, row, col, min_row, max_row, min_col, max_col}
    )
  end

  def move_up(pid \\ __MODULE__, lines, min_row, max_row)

  def move_up(pid, lines, min_row, max_row) do
    GenServer.call(pid, {:move_up, lines, min_row, max_row})
  end

  def move_down(pid \\ __MODULE__, lines, min_row, max_row)

  def move_down(pid, lines, min_row, max_row) do
    GenServer.call(pid, {:move_down, lines, min_row, max_row})
  end

  def move_left(pid \\ __MODULE__, cols, min_col, max_col)

  def move_left(pid, cols, min_col, max_col) do
    GenServer.call(pid, {:move_left, cols, min_col, max_col})
  end

  def move_right(pid \\ __MODULE__, cols, min_col, max_col)

  def move_right(pid, cols, min_col, max_col) do
    GenServer.call(pid, {:move_right, cols, min_col, max_col})
  end

  def move_to_column(pid \\ __MODULE__, col, min_col, max_col)

  def move_to_column(pid, col, min_col, max_col) do
    GenServer.call(pid, {:move_to_column, col, min_col, max_col})
  end

  def move_to_line_start(pid \\ __MODULE__)

  def move_to_line_start(pid) do
    GenServer.call(pid, :move_to_line_start)
  end

  def constrain_position(pid \\ __MODULE__, min_bounds, max_bounds)

  def constrain_position(pid, min_bounds, max_bounds) do
    GenServer.call(pid, {:constrain_position, min_bounds, max_bounds})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok,
     %{
       x: 0,
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
     }}
  end

  @impl true
  def handle_call(:visible?, _from, state) do
    {:reply, state.visible, state}
  end

  @impl true
  def handle_call(:get_style, _from, state) do
    {:reply, state.style, state}
  end

  @impl true
  def handle_call(:blinking?, _from, state) do
    {:reply, state.blinking, state}
  end

  @impl true
  def handle_call(:get_position, _from, state) do
    {:reply, {state.x, state.y}, state}
  end

  @impl true
  def handle_call({:set_position, row, col}, _from, state) do
    {:reply, :ok, %{state | x: row, y: col}}
  end

  @impl true
  def handle_call({:set_visibility, visible}, _from, state) do
    {:reply, :ok, %{state | visible: visible}}
  end

  @impl true
  def handle_call({:set_style, style}, _from, state) do
    {:reply, :ok, %{state | style: style}}
  end

  @impl true
  def handle_call({:set_blink, blinking}, _from, state) do
    {:reply, :ok, %{state | blinking: blinking}}
  end

  @impl true
  def handle_call({:move_to, row, col}, _from, state) do
    {:reply, :ok, %{state | x: row, y: col}}
  end

  @impl true
  def handle_call({:move_to, row, col, min_row, max_row}, _from, state) do
    {_, current_col} = {state.x, state.y}
    new_row = max(min_row, min(max_row, row))
    {:reply, :ok, %{state | x: new_row, y: current_col}}
  end

  @impl true
  def handle_call(
        {:move_to, row, col, min_row, max_row, min_col, max_col},
        _from,
        state
      ) do
    new_row = max(min_row, min(max_row, row))
    new_col = max(min_col, min(max_col, col))
    {:reply, :ok, %{state | x: new_row, y: new_col}}
  end

  @impl true
  def handle_call({:move_up, lines, _min_row, _max_row}, _from, state) do
    {row, col} = {state.x, state.y}
    new_row = max(0, row - lines)
    {:reply, :ok, %{state | x: new_row, y: col}}
  end

  @impl true
  def handle_call({:move_down, lines, _min_row, _max_row}, _from, state) do
    {row, col} = {state.x, state.y}
    new_row = min(row + lines, 0)
    {:reply, :ok, %{state | x: new_row, y: col}}
  end

  @impl true
  def handle_call({:move_left, cols, _min_col, _max_col}, _from, state) do
    {row, col} = {state.x, state.y}
    new_col = max(0, col - cols)
    {:reply, :ok, %{state | x: row, y: new_col}}
  end

  @impl true
  def handle_call({:move_right, cols, _min_col, _max_col}, _from, state) do
    {row, col} = {state.x, state.y}
    new_col = min(col + cols, 0)
    {:reply, :ok, %{state | x: row, y: new_col}}
  end

  @impl true
  def handle_call({:move_to_column, col, _min_col, _max_col}, _from, state) do
    {row, _} = {state.x, state.y}
    {:reply, :ok, %{state | x: row, y: col}}
  end

  @impl true
  def handle_call(:move_to_line_start, _from, state) do
    {row, _} = {state.x, state.y}
    {:reply, :ok, %{state | x: row, y: 0}}
  end

  @impl true
  def handle_call(
        {:constrain_position, {min_row, min_col}, {max_row, max_col}},
        _from,
        state
      ) do
    {row, col} = {state.x, state.y}
    new_row = max(min_row, min(max_row, row))
    new_col = max(min_col, min(max_col, col))
    {:reply, :ok, %{state | x: new_row, y: new_col}}
  end

  @impl true
  def handle_call(request, _from, state) do
    Logger.warning("Unhandled call: #{inspect(request)}")
    {:reply, {:error, :unknown_call}, state}
  end
end
