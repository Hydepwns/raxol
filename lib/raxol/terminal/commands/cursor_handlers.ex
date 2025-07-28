defmodule Raxol.Terminal.Commands.CursorHandlers do
  @moduledoc """
  Handles cursor movement related CSI commands.

  This module contains handlers for cursor movement commands like CUP, CUU, CUD, etc.
  Each function takes the current emulator state and parsed parameters,
  returning the updated emulator state.
  """

  import Raxol.Guards
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager

  require Raxol.Core.Runtime.Log

  @spec handle_cursor_movement(
          Emulator.t(),
          atom(),
          integer()
        ) :: {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cursor_movement(emulator, direction, amount) do
    cursor = emulator.cursor
    {row, col} = get_cursor_position(cursor)

    {new_row, new_col} =
      case direction do
        :up -> {max(0, row - amount), col}
        :down -> {min(emulator.height - 1, row + amount), col}
        :left -> {row, max(0, col - amount)}
        :right -> {row, min(emulator.width - 1, col + amount)}
      end

    updated_cursor = set_cursor_position(cursor, {new_row, new_col})
    {:ok, %{emulator | cursor: updated_cursor}}
  end

  @doc "Handles Cursor Position (CUP - \'H\")"
  @spec handle_cup(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cup(emulator, params) do
    row = get_valid_pos_param(params, 0, 1)
    col = get_valid_pos_param(params, 1, 1)

    # Convert to 0-based coordinates
    row_0 = row - 1
    col_0 = col - 1

    # Clamp to screen bounds
    row_clamped = max(0, min(row_0, emulator.height - 1))
    col_clamped = max(0, min(col_0, emulator.width - 1))

    # Pass {row, col} to match new convention
    updated_cursor =
      set_cursor_position(emulator.cursor, {row_clamped, col_clamped})

    {:ok, %{emulator | cursor: updated_cursor}}
  end

  @doc "Handles Cursor Position (CUP - 'H') - alias for handle_cup"
  @spec handle_h_alias(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_h_alias(emulator, params) do
    handle_cup(emulator, params)
  end

  @doc "Handles Cursor Up (CUU - \'A\')"
  @spec handle_a_alias(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_a_alias(emulator, params) do
    amount = Enum.at(params, 0, 1)
    handle_cursor_movement(emulator, :up, amount)
  end

  @doc "Handles Cursor Down (CUD - \'B\') - alias for handle_B"
  @spec handle_b_alias(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_b_alias(emulator, params) do
    amount = Enum.at(params, 0, 1)
    handle_cursor_movement(emulator, :down, amount)
  end

  @doc "Handles Cursor Forward (CUF - \'C\') - alias for handle_C"
  @spec handle_c_alias(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_c_alias(emulator, params) do
    amount = Enum.at(params, 0, 1)
    handle_cursor_movement(emulator, :right, amount)
  end

  @doc "Handles Cursor Backward (CUB - \'D\') - alias for handle_D"
  @spec handle_d_alias(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_d_alias(emulator, params) do
    amount = Enum.at(params, 0, 1)
    handle_cursor_movement(emulator, :left, amount)
  end

  @doc """
  Handles Cursor Next Line (CNL - 'E').
  """
  @spec handle_e_alias(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_e_alias(emulator, params) do
    amount = Enum.at(params, 0, 1)
    cursor = emulator.cursor
    {row, _col} = get_cursor_position(cursor)

    # Move down by amount, clamp to screen height
    new_row = min(emulator.height - 1, row + amount)

    # Move to beginning of line (column 0) at the new row
    updated_cursor = set_cursor_position(cursor, {new_row, 0})
    {:ok, %{emulator | cursor: updated_cursor}}
  end

  @doc """
  Handles Cursor Previous Line (CPL - 'F').
  """
  @spec handle_f(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_f(emulator, params) do
    amount = Enum.at(params, 0, 1)
    cursor = emulator.cursor
    {row, _col} = get_cursor_position(cursor)

    # Move up by amount, clamp to screen top
    new_row = max(0, row - amount)

    # Move to beginning of line (column 0) at the new row
    updated_cursor = set_cursor_position(cursor, {new_row, 0})
    {:ok, %{emulator | cursor: updated_cursor}}
  end

  @doc """
  Handles Cursor Previous Line (CPL - 'F') - alias for handle_f.
  """
  @spec handle_f_alias(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_f_alias(emulator, params) do
    handle_f(emulator, params)
  end

  @doc """
  Handles Cursor Horizontal Absolute (CHA - 'G').
  """
  @spec handle_g(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_g(emulator, params) do
    # handle_g is the same as handle_G (Cursor Horizontal Absolute)
    handle_G(emulator, params)
  end

  @doc """
  Handles Cursor Horizontal Absolute (CHA - 'G') - alias for handle_g.
  """
  @spec handle_g_alias(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_g_alias(emulator, params) do
    IO.puts(
      "DEBUG: handle_G called with params=#{inspect(params)}, cursor=#{inspect(emulator.cursor)}"
    )

    column = Enum.at(params, 0, 1)
    # Convert to 0-based
    column_0 = column - 1

    # Clamp to screen width
    column_clamped = max(0, min(column_0, emulator.width - 1))

    cursor = emulator.cursor
    {current_row, _} = get_cursor_position(cursor)
    updated_cursor = set_cursor_position(cursor, {current_row, column_clamped})

    {:ok, %{emulator | cursor: updated_cursor}}
  end

  @doc "Handles Cursor Vertical Absolute (VPA - \'d\') - alias for handle_decvpa"
  @spec handle_d(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_d(emulator, params) do
    handle_decvpa(emulator, params)
  end

  @doc "Handles Cursor Vertical Absolute (VPA - \'d\")"
  @spec handle_decvpa(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_decvpa(emulator, params) do
    row = get_valid_pos_param(params, 0, 1)
    # Convert to 0-based
    row_0 = row - 1

    # Clamp to screen height
    row_clamped = max(0, min(row_0, emulator.height - 1))

    cursor = emulator.cursor
    {current_col, _} = get_cursor_position(cursor)
    updated_cursor = set_cursor_position(cursor, {row_clamped, current_col})

    {:ok, %{emulator | cursor: updated_cursor}}
  end

  @doc """
  Moves the cursor to a specific position with width and height bounds.
  """
  @spec move_cursor_to(
          Emulator.t(),
          {integer(), integer()},
          integer(),
          integer()
        ) :: Emulator.t()
  def move_cursor_to(emulator, position, width, height) do
    {row, col} = position
    # Clamp coordinates to screen bounds
    row_clamped = max(0, min(row, height - 1))
    col_clamped = max(0, min(col, width - 1))

    updated_cursor =
      set_cursor_position(emulator.cursor, {row_clamped, col_clamped})

    %{emulator | cursor: updated_cursor}
  end

  @doc """
  Moves the cursor to a specific position.
  """
  @spec move_cursor_to(Emulator.t(), integer(), integer()) :: Emulator.t()
  def move_cursor_to(emulator, x, y) do
    move_cursor_to(emulator, {x, y}, emulator.width, emulator.height)
  end

  @doc """
  Moves the cursor up by the specified number of lines.
  """
  @spec move_cursor_up(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_cursor_up(emulator, count \\ 1) do
    cursor = emulator.cursor
    {row, col} = get_cursor_position(cursor)
    new_row = max(0, row - count)
    updated_cursor = set_cursor_position(cursor, {new_row, col})
    %{emulator | cursor: updated_cursor}
  end

  @doc """
  Moves the cursor up by the specified number of lines with width and height bounds.
  """
  @spec move_cursor_up(
          Emulator.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Emulator.t()
  def move_cursor_up(emulator, count, _width, _height) do
    cursor = emulator.cursor
    {row, col} = get_cursor_position(cursor)
    new_row = max(0, row - count)
    updated_cursor = set_cursor_position(cursor, {new_row, col})
    %{emulator | cursor: updated_cursor}
  end

  @doc """
  Moves the cursor down by the specified number of lines.
  """
  @spec move_cursor_down(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_cursor_down(emulator, count \\ 1) do
    cursor = emulator.cursor
    {row, col} = get_cursor_position(cursor)
    new_row = min(emulator.height - 1, row + count)
    updated_cursor = set_cursor_position(cursor, {new_row, col})
    %{emulator | cursor: updated_cursor}
  end

  @doc """
  Moves the cursor down by the specified number of lines with width and height bounds.
  """
  @spec move_cursor_down(
          Emulator.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Emulator.t()
  def move_cursor_down(emulator, count, _width, height) do
    cursor = emulator.cursor
    {row, col} = get_cursor_position(cursor)
    new_row = min(height - 1, row + count)
    updated_cursor = set_cursor_position(cursor, {new_row, col})
    %{emulator | cursor: updated_cursor}
  end

  @doc """
  Moves the cursor left by the specified number of columns.
  """
  @spec move_cursor_left(
          Emulator.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Emulator.t()
  def move_cursor_left(emulator, count, _width, _height) do
    cursor = emulator.cursor
    {row, col} = get_cursor_position(cursor)
    new_col = max(0, col - count)
    updated_cursor = set_cursor_position(cursor, {row, new_col})
    %{emulator | cursor: updated_cursor}
  end

  @doc """
  Moves the cursor right by the specified number of columns.
  """
  @spec move_cursor_right(
          Emulator.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Emulator.t()
  def move_cursor_right(emulator, count, width, _height) do
    cursor = emulator.cursor
    {row, col} = get_cursor_position(cursor)
    new_col = min(width - 1, col + count)
    updated_cursor = set_cursor_position(cursor, {row, new_col})
    %{emulator | cursor: updated_cursor}
  end

  @doc """
  Moves the cursor forward by the specified number of columns.
  """
  @spec move_cursor_forward(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_cursor_forward(emulator, count) do
    move_cursor_right(emulator, count, emulator.width, emulator.height)
  end

  @doc """
  Moves the cursor back by the specified number of columns.
  """
  @spec move_cursor_back(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_cursor_back(emulator, count) do
    move_cursor_left(emulator, count, emulator.width, emulator.height)
  end

  @doc """
  Moves the cursor to the start of the current line.
  """
  @spec move_cursor_to_line_start(Emulator.t()) :: Emulator.t()
  def move_cursor_to_line_start(emulator) do
    cursor = emulator.cursor
    {row, _col} = get_cursor_position(cursor)
    updated_cursor = set_cursor_position(cursor, {row, 0})
    %{emulator | cursor: updated_cursor}
  end

  @doc """
  Moves the cursor to a specific column.
  """
  @spec move_cursor_to_column(
          Emulator.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Emulator.t()
  def move_cursor_to_column(emulator, column, width, _height) do
    cursor = emulator.cursor
    {row, _col} = get_cursor_position(cursor)
    new_col = max(0, min(width - 1, column))
    updated_cursor = set_cursor_position(cursor, {row, new_col})
    %{emulator | cursor: updated_cursor}
  end

  defp get_valid_pos_param(params, index, default) do
    case Enum.at(params, index) do
      nil -> default
      value when integer?(value) and value > 0 -> value
      _ -> default
    end
  end

  # Helper functions to handle both cursor structs and PIDs
  defp set_cursor_position(%CursorManager{} = cursor, {row, col}) do
    %CursorManager{cursor | row: row, col: col, position: {row, col}}
  end

  defp set_cursor_position(cursor, position) when is_pid(cursor) do
    CursorManager.set_position(cursor, position)
    cursor
  end

  defp set_cursor_position(cursor, position) when is_map(cursor) do
    {row, col} = position
    %{cursor | position: {row, col}, row: row, col: col}
  end

  # Fallback clause for any other cursor type
  defp set_cursor_position(cursor, {row, col}) do
    # Try to handle any cursor type that might have position, row, col fields
    case cursor do
      %{position: _} when is_map(cursor) ->
        %{cursor | position: {row, col}}

      %{row: _, col: _} when is_map(cursor) ->
        %{cursor | row: row, col: col, position: {row, col}}

      _ ->
        # If we can't handle it, return the cursor unchanged
        cursor
    end
  end

  defp get_cursor_position(cursor) when is_pid(cursor) do
    CursorManager.get_position(cursor)
  end

  defp get_cursor_position(cursor) when is_map(cursor) do
    cursor.position
  end

  @doc """
  Handles CSI A - Cursor Up (CUU)
  """
  def handle_A(emulator, params) do
    count = get_valid_pos_param(params, 0, 1)
    {:ok, move_cursor_up(emulator, count)}
  end

  @doc """
  Handles CSI B - Cursor Down (CUD)
  """
  def handle_B(emulator, params) do
    count = get_valid_pos_param(params, 0, 1)
    {:ok, move_cursor_down(emulator, count)}
  end

  @doc """
  Handles CSI C - Cursor Forward (CUF)
  """
  def handle_C(emulator, params) do
    count = get_valid_pos_param(params, 0, 1)
    {:ok, move_cursor_forward(emulator, count)}
  end

  @doc """
  Handles CSI D - Cursor Back (CUB)
  """
  def handle_D(emulator, params) do
    count = get_valid_pos_param(params, 0, 1)
    {:ok, move_cursor_back(emulator, count)}
  end

  @doc """
  Handles CSI G - Cursor Horizontal Absolute (CHA)
  """
  def handle_G(emulator, params) do
    # Convert to 0-based
    column = get_valid_pos_param(params, 0, 1) - 1

    {:ok,
     move_cursor_to_column(emulator, column, emulator.width, emulator.height)}
  end

  @doc """
  Handles CSI E - Cursor Next Line (CNL)
  Moves cursor to beginning of line n lines down
  """
  def handle_E(emulator, params) do
    count = get_valid_pos_param(params, 0, 1)
    
    # Move down by count lines
    emulator_after_down = move_cursor_down(emulator, count)
    
    # Move to column 0
    {:ok, move_cursor_to_column(emulator_after_down, 0, emulator.width, emulator.height)}
  end

  @doc """
  Handles CSI F - Cursor Previous Line (CPL)
  Moves cursor to beginning of line n lines up
  """
  def handle_F(emulator, params) do
    count = get_valid_pos_param(params, 0, 1)
    
    # Move up by count lines
    emulator_after_up = move_cursor_up(emulator, count)
    
    # Move to column 0
    {:ok, move_cursor_to_column(emulator_after_up, 0, emulator.width, emulator.height)}
  end

  @doc """
  Handles CSI H - Cursor Position (CUP)
  Sets cursor position to row;column
  """
  def handle_H(emulator, params) do
    handle_cup(emulator, params)
  end
end
