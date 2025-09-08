defmodule Raxol.Terminal.Emulator.CursorOperations do
  @moduledoc """
  Cursor operation functions extracted from the main emulator module.
  Handles cursor movement, positioning, and blink operations.
  """

  alias Raxol.Terminal.Emulator

  @type emulator :: Emulator.t()

  @doc """
  Moves the cursor forward by the specified count.
  """
  @spec move_cursor_forward(emulator(), non_neg_integer()) :: emulator()
  def move_cursor_forward(emulator, count) do
    cursor = emulator.cursor
    call_cursor_if_pid(is_pid(cursor), cursor, {:move_forward, count})
    emulator
  end

  @doc """
  Moves the cursor back by the specified count.
  """
  @spec move_cursor_back(emulator(), non_neg_integer()) :: emulator()
  def move_cursor_back(emulator, count) do
    cursor = emulator.cursor
    call_cursor_if_pid(is_pid(cursor), cursor, {:move_back, count})
    emulator
  end

  @doc """
  Moves the cursor down by the specified count.
  """
  @spec move_cursor_down(emulator(), non_neg_integer()) :: emulator()
  def move_cursor_down(emulator, count, _width, _height) do
    move_cursor_down(emulator, count)
  end

  @spec move_cursor_down(emulator(), non_neg_integer()) :: emulator()
  def move_cursor_down(emulator, count) do
    cursor = emulator.cursor
    call_cursor_if_pid(is_pid(cursor), cursor, {:move_down, count})
    emulator
  end

  @doc """
  Moves the cursor up by the specified count.
  """
  @spec move_cursor_up(emulator(), non_neg_integer()) :: emulator()
  def move_cursor_up(emulator, count, _width, _height) do
    move_cursor_up(emulator, count)
  end

  @spec move_cursor_up(emulator(), non_neg_integer()) :: emulator()
  def move_cursor_up(emulator, count) do
    cursor = emulator.cursor
    call_cursor_if_pid(is_pid(cursor), cursor, {:move_up, count})
    emulator
  end

  @doc """
  Moves the cursor left by the specified count.
  """
  @spec move_cursor_left(
          emulator(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: emulator()
  def move_cursor_left(emulator, count, _width, _height) do
    move_cursor_back(emulator, count)
  end

  @doc """
  Moves the cursor right by the specified count.
  """
  @spec move_cursor_right(
          emulator(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: emulator()
  def move_cursor_right(emulator, count, _width, _height) do
    move_cursor_forward(emulator, count)
  end

  @doc """
  Moves the cursor to the specified column.
  """
  @spec move_cursor_to_column(
          emulator(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: emulator()
  def move_cursor_to_column(emulator, column, _width, _height) do
    {_current_x, current_y} =
      Raxol.Terminal.Emulator.Helpers.get_cursor_position(emulator)

    Raxol.Terminal.Commands.CursorHandler.move_cursor_to(
      emulator,
      current_y,
      column
    )
  end

  @doc """
  Moves the cursor to the start of the current line.
  """
  @spec move_cursor_to_line_start(emulator()) :: emulator()
  def move_cursor_to_line_start(emulator) do
    {_current_x, current_y} =
      Raxol.Terminal.Emulator.Helpers.get_cursor_position(emulator)

    Raxol.Terminal.Commands.CursorHandler.move_cursor_to(
      emulator,
      current_y,
      0
    )
  end

  @doc """
  Moves the cursor to the specified position.
  """
  @spec move_cursor_to(emulator(), non_neg_integer(), non_neg_integer()) ::
          emulator()
  def move_cursor_to(emulator, x, y) do
    Raxol.Terminal.Commands.CursorHandler.move_cursor_to(emulator, x, y)
  end

  @doc """
  Moves the cursor to the specified position (2-arity version).
  """
  @spec move_cursor_to(emulator(), {non_neg_integer(), non_neg_integer()}) ::
          emulator()
  def move_cursor_to(emulator, {x, y}) do
    move_cursor_to(emulator, x, y)
  end

  @doc """
  Moves the cursor to the specified position (alias for move_cursor_to).
  """
  @spec move_cursor(emulator(), non_neg_integer(), non_neg_integer()) ::
          emulator()
  def move_cursor(emulator, x, y) do
    Raxol.Terminal.Commands.CursorHandler.move_cursor_to(emulator, x, y)
  end

  @doc """
  Sets the blink rate for the cursor.
  """
  @spec set_blink_rate(emulator(), non_neg_integer()) :: emulator()
  def set_blink_rate(emulator, rate) do
    cursor = emulator.cursor
    set_cursor_blink_if_pid(is_pid(cursor), cursor, rate)
    # Store blink rate in emulator state for reference
    %{emulator | cursor_blink_rate: rate}
  end

  # Helper functions for pattern matching refactoring

  defp call_cursor_if_pid(true, cursor, message) do
    GenServer.call(cursor, message)
  end

  defp call_cursor_if_pid(false, _cursor, _message), do: nil

  defp set_cursor_blink_if_pid(true, cursor, rate) do
    # Set blink rate in cursor manager
    GenServer.call(cursor, {:set_blink_rate, rate})

    # Also set blink state based on rate
    blinking = rate > 0
    GenServer.call(cursor, {:set_blink, blinking})
  end

  defp set_cursor_blink_if_pid(false, _cursor, _rate), do: nil
end
