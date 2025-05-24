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
  require Logger

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

  @doc "Handles Cursor Position (CUP - 'H')"
  @spec handle_H(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_H(emulator, params) do
    row = get_valid_pos_param(params, 0, 1)
    col = get_valid_pos_param(params, 1, 1)
    active_buffer = Emulator.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)

    new_cursor =
      CursorManager.move_to(emulator.cursor, {col - 1, row - 1}, width, height)

    {:ok, %{emulator | cursor: new_cursor}}
  end

  @doc "Handles Cursor Up (CUU - 'A')"
  @spec handle_A(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_A(emulator, params) do
    amount = get_valid_non_neg_param(params, 0, 1)
    handle_cursor_movement(emulator, &CursorManager.move_up/4, amount)
  end

  @doc "Handles Cursor Down (CUD - 'B')"
  @spec handle_B(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_B(emulator, params) do
    amount = get_valid_non_neg_param(params, 0, 1)
    handle_cursor_movement(emulator, &CursorManager.move_down/4, amount)
  end

  @doc "Handles Cursor Forward (CUF - 'C')"
  @spec handle_C(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_C(emulator, params) do
    amount = get_valid_non_neg_param(params, 0, 1)
    handle_cursor_movement(emulator, &CursorManager.move_right/4, amount)
  end

  @doc "Handles Cursor Backward (CUB - 'D')"
  @spec handle_D(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_D(emulator, params) do
    amount = get_valid_non_neg_param(params, 0, 1)
    handle_cursor_movement(emulator, &CursorManager.move_left/4, amount)
  end

  @doc "Handles Cursor Next Line (CNL - 'E')"
  @spec handle_E(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_E(emulator, params) do
    amount = get_valid_non_neg_param(params, 0, 1)

    emulator
    |> handle_cursor_movement(&CursorManager.move_down/4, amount)
    |> (fn {:ok, emu} ->
          handle_cursor_movement(emu, &CursorManager.move_to_column/4, 0)
        end).()
  end

  @doc "Handles Cursor Previous Line (CPL - 'F')"
  @spec handle_F(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_F(emulator, params) do
    amount = get_valid_non_neg_param(params, 0, 1)

    emulator
    |> handle_cursor_movement(&CursorManager.move_up/4, amount)
    |> (fn {:ok, emu} ->
          handle_cursor_movement(emu, &CursorManager.move_to_column/4, 0)
        end).()
  end

  @doc "Handles Cursor Horizontal Absolute (CHA - 'G')"
  @spec handle_G(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_G(emulator, params) do
    column = get_valid_pos_param(params, 0, 1)

    handle_cursor_movement(
      emulator,
      &CursorManager.move_to_column/4,
      column - 1
    )
  end

  @doc "Handles Cursor Vertical Absolute (VPA - 'd')"
  @spec handle_d(Emulator.t(), list(integer() | nil)) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_d(emulator, params) do
    row = get_valid_pos_param(params, 0, 1)
    active_buffer = Emulator.get_active_buffer(emulator)
    height = ScreenBuffer.get_height(active_buffer)
    new_row = min(row - 1, height - 1)
    {current_col, _} = Raxol.Terminal.Emulator.get_cursor_position(emulator)
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

  # --- Parameter Validation Helpers ---

  @doc """
  Gets a parameter value with validation.
  Returns the parameter value if valid, or the default value if invalid.
  """
  @spec get_valid_param(
          list(integer() | nil),
          non_neg_integer(),
          integer(),
          integer(),
          integer()
        ) :: integer()
  defp get_valid_param(params, index, default, min, max) do
    case Enum.at(params, index, default) do
      value when is_integer(value) and value >= min and value <= max ->
        value

      _ ->
        Logger.warn(
          "Invalid parameter value at index #{index}, using default #{default}"
        )

        default
    end
  end

  @doc """
  Gets a parameter value with validation for non-negative integers.
  Returns the parameter value if valid, or the default value if invalid.
  """
  @spec get_valid_non_neg_param(
          list(integer() | nil),
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  defp get_valid_non_neg_param(params, index, default) do
    get_valid_param(params, index, default, 0, 9999)
  end

  @doc """
  Gets a parameter value with validation for positive integers.
  Returns the parameter value if valid, or the default value if invalid.
  """
  @spec get_valid_pos_param(
          list(integer() | nil),
          non_neg_integer(),
          pos_integer()
        ) :: pos_integer()
  defp get_valid_pos_param(params, index, default) do
    get_valid_param(params, index, default, 1, 9999)
  end
end
