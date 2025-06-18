defmodule Raxol.Terminal.Buffer.Manager.Cursor do
  @moduledoc '''
  Handles cursor management for the terminal buffer.
  Provides functionality for cursor position tracking and movement.
  '''

  alias Raxol.Terminal.Buffer.Manager.State

  @doc '''
  Sets the cursor position to the specified coordinates.
  '''
  @spec set_position(State.t(), non_neg_integer(), non_neg_integer()) ::
          State.t()
  def set_position(%State{} = state, x, y) do
    move_to(state, x, y)
  end

  @doc '''
  Moves the cursor to the specified coordinates.
  '''
  @spec move_to(State.t(), non_neg_integer(), non_neg_integer()) :: State.t()
  def move_to(%State{} = state, x, y) do
    new_x = min(max(0, x), state.active_buffer.width - 1)
    new_y = min(max(0, y), state.active_buffer.height - 1)
    %{state | cursor_position: {new_x, new_y}}
  end

  @doc '''
  Moves the cursor to the start of the current line.
  '''
  @spec move_to_line_start(State.t()) :: State.t()
  def move_to_line_start(%State{} = state) do
    {_, y} = state.cursor_position
    move_to(state, 0, y)
  end

  @doc '''
  Moves the cursor to the end of the current line.
  '''
  @spec move_to_line_end(State.t()) :: State.t()
  def move_to_line_end(%State{} = state) do
    {_, y} = state.cursor_position
    move_to(state, state.active_buffer.width - 1, y)
  end

  @doc '''
  Moves the cursor to the top of the screen.
  '''
  @spec move_to_top(State.t()) :: State.t()
  def move_to_top(%State{} = state) do
    {x, _} = state.cursor_position
    move_to(state, x, 0)
  end

  @doc '''
  Moves the cursor to the bottom of the screen.
  '''
  @spec move_to_bottom(State.t()) :: State.t()
  def move_to_bottom(%State{} = state) do
    {x, _} = state.cursor_position
    move_to(state, x, state.active_buffer.height - 1)
  end

  @doc '''
  Gets the current cursor position.

  ## Examples

      iex> state = State.new(80, 24)
      iex> Cursor.get_position(state)
      {0, 0}
  '''
  def get_position(%State{} = state) do
    state.cursor_position
  end

  @doc '''
  Moves the cursor relative to its current position.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Cursor.move(state, 5, 3)
      iex> Cursor.get_position(state)
      {5, 3}
  '''
  def move(%State{} = state, dx, dy) do
    {x, y} = state.cursor_position
    new_x = max(0, min(x + dx, state.active_buffer.width - 1))
    new_y = max(0, min(y + dy, state.active_buffer.height - 1))
    set_position(state, new_x, new_y)
  end
end
