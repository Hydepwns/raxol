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
  alias Raxol.Terminal.ScreenBuffer
  require Raxol.Core.Runtime.Log

  @spec handle_cursor_movement(
          Emulator.t(),
          atom(),
          integer()
        ) :: {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cursor_movement(emulator, direction, amount) do
    cursor = emulator.cursor
    {x, y} = get_cursor_position(cursor)

    {new_x, new_y} = case direction do
      :up -> {x, max(0, y - amount)}
      :down -> {x, min(emulator.height - 1, y + amount)}
      :left -> {max(0, x - amount), y}
      :right -> {min(emulator.width - 1, x + amount), y}
    end

    updated_cursor = set_cursor_position(cursor, {new_x, new_y})
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

    # Position is {x, y} where x is column and y is row
    updated_cursor = set_cursor_position(emulator.cursor, {col_clamped, row_clamped})
    {:ok, %{emulator | cursor: updated_cursor}}
  end

  @doc "Handles Cursor Position (CUP - 'H') - alias for handle_cup"
  @spec handle_H(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_H(emulator, params) do
    handle_cup(emulator, params)
  end

  @doc "Handles Cursor Up (CUU - \'A\')"
  @spec handle_A(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_A(emulator, params) do
    amount = Enum.at(params, 0, 1)
    handle_cursor_movement(emulator, :up, amount)
  end

  @doc "Handles Cursor Down (CUD - \'B\') - alias for handle_B"
  @spec handle_B(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_B(emulator, params) do
    amount = Enum.at(params, 0, 1)
    handle_cursor_movement(emulator, :down, amount)
  end

  @doc "Handles Cursor Forward (CUF - \'C\') - alias for handle_C"
  @spec handle_C(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_C(emulator, params) do
    amount = Enum.at(params, 0, 1)
    handle_cursor_movement(emulator, :right, amount)
  end

  @doc "Handles Cursor Backward (CUB - \'D\') - alias for handle_D"
  @spec handle_D(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_D(emulator, params) do
    amount = Enum.at(params, 0, 1)
    handle_cursor_movement(emulator, :left, amount)
  end

  @doc """
  Handles Cursor Next Line (CNL - 'E').
  """
  @spec handle_E(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_E(emulator, params) do
    amount = Enum.at(params, 0, 1)
    cursor = emulator.cursor
    {x, y} = get_cursor_position(cursor)

    # Move down by amount, clamp to screen height
    new_y = min(emulator.height - 1, y + amount)

    # Move to beginning of line (column 0)
    updated_cursor = set_cursor_position(cursor, {0, new_y})
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
    {x, y} = get_cursor_position(cursor)

    # Move up by amount, clamp to screen top
    new_y = max(0, y - amount)

    # Move to beginning of line (column 0)
    updated_cursor = set_cursor_position(cursor, {0, new_y})
    {:ok, %{emulator | cursor: updated_cursor}}
  end

  @doc """
  Handles Cursor Previous Line (CPL - 'F') - alias for handle_f.
  """
  @spec handle_F(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_F(emulator, params) do
    handle_f(emulator, params)
  end

  @doc """
  Handles Cursor Horizontal Absolute (CHA - 'G').
  """
  @spec handle_g(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_g(emulator, params) do
    column = Enum.at(params, 0, 1)
    column_0 = column - 1  # Convert to 0-based

    # Clamp to screen width
    column_clamped = max(0, min(column_0, emulator.width - 1))

    cursor = emulator.cursor
    {_, current_y} = get_cursor_position(cursor)
    updated_cursor = set_cursor_position(cursor, {column_clamped, current_y})

    {:ok, %{emulator | cursor: updated_cursor}}
  end

  @doc """
  Handles Cursor Horizontal Absolute (CHA - 'G') - alias for handle_g.
  """
  @spec handle_G(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_G(emulator, params) do
    handle_g(emulator, params)
  end

  @doc "Handles Cursor Vertical Absolute (VPA - \'d\")"
  @spec handle_decvpa(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_decvpa(emulator, params) do
    row = get_valid_pos_param(params, 0, 1)
    row_0 = row - 1  # Convert to 0-based

    # Clamp to screen height
    row_clamped = max(0, min(row_0, emulator.height - 1))

    cursor = emulator.cursor
    {current_x, _} = get_cursor_position(cursor)
    updated_cursor = set_cursor_position(cursor, {current_x, row_clamped})

    {:ok, %{emulator | cursor: updated_cursor}}
  end

  @doc "Handles Cursor Vertical Absolute (VPA - 'd') - alias for handle_decvpa"
  @spec handle_d(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_d(emulator, params) do
    handle_decvpa(emulator, params)
  end

  # Private helper functions
  defp get_valid_non_neg_param(params, index, default) do
    case Enum.at(params, index) do
      nil -> default
      value when integer?(value) and value >= 0 -> value
      _ -> default
    end
  end

  defp get_valid_pos_param(params, index, default) do
    case Enum.at(params, index) do
      nil -> default
      value when integer?(value) and value > 0 -> value
      _ -> default
    end
  end

  # Helper functions to handle both cursor structs and PIDs
  defp get_cursor_position(cursor) when is_pid(cursor) do
    CursorManager.get_position(cursor)
  end

  defp get_cursor_position(cursor) when is_map(cursor) do
    cursor.position
  end

  defp set_cursor_position(cursor, position) when is_pid(cursor) do
    CursorManager.set_position(cursor, position)
    cursor
  end

  defp set_cursor_position(cursor, position) when is_map(cursor) do
    %{cursor | position: position}
  end
end
