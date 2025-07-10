defmodule Raxol.Terminal.CursorHandlers do
  @moduledoc """
  Handles cursor movement and positioning operations for the terminal emulator.
  Extracted from the main emulator module for clarity and maintainability.
  """

  # Import/alias as needed for dependencies

  # Add missing functions
  defp pid?(pid) when is_pid(pid), do: true
  defp pid?(_), do: false

  @doc """
  Moves the cursor up by the specified number of lines.
  """
  @spec move_cursor_up(any(), non_neg_integer()) :: any()
  def move_cursor_up(emulator, count) do
    cursor = emulator.cursor

    if pid?(cursor) do
      GenServer.call(cursor, {:move_up, count})
    end

    emulator
  end

  @doc """
  Moves the cursor down by the specified number of lines.
  """
  @spec move_cursor_down(any(), non_neg_integer()) :: any()
  def move_cursor_down(emulator, count) do
    cursor = emulator.cursor

    if pid?(cursor) do
      GenServer.call(cursor, {:move_down, count})
    end

    emulator
  end

  @doc """
  Moves the cursor forward by the specified number of columns.
  """
  @spec move_cursor_forward(any(), non_neg_integer()) :: any()
  def move_cursor_forward(emulator, count) do
    cursor = emulator.cursor

    if pid?(cursor) do
      GenServer.call(cursor, {:move_forward, count})
    end

    emulator
  end

  @doc """
  Moves the cursor back by the specified number of columns.
  """
  @spec move_cursor_back(any(), non_neg_integer()) :: any()
  def move_cursor_back(emulator, count) do
    cursor = emulator.cursor

    if pid?(cursor) do
      GenServer.call(cursor, {:move_back, count})
    end

    emulator
  end

  @doc """
  Moves the cursor to a specific column on the current line.
  """
  @spec move_cursor_to_column(
          any(),
          non_neg_integer(),
          non_neg_integer() | nil,
          non_neg_integer() | nil
        ) :: any()
  def move_cursor_to_column(emulator, column, _width, _height) do
    {_current_x, current_y} =
      Raxol.Terminal.Emulator.get_cursor_position(emulator)

    Raxol.Terminal.Emulator.move_cursor_to(emulator, current_y, column)
  end

  @doc """
  Moves the cursor to the start of the current line.
  """
  @spec move_cursor_to_line_start(any()) :: any()
  def move_cursor_to_line_start(emulator) do
    {_current_x, current_y} =
      Raxol.Terminal.Emulator.get_cursor_position(emulator)

    Raxol.Terminal.Emulator.move_cursor_to(emulator, current_y, 0)
  end

  @doc """
  Moves the cursor up by the specified number of lines with width and height constraints.
  """
  @spec move_cursor_up(
          any(),
          non_neg_integer(),
          non_neg_integer() | nil,
          non_neg_integer() | nil
        ) :: any()
  def move_cursor_up(emulator, count, _width, _height) do
    move_cursor_up(emulator, count)
  end

  @doc """
  Moves the cursor down by the specified number of lines with width and height constraints.
  """
  @spec move_cursor_down(
          any(),
          non_neg_integer(),
          non_neg_integer() | nil,
          non_neg_integer() | nil
        ) :: any()
  def move_cursor_down(emulator, count, _width, _height) do
    move_cursor_down(emulator, count)
  end

  @doc """
  Moves the cursor left by the specified number of columns with width and height constraints.
  """
  @spec move_cursor_left(
          any(),
          non_neg_integer(),
          non_neg_integer() | nil,
          non_neg_integer() | nil
        ) :: any()
  def move_cursor_left(emulator, count, _width, _height) do
    move_cursor_back(emulator, count)
  end

  @doc """
  Moves the cursor right by the specified number of columns with width and height constraints.
  """
  @spec move_cursor_right(
          any(),
          non_neg_integer(),
          non_neg_integer() | nil,
          non_neg_integer() | nil
        ) :: any()
  def move_cursor_right(emulator, count, _width, _height) do
    move_cursor_forward(emulator, count)
  end

  @doc """
  Moves the cursor to the specified position with width and height constraints.
  """
  @spec move_cursor_to(any(), non_neg_integer(), non_neg_integer()) :: any()
  def move_cursor_to(emulator, x, y) do
    Raxol.Terminal.Emulator.move_cursor_to(emulator, x, y)
  end
end
