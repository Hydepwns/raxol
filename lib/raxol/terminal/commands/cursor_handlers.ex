defmodule Raxol.Terminal.Commands.CursorHandlers do
  @moduledoc """
  Handles cursor movement related CSI commands.

  This module contains handlers for cursor movement commands like CUP, CUU, CUD, etc.
  Each function takes the current emulator state and parsed parameters,
  returning the updated emulator state.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ScreenBuffer
  require Raxol.Core.Runtime.Log

  @doc """
  Helper function to handle cursor movement operations.
  Takes the emulator, movement function, and movement parameters.
  """
  @spec handle_cursor_movement(
          Emulator.t(),
          (CursorManager.t(), integer(), integer(), integer() ->
             CursorManager.t()),
          integer()
        ) :: {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cursor_movement(emulator, movement_fn, amount) do
    active_buffer = Emulator.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    new_cursor = movement_fn.(emulator.cursor, amount, width, height)
    {:ok, %{emulator | cursor: new_cursor}}
  end

  @doc "Handles Cursor Position (CUP - \'H\")"
  @spec handle_cup(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cup(emulator, params) do
    row = get_valid_pos_param(params, 0, 1)
    col = get_valid_pos_param(params, 1, 1)
    active_buffer = Emulator.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)

    new_cursor =
      CursorManager.move_to(emulator.cursor, {col - 1, row - 1}, width, height)

    {:ok, %{emulator | cursor: new_cursor}}
  end

  @doc "Handles Cursor Up (CUU - \'A\")"
  @spec handle_a(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_a(emulator, params) do
    amount = get_valid_non_neg_param(params, 0, 1)
    handle_cursor_movement(emulator, &CursorManager.move_up/4, amount)
  end

  @doc "Handles Cursor Down (CUD - \'B\")"
  @spec handle_b(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_b(emulator, params) do
    amount = get_valid_non_neg_param(params, 0, 1)
    handle_cursor_movement(emulator, &CursorManager.move_down/4, amount)
  end

  @doc "Handles Cursor Forward (CUF - \'C\")"
  @spec handle_c(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_c(emulator, params) do
    amount = get_valid_non_neg_param(params, 0, 1)
    handle_cursor_movement(emulator, &CursorManager.move_right/4, amount)
  end

  @doc "Handles Cursor Backward (CUB - \'D\")"
  @spec handle_d(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_d(emulator, params) do
    amount = get_valid_non_neg_param(params, 0, 1)
    handle_cursor_movement(emulator, &CursorManager.move_left/4, amount)
  end

  @doc "Handles Cursor Next Line (CNL - \'E\")"
  @spec handle_e(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_e(emulator, params) do
    amount = get_valid_non_neg_param(params, 0, 1)

    emulator
    |> handle_cursor_movement(&CursorManager.move_down/4, amount)
    |> (fn {:ok, emu} ->
          handle_cursor_movement(emu, &CursorManager.move_to_column/4, 0)
        end).()
  end

  @doc "Handles Cursor Previous Line (CPL - \'F\")"
  @spec handle_f(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_f(emulator, params) do
    amount = get_valid_non_neg_param(params, 0, 1)

    emulator
    |> handle_cursor_movement(&CursorManager.move_up/4, amount)
    |> (fn {:ok, emu} ->
          handle_cursor_movement(emu, &CursorManager.move_to_column/4, 0)
        end).()
  end

  @doc "Handles Cursor Horizontal Absolute (CHA - \'G\")"
  @spec handle_g(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_g(emulator, params) do
    column = get_valid_pos_param(params, 0, 1)

    handle_cursor_movement(
      emulator,
      &CursorManager.move_to_column/4,
      column - 1
    )
  end

  @doc "Handles Cursor Vertical Absolute (VPA - \'d\")"
  @spec handle_decvpa(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_decvpa(emulator, params) do
    row = get_valid_pos_param(params, 0, 1)
    active_buffer = Emulator.get_active_buffer(emulator)
    height = ScreenBuffer.get_height(active_buffer)
    new_row = min(row - 1, height - 1)

    {current_col, _} =
      Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    width = ScreenBuffer.get_width(active_buffer)

    new_cursor =
      CursorManager.move_to(
        emulator.cursor,
        {current_col, new_row},
        width,
        height
      )

    {:ok, %{emulator | cursor: new_cursor}}
  end

  # Private helper functions
  defp get_valid_non_neg_param(params, index, default) do
    case Enum.at(params, index) do
      nil -> default
      value when is_integer(value) and value >= 0 -> value
      _ -> default
    end
  end

  defp get_valid_pos_param(params, index, default) do
    case Enum.at(params, index) do
      nil -> default
      value when is_integer(value) and value > 0 -> value
      _ -> default
    end
  end
end
