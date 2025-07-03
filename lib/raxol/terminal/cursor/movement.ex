defmodule Raxol.Terminal.Cursor.Movement do
  @moduledoc """
  Handles cursor movement and positioning for the terminal emulator.

  This module provides functions for moving the cursor in various directions,
  handling relative and absolute positioning, and managing cursor boundaries.
  """

  alias Raxol.Terminal.Cursor.Manager

  @doc """
  Moves the cursor up by the specified number of lines, respecting margins.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Movement.move_up(cursor, 2)
      iex> cursor.position
      {0, 0}  # Already at top, no change
  """
  @spec move_up(
          Cursor.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Cursor.t()
  def move_up(cursor, count \\ 1, _width, _height) do
    # Move cursor up by count lines, but not above the top margin
    new_row = max(cursor.row - count, cursor.top_margin)
    Manager.move_to(cursor, new_row, cursor.col)
  end

  # 2-arity version for tests
  def move_up(cursor, count) do
    move_up(cursor, count, 80, 24)
  end

  @doc """
  Moves the cursor down by the specified number of lines, respecting margins.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Movement.move_down(cursor, 2)
      iex> cursor.position
      {0, 2}
  """
  @spec move_down(
          Cursor.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Cursor.t()
  def move_down(cursor, count \\ 1, _width, _height) do
    # Move cursor down by count lines, but not below the bottom margin
    new_row = min(cursor.row + count, cursor.bottom_margin)
    Manager.move_to(cursor, new_row, cursor.col)
  end

  # 2-arity version for tests
  def move_down(cursor, count) do
    move_down(cursor, count, 80, 24)
  end

  @doc """
  Moves the cursor left by the specified number of columns.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Manager.move_to(cursor, 0, 5)
      iex> cursor = Movement.move_left(cursor, 2)
      iex> cursor.position
      {3, 0}
  """
  def move_left(cursor, count \\ 1) do
    new_col = max(0, cursor.col - count)
    Manager.move_to(cursor, cursor.row, new_col)
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
    new_col = cursor.col + count
    Manager.move_to(cursor, cursor.row, new_col)
  end

  @doc """
  Moves the cursor to the beginning of the line.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Manager.move_to(cursor, 0, 10)
      iex> cursor = Movement.move_to_line_start(cursor)
      iex> cursor.position
      {0, 0}
  """
  def move_to_line_start(cursor) do
    Manager.move_to(cursor, cursor.row, 0)
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
    Manager.move_to(cursor, cursor.row, line_width - 1)
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
    Manager.move_to(cursor, cursor.row, column)
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
    Manager.move_to(cursor, line, cursor.col)
  end

  @doc """
  Moves the cursor to a specific position in the terminal.
  """
  def move_to_position(cursor, row, col) do
    Manager.move_to(cursor, row, col)
  end

  @doc """
  Moves the cursor to a specific position with row bounds.
  """
  def move_to(cursor, row, _col, min_row, max_row) do
    {_current_row, current_col} = Manager.get_position(cursor)
    new_row = max(min_row, min(max_row, row))
    Manager.move_to(cursor, new_row, current_col)
  end

  @doc """
  Moves the cursor to a specific position with both row and column bounds.
  """
  def move_to(cursor, row, col, min_row, max_row, min_col, max_col) do
    new_row = max(min_row, min(max_row, row))
    new_col = max(min_col, min(max_col, col))
    Manager.move_to(cursor, new_row, new_col)
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
  def move_home(cursor, width, height) do
    Manager.move_to(cursor, 0, 0, width, height)
  end

  # 1-arity version for tests
  def move_home(cursor) do
    Manager.move_to(cursor, 0, 0)
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
  def move_to_next_tab(cursor, tab_stops, width, height) do
    next_tab = find_next_tab(cursor.col, tab_stops, width)
    Manager.move_to(cursor, cursor.row, next_tab, width, height)
  end

  # 2-arity version for tests
  def move_to_next_tab(cursor, tab_size) do
    next_tab = div(cursor.col + tab_size, tab_size) * tab_size
    Manager.move_to(cursor, cursor.row, next_tab)
  end

  @doc """
  Moves the cursor to the previous tab stop.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Movement}
      iex> cursor = Manager.new()
      iex> cursor = Manager.move_to(cursor, 0, 10)
      iex> cursor = Movement.move_to_prev_tab(cursor, 8)
      iex> cursor.position
      {8, 0}
  """
  def move_to_prev_tab(cursor, tab_stops, width, height) do
    prev_tab = find_previous_tab(cursor.col, tab_stops)
    Manager.move_to(cursor, cursor.row, prev_tab, width, height)
  end

  # 2-arity version for tests
  def move_to_prev_tab(cursor, tab_size) do
    prev_tab = div(cursor.col - 1, tab_size) * tab_size
    prev_tab = max(prev_tab, 0)
    Manager.move_to(cursor, cursor.row, prev_tab)
  end

  # Helper functions

  defp find_next_tab(current_col, tab_stops, width) do
    case Enum.find(tab_stops, fn stop -> stop > current_col end) do
      nil -> width - 1
      stop -> stop
    end
  end

  defp find_previous_tab(current_col, tab_stops) do
    case Enum.find(Enum.reverse(tab_stops), fn stop -> stop < current_col end) do
      nil -> 0
      stop -> stop
    end
  end
end
