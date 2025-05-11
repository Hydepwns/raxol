defmodule Raxol.Terminal.Buffer.Manager.Cursor do
  @moduledoc """
  Handles cursor management for the terminal buffer.
  Provides functionality for cursor position tracking and movement.
  """

  alias Raxol.Terminal.Buffer.Manager.State

  @doc """
  Sets the cursor position in the buffer state.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Cursor.set_position(state, 10, 5)
      iex> Cursor.get_position(state)
      {10, 5}
  """
  def set_position(%State{} = state, x, y) do
    %{state | cursor_position: {x, y}}
  end

  @doc """
  Gets the current cursor position.

  ## Examples

      iex> state = State.new(80, 24)
      iex> Cursor.get_position(state)
      {0, 0}
  """
  def get_position(%State{} = state) do
    state.cursor_position
  end

  @doc """
  Moves the cursor relative to its current position.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Cursor.move(state, 5, 3)
      iex> Cursor.get_position(state)
      {5, 3}
  """
  def move(%State{} = state, dx, dy) do
    {x, y} = state.cursor_position
    new_x = max(0, min(x + dx, state.active_buffer.width - 1))
    new_y = max(0, min(y + dy, state.active_buffer.height - 1))
    set_position(state, new_x, new_y)
  end

  @doc """
  Moves the cursor to the beginning of the line.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Cursor.set_position(state, 10, 5)
      iex> state = Cursor.move_to_line_start(state)
      iex> Cursor.get_position(state)
      {0, 5}
  """
  def move_to_line_start(%State{} = state) do
    {_, y} = state.cursor_position
    set_position(state, 0, y)
  end

  @doc """
  Moves the cursor to the end of the line.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Cursor.set_position(state, 10, 5)
      iex> state = Cursor.move_to_line_end(state)
      iex> Cursor.get_position(state)
      {79, 5}
  """
  def move_to_line_end(%State{} = state) do
    {_, y} = state.cursor_position
    set_position(state, state.active_buffer.width - 1, y)
  end

  @doc """
  Moves the cursor to the top of the screen.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Cursor.set_position(state, 10, 5)
      iex> state = Cursor.move_to_top(state)
      iex> Cursor.get_position(state)
      {10, 0}
  """
  def move_to_top(%State{} = state) do
    {x, _} = state.cursor_position
    set_position(state, x, 0)
  end

  @doc """
  Moves the cursor to the bottom of the screen.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Cursor.set_position(state, 10, 5)
      iex> state = Cursor.move_to_bottom(state)
      iex> Cursor.get_position(state)
      {10, 23}
  """
  def move_to_bottom(%State{} = state) do
    {x, _} = state.cursor_position
    set_position(state, x, state.active_buffer.height - 1)
  end
end
