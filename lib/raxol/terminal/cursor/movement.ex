defmodule Raxol.Terminal.Cursor.Movement do
  @moduledoc """
  Handles cursor movement and positioning for the terminal emulator.

  This module provides functions for moving the cursor in various directions,
  handling relative and absolute positioning, and managing cursor boundaries.
  """

  alias Raxol.Terminal.Cursor.Manager

  @doc """
  Moves the cursor up by the specified number of lines.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Movement.move_up(cursor, 2)
      iex> cursor.position
      {0, 0}  # Already at top, no change
  """
  def move_up(cursor, count \\ 1) do
    {x, y} = Manager.get_position(cursor)
    new_y = max(0, y - count)
    Manager.move_to(cursor, {x, new_y})
  end

  @doc """
  Moves the cursor down by the specified number of lines.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Movement.move_down(cursor, 2)
      iex> cursor.position
      {0, 2}
  """
  def move_down(cursor, count \\ 1) do
    {x, y} = Manager.get_position(cursor)
    new_y = y + count
    Manager.move_to(cursor, {x, new_y})
  end

  @doc """
  Moves the cursor left by the specified number of columns.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Manager.move_to(cursor, 5, 0)
      iex> cursor = Movement.move_left(cursor, 2)
      iex> cursor.position
      {3, 0}
  """
  def move_left(cursor, count \\ 1) do
    {x, y} = Manager.get_position(cursor)
    new_x = max(0, x - count)
    Manager.move_to(cursor, {new_x, y})
  end

  @doc """
  Moves the cursor right by the specified number of columns.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Movement.move_right(cursor, 2)
      iex> cursor.position
      {2, 0}
  """
  def move_right(cursor, count \\ 1) do
    {x, y} = Manager.get_position(cursor)
    new_x = x + count
    Manager.move_to(cursor, {new_x, y})
  end

  @doc """
  Moves the cursor to the beginning of the line.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Manager.move_to(cursor, 10, 0)
      iex> cursor = Movement.move_to_line_start(cursor)
      iex> cursor.position
      {0, 0}
  """
  def move_to_line_start(cursor) do
    {_, y} = Manager.get_position(cursor)
    Manager.move_to(cursor, {0, y})
  end

  @doc """
  Moves the cursor to the end of the line.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Movement.move_to_line_end(cursor, 80)
      iex> cursor.position
      {79, 0}
  """
  def move_to_line_end(cursor, line_width) do
    {_, y} = Manager.get_position(cursor)
    Manager.move_to(cursor, {line_width - 1, y})
  end

  @doc """
  Moves the cursor to the specified column.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Movement.move_to_column(cursor, 10)
      iex> cursor.position
      {10, 0}
  """
  def move_to_column(cursor, column) do
    {_, y} = Manager.get_position(cursor)
    Manager.move_to(cursor, {column, y})
  end

  @doc """
  Moves the cursor to the specified line.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Movement.move_to_line(cursor, 5)
      iex> cursor.position
      {0, 5}
  """
  def move_to_line(cursor, line) do
    {x, _} = Manager.get_position(cursor)
    Manager.move_to(cursor, {x, line})
  end

  @doc """
  Moves the cursor to the specified position.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Movement.move_to_position(cursor, 10, 5)
      iex> cursor.position
      {10, 5}
  """
  def move_to_position(cursor, column, line) do
    Manager.move_to(cursor, {column, line})
  end

  @doc """
  Moves the cursor to the home position (0, 0).

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Manager.move_to(cursor, 10, 5)
      iex> cursor = Movement.move_home(cursor)
      iex> cursor.position
      {0, 0}
  """
  def move_home(cursor) do
    Manager.move_to(cursor, {0, 0})
  end

  @doc """
  Moves the cursor to the next tab stop.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Movement.move_to_next_tab(cursor, 8)
      iex> cursor.position
      {8, 0}
  """
  def move_to_next_tab(cursor, tab_width) do
    {x, y} = Manager.get_position(cursor)
    next_tab = div(x + tab_width, tab_width) * tab_width
    Manager.move_to(cursor, {next_tab, y})
  end

  @doc """
  Moves the cursor to the previous tab stop.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Manager.move_to(cursor, 10, 0)
      iex> cursor = Movement.move_to_prev_tab(cursor, 8)
      iex> cursor.position
      {8, 0}
  """
  def move_to_prev_tab(cursor, tab_width) do
    {x, y} = Manager.get_position(cursor)
    prev_tab = max(0, div(x - 1, tab_width) * tab_width)
    Manager.move_to(cursor, {prev_tab, y})
  end
end
