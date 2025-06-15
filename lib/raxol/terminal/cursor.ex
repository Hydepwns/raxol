defmodule Raxol.Terminal.Cursor do
  @moduledoc """
  Provides cursor manipulation functions for the terminal emulator.
  This module handles operations like moving the cursor, setting its visibility,
  and managing cursor state.
  """

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  defstruct [:position, :shape, :visible]

  @type t :: %__MODULE__{
          position: {non_neg_integer(), non_neg_integer()},
          shape: atom(),
          visible: boolean()
        }

  @doc """
  Moves the cursor up by the specified number of lines.
  """
  @spec move_up(EmulatorStruct.t(), non_neg_integer()) :: EmulatorStruct.t()
  def move_up(emulator, lines) do
    {x, y} = emulator.cursor.position
    new_y = max(0, y - lines)
    %{emulator | cursor: %{emulator.cursor | position: {x, new_y}}}
  end

  @doc """
  Moves the cursor down by the specified number of lines.
  """
  @spec move_down(EmulatorStruct.t(), non_neg_integer()) :: EmulatorStruct.t()
  def move_down(emulator, lines) do
    {x, y} = emulator.cursor.position
    new_y = min(emulator.height - 1, y + lines)
    %{emulator | cursor: %{emulator.cursor | position: {x, new_y}}}
  end

  @doc """
  Moves the cursor right by the specified number of columns.
  """
  @spec move_right(EmulatorStruct.t(), non_neg_integer()) :: EmulatorStruct.t()
  def move_right(emulator, cols) do
    {x, y} = emulator.cursor.position
    new_x = min(emulator.width - 1, x + cols)
    %{emulator | cursor: %{emulator.cursor | position: {new_x, y}}}
  end

  @doc """
  Moves the cursor left by the specified number of columns.
  """
  @spec move_left(EmulatorStruct.t(), non_neg_integer()) :: EmulatorStruct.t()
  def move_left(emulator, cols) do
    {x, y} = emulator.cursor.position
    new_x = max(0, x - cols)
    %{emulator | cursor: %{emulator.cursor | position: {new_x, y}}}
  end

  @doc """
  Moves the cursor down and to the beginning of the line.
  """
  @spec move_down_and_home(EmulatorStruct.t(), non_neg_integer()) ::
          EmulatorStruct.t()
  def move_down_and_home(emulator, lines) do
    emulator
    |> move_down(lines)
    |> move_to_column(0)
  end

  @doc """
  Moves the cursor up and to the beginning of the line.
  """
  @spec move_up_and_home(EmulatorStruct.t(), non_neg_integer()) ::
          EmulatorStruct.t()
  def move_up_and_home(emulator, lines) do
    emulator
    |> move_up(lines)
    |> move_to_column(0)
  end

  @doc """
  Moves the cursor to the specified column.
  """
  @spec move_to_column(EmulatorStruct.t(), non_neg_integer()) ::
          EmulatorStruct.t()
  def move_to_column(emulator, col) do
    {_, y} = emulator.cursor.position
    new_x = max(0, min(emulator.width - 1, col))
    %{emulator | cursor: %{emulator.cursor | position: {new_x, y}}}
  end

  @doc """
  Moves the cursor to the specified position.
  """
  @spec move_to(EmulatorStruct.t(), {non_neg_integer(), non_neg_integer()}) ::
          EmulatorStruct.t()
  def move_to(emulator, {row, col}) do
    new_x = max(0, min(emulator.width - 1, col))
    new_y = max(0, min(emulator.height - 1, row))
    %{emulator | cursor: %{emulator.cursor | position: {new_x, new_y}}}
  end

  @doc """
  Sets the cursor visibility.
  """
  @spec set_visible(EmulatorStruct.t(), boolean()) :: EmulatorStruct.t()
  def set_visible(emulator, visible) do
    %{emulator | cursor: %{emulator.cursor | visible: visible}}
  end

  @doc """
  Moves the cursor forward by the specified number of columns.
  """
  @spec move_forward(EmulatorStruct.t(), non_neg_integer()) ::
          EmulatorStruct.t()
  def move_forward(emulator, cols) do
    move_right(emulator, cols)
  end

  @doc """
  Moves the cursor backward by the specified number of columns.
  """
  @spec move_backward(EmulatorStruct.t(), non_neg_integer()) ::
          EmulatorStruct.t()
  def move_backward(emulator, cols) do
    move_left(emulator, cols)
  end

  @doc """
  Moves the cursor to the specified row and column.
  """
  @spec move_to(EmulatorStruct.t(), non_neg_integer(), non_neg_integer()) ::
          EmulatorStruct.t()
  def move_to(emulator, row, col) do
    move_to(emulator, {row, col})
  end

  @doc """
  Gets the current cursor position.
  """
  @spec get_position(EmulatorStruct.t()) ::
          {non_neg_integer(), non_neg_integer()}
  def get_position(emulator) do
    emulator.cursor.position
  end

  @doc """
  Sets the cursor shape.
  """
  @spec set_shape(EmulatorStruct.t(), non_neg_integer()) :: EmulatorStruct.t()
  def set_shape(emulator, shape) do
    %{emulator | cursor: %{emulator.cursor | shape: shape}}
  end

  @doc """
  Moves the cursor to the specified position, taking into account the screen width and height.
  """
  @spec move_to(
          t(),
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer(),
          non_neg_integer()
        ) :: t()
  def move_to(cursor, {x, y}, width, height) do
    x = max(0, min(x, width - 1))
    y = max(0, min(y, height - 1))
    %{cursor | position: {x, y}}
  end
end
