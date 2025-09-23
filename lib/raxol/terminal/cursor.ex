defmodule Raxol.Terminal.Cursor do
  @moduledoc """
  Provides cursor manipulation functions for the terminal emulator.
  This module handles operations like moving the cursor, setting its visibility,
  and managing cursor state.
  """

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  defstruct [:position, :shape, :visible, :saved_position]

  @type t :: %__MODULE__{
          position: {non_neg_integer(), non_neg_integer()},
          shape: atom(),
          visible: boolean(),
          saved_position: {non_neg_integer(), non_neg_integer()} | nil
        }

  @doc """
  Creates a new cursor with default settings.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      position: {0, 0},
      shape: :block,
      visible: true,
      saved_position: nil
    }
  end

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
  def move_to(%{cursor: nil} = emulator, {row, col}) do
    new_x = max(0, min(emulator.width - 1, col))
    new_y = max(0, min(emulator.height - 1, row))
    %{emulator | cursor: %{position: {new_x, new_y}, row: new_y, col: new_x}}
  end

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
  def move_to(%{cursor: nil} = emulator, row, col) do
    move_to(emulator, {row, col})
  end

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

  # === Additional Cursor Functions ===

  @doc """
  Checks if the cursor is visible.
  """
  @spec visible?(EmulatorStruct.t()) :: boolean()
  def visible?(emulator) do
    emulator.cursor.visible
  end

  @doc """
  Sets the cursor visibility.
  """
  @spec set_visibility(EmulatorStruct.t(), boolean()) :: EmulatorStruct.t()
  def set_visibility(emulator, visible) do
    set_visible(emulator, visible)
  end

  @doc """
  Sets the cursor style.
  """
  @spec set_style(EmulatorStruct.t(), map()) :: EmulatorStruct.t()
  def set_style(emulator, style) do
    %{emulator | cursor: %{emulator.cursor | style: style}}
  end

  @doc """
  Sets the cursor position.
  """
  @spec set_position(EmulatorStruct.t(), {non_neg_integer(), non_neg_integer()}) ::
          EmulatorStruct.t()
  def set_position(%{cursor: nil} = emulator, {col, row}) do
    # Create a cursor if it doesn't exist
    new_x = max(0, min(emulator.width - 1, col))
    new_y = max(0, min(emulator.height - 1, row))
    %{emulator | cursor: %{position: {new_x, new_y}, row: new_y, col: new_x}}
  end

  def set_position(emulator, position) do
    move_to(emulator, position)
  end

  @doc """
  Sets the cursor color.
  """
  @spec set_color(EmulatorStruct.t(), map()) :: EmulatorStruct.t()
  def set_color(emulator, color) do
    %{emulator | cursor: %{emulator.cursor | color: color}}
  end

  @doc """
  Sets the cursor blink state.
  """
  @spec set_blink(EmulatorStruct.t(), boolean()) :: EmulatorStruct.t()
  def set_blink(emulator, blink) do
    %{emulator | cursor: %{emulator.cursor | blink: blink}}
  end

  @doc """
  Resets the cursor color to default.
  """
  @spec reset_color(EmulatorStruct.t()) :: EmulatorStruct.t()
  def reset_color(emulator) do
    %{emulator | cursor: %{emulator.cursor | color: nil}}
  end

  @doc """
  Gets the cursor style.
  """
  @spec get_style(EmulatorStruct.t()) :: map()
  def get_style(emulator) do
    emulator.cursor.style || %{}
  end

  @doc """
  Moves the cursor relative to its current position.
  """
  @spec move_relative(t(), integer(), integer()) :: t()
  def move_relative(%__MODULE__{position: {x, y}} = cursor, dx, dy) do
    new_x = max(0, x + dx)
    new_y = max(0, y + dy)
    %{cursor | position: {new_x, new_y}}
  end

  @doc """
  Saves the current cursor position.
  """
  @spec save(t()) :: t()
  def save(%__MODULE__{position: position} = cursor) do
    %{cursor | saved_position: position}
  end

  @doc """
  Restores the cursor to a previously saved position.
  """
  @spec restore(t(), t()) :: t()
  def restore(cursor, saved_cursor) do
    case saved_cursor.saved_position do
      nil -> cursor
      position -> %{cursor | position: position}
    end
  end
end
