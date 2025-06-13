defmodule Raxol.Terminal.Cursor.Manager do
  @moduledoc """
  Manages cursor state and operations in the terminal.
  Handles cursor position, visibility, style, and blinking state.
  """

  use GenServer
  require Logger

  # Struct definition for cursor state
  defstruct position: {0, 0},
            visible: true,
            style: :block,
            blinking: true,
            state: :visible,
            blink_rate: 500,
            custom_shape: nil,
            custom_dimensions: nil

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a new cursor struct with default values.
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
  def get_position(%__MODULE__{} = cursor) do
    cursor.position
  end

  @doc """
  Updates the cursor position.
  """
  def update_position(%__MODULE__{} = cursor, {row, col}) do
    %{cursor | position: {row, col}}
  end

  @doc """
  Resets the cursor position to the origin (0, 0).
  """
  def reset_position(%__MODULE__{} = cursor) do
    %{cursor | position: {0, 0}}
  end

  @doc """
  Moves the cursor to a specific position.
  """
  def move_to(%__MODULE__{} = cursor, row, col) do
    %{cursor | position: {row, col}}
  end

  @doc """
  Moves the cursor to a specific position with bounds checking.
  """
  def move_to(%__MODULE__{} = cursor, row, col, min_row, max_row) do
    new_row = max(min_row, min(max_row, row))
    %{cursor | position: {new_row, col}}
  end

  @doc """
  Moves the cursor to a specific position with bounds checking for both row and column.
  """
  def move_to(%__MODULE__{} = cursor, row, col, min_row, max_row, min_col, max_col) do
    new_row = max(min_row, min(max_row, row))
    new_col = max(min_col, min(max_col, col))
    %{cursor | position: {new_row, new_col}}
  end

  @doc """
  Moves the cursor up by the specified number of lines.
  """
  def move_up(%__MODULE__{} = cursor, lines, min_row, max_row) do
    {row, col} = cursor.position
    new_row = max(min_row, row - lines)
    %{cursor | position: {new_row, col}}
  end

  @doc """
  Moves the cursor down by the specified number of lines.
  """
  def move_down(%__MODULE__{} = cursor, lines, min_row, max_row) do
    {row, col} = cursor.position
    new_row = min(max_row, row + lines)
    %{cursor | position: {new_row, col}}
  end

  @doc """
  Moves the cursor left by the specified number of columns.
  """
  def move_left(%__MODULE__{} = cursor, cols, min_col, max_col) do
    {row, col} = cursor.position
    new_col = max(min_col, col - cols)
    %{cursor | position: {row, new_col}}
  end

  @doc """
  Moves the cursor right by the specified number of columns.
  """
  def move_right(%__MODULE__{} = cursor, cols, min_col, max_col) do
    {row, col} = cursor.position
    new_col = min(max_col, col + cols)
    %{cursor | position: {row, new_col}}
  end

  @doc """
  Moves the cursor to the start of the current line.
  """
  def move_to_line_start(%__MODULE__{} = cursor) do
    {row, _} = cursor.position
    %{cursor | position: {row, 0}}
  end

  @doc """
  Moves the cursor to a specific column.
  """
  def move_to_column(%__MODULE__{} = cursor, col, min_col, max_col) do
    {row, _} = cursor.position
    new_col = max(min_col, min(max_col, col))
    %{cursor | position: {row, new_col}}
  end

  @doc """
  Constrains the cursor position within the given bounds.
  """
  def constrain_position(%__MODULE__{} = cursor, {min_row, min_col}, {max_row, max_col}) do
    {row, col} = cursor.position
    new_row = max(min_row, min(max_row, row))
    new_col = max(min_col, min(max_col, col))
    %{cursor | position: {new_row, new_col}}
  end

  @doc """
  Sets the cursor style.
  """
  def set_style(%__MODULE__{} = cursor, style) do
    %{cursor | style: style}
  end

  @doc """
  Sets the cursor state (visible, hidden, or blinking).
  """
  def set_state(%__MODULE__{} = cursor, state) do
    %{cursor | state: state}
  end

  @doc """
  Sets a custom cursor shape and dimensions.
  """
  def set_custom_shape(%__MODULE__{} = cursor, shape, dimensions) do
    %{cursor | style: :custom, custom_shape: shape, custom_dimensions: dimensions}
  end

  @doc """
  Updates the cursor blink state and returns the updated cursor and visibility.
  """
  def update_blink(%__MODULE__{} = cursor) do
    case cursor.state do
      :blinking ->
        visible = !cursor.visible
        {%{cursor | visible: visible}, visible}
      _ ->
        {cursor, cursor.visible}
    end
  end

  # GenServer API functions
  def is_visible?(pid \\ __MODULE__) do
    GenServer.call(pid, :is_visible?)
  end

  def get_style(pid \\ __MODULE__) do
    GenServer.call(pid, :get_style)
  end

  def is_blinking?(pid \\ __MODULE__) do
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

  def move_to(pid \\ __MODULE__, row, col) do
    GenServer.call(pid, {:move_to, row, col})
  end

  def move_to(pid \\ __MODULE__, row, col, min_row, max_row) do
    GenServer.call(pid, {:move_to, row, col, min_row, max_row})
  end

  def move_to(pid \\ __MODULE__, row, col, min_row, max_row, min_col, max_col) do
    GenServer.call(pid, {:move_to, row, col, min_row, max_row, min_col, max_col})
  end

  def move_up(pid \\ __MODULE__, lines, min_row, max_row) do
    GenServer.call(pid, {:move_up, lines, min_row, max_row})
  end

  def move_down(pid \\ __MODULE__, lines, min_row, max_row) do
    GenServer.call(pid, {:move_down, lines, min_row, max_row})
  end

  def move_left(pid \\ __MODULE__, cols, min_col, max_col) do
    GenServer.call(pid, {:move_left, cols, min_col, max_col})
  end

  def move_right(pid \\ __MODULE__, cols, min_col, max_col) do
    GenServer.call(pid, {:move_right, cols, min_col, max_col})
  end

  def move_to_column(pid \\ __MODULE__, col, min_col, max_col) do
    GenServer.call(pid, {:move_to_column, col, min_col, max_col})
  end

  def move_to_line_start(pid \\ __MODULE__) do
    GenServer.call(pid, :move_to_line_start)
  end

  def constrain_position(pid \\ __MODULE__, min_bounds, max_bounds) do
    GenServer.call(pid, {:constrain_position, min_bounds, max_bounds})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{
      position: {0, 0},
      visible: true,
      style: :block,
      blinking: true,
      state: :visible,
      blink_rate: 500,
      custom_shape: nil,
      custom_dimensions: nil
    }}
  end

  @impl true
  def handle_call(:is_visible?, _from, state) do
    {:reply, state.visible, state}
  end

  @impl true
  def handle_call(:get_style, _from, state) do
    {:reply, state.style, state}
  end

  @impl true
  def handle_call(:is_blinking?, _from, state) do
    {:reply, state.blinking, state}
  end

  @impl true
  def handle_call(:get_position, _from, state) do
    {:reply, state.position, state}
  end

  @impl true
  def handle_call({:set_position, row, col}, _from, state) do
    {:reply, :ok, %{state | position: {row, col}}}
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
    {:reply, :ok, %{state | position: {row, col}}}
  end

  @impl true
  def handle_call({:move_to, row, col, min_row, max_row}, _from, state) do
    new_row = max(min_row, min(max_row, row))
    {:reply, :ok, %{state | position: {new_row, col}}}
  end

  @impl true
  def handle_call({:move_to, row, col, min_row, max_row, min_col, max_col}, _from, state) do
    new_row = max(min_row, min(max_row, row))
    new_col = max(min_col, min(max_col, col))
    {:reply, :ok, %{state | position: {new_row, new_col}}}
  end

  @impl true
  def handle_call({:move_up, lines, min_row, max_row}, _from, state) do
    {row, col} = state.position
    new_row = max(min_row, row - lines)
    {:reply, :ok, %{state | position: {new_row, col}}}
  end

  @impl true
  def handle_call({:move_down, lines, min_row, max_row}, _from, state) do
    {row, col} = state.position
    new_row = min(max_row, row + lines)
    {:reply, :ok, %{state | position: {new_row, col}}}
  end

  @impl true
  def handle_call({:move_left, cols, min_col, max_col}, _from, state) do
    {row, col} = state.position
    new_col = max(min_col, col - cols)
    {:reply, :ok, %{state | position: {row, new_col}}}
  end

  @impl true
  def handle_call({:move_right, cols, min_col, max_col}, _from, state) do
    {row, col} = state.position
    new_col = min(max_col, col + cols)
    {:reply, :ok, %{state | position: {row, new_col}}}
  end

  @impl true
  def handle_call({:move_to_column, col, min_col, max_col}, _from, state) do
    {row, _} = state.position
    new_col = max(min_col, min(max_col, col))
    {:reply, :ok, %{state | position: {row, new_col}}}
  end

  @impl true
  def handle_call(:move_to_line_start, _from, state) do
    {row, _} = state.position
    {:reply, :ok, %{state | position: {row, 0}}}
  end

  @impl true
  def handle_call({:constrain_position, {min_row, min_col}, {max_row, max_col}}, _from, state) do
    {row, col} = state.position
    new_row = max(min_row, min(max_row, row))
    new_col = max(min_col, min(max_col, col))
    {:reply, :ok, %{state | position: {new_row, new_col}}}
  end

  @impl true
  def handle_call(request, _from, state) do
    Logger.warning("Unhandled call: #{inspect(request)}")
    {:reply, {:error, :unknown_call}, state}
  end
end
