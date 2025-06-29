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
    CursorManager.move_cursor(emulator.cursor, direction, amount)
    {:ok, emulator}
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

    CursorManager.set_position(emulator.cursor, {row_0, col_0})
    {:ok, emulator}
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

    # Move down by amount
    CursorManager.move_cursor(emulator.cursor, :down, amount)

    # Move to beginning of line
    {current_row, _} = CursorManager.get_position(emulator.cursor)
    CursorManager.set_position(emulator.cursor, {current_row, 0})

    {:ok, emulator}
  end

  @doc """
  Handles Cursor Previous Line (CPL - 'F').
  """
  @spec handle_f(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_f(emulator, params) do
    amount = Enum.at(params, 0, 1)

    # Move up by amount
    CursorManager.move_cursor(emulator.cursor, :up, amount)

    # Move to beginning of line
    {current_row, _} = CursorManager.get_position(emulator.cursor)
    CursorManager.set_position(emulator.cursor, {current_row, 0})

    {:ok, emulator}
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

    {current_row, _} = CursorManager.get_position(emulator.cursor)
    CursorManager.set_position(emulator.cursor, {current_row, column_0})

    {:ok, emulator}
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

    {_, current_col} = CursorManager.get_position(emulator.cursor)
    CursorManager.set_position(emulator.cursor, {row_0, current_col})

    {:ok, emulator}
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
end
