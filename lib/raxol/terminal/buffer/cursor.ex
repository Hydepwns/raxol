defmodule Raxol.Terminal.Buffer.Cursor do
  @moduledoc """
  Manages cursor state and operations for the screen buffer.
  This module handles cursor position, visibility, style, and blink state.
  """

  alias Raxol.Terminal.ScreenBuffer

  @type t :: %__MODULE__{
          position: {non_neg_integer(), non_neg_integer()},
          visible: boolean(),
          style: atom(),
          blink_state: boolean()
        }

  defstruct [
    :position,
    :visible,
    :style,
    :blink_state
  ]

  @doc """
  Initializes a new cursor state with default values.
  """
  @spec init() :: t()
  def init do
    %__MODULE__{
      position: {0, 0},
      visible: true,
      style: :block,
      blink_state: true
    }
  end

  @doc """
  Sets the cursor position.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `x` - The x-coordinate (column)
  * `y` - The y-coordinate (row)

  ## Returns

  The updated screen buffer with new cursor position.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Cursor.set_position(buffer, 10, 5)
      iex> Cursor.get_position(buffer)
      {10, 5}
  """
  @spec set_position(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def set_position(buffer, x, y) do
    new_cursor = %{buffer.cursor | position: {x, y}}
    %{buffer | cursor: new_cursor}
  end

  @doc """
  Gets the current cursor position.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  A tuple {x, y} representing the cursor position.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Cursor.get_position(buffer)
      {0, 0}
  """
  @spec get_position(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()}
  def get_position(buffer) do
    buffer.cursor.position
  end

  @doc """
  Sets the cursor visibility.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `visible` - Whether the cursor should be visible

  ## Returns

  The updated screen buffer with new cursor visibility.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Cursor.set_visibility(buffer, false)
      iex> Cursor.visible?(buffer)
      false
  """
  @spec set_visibility(ScreenBuffer.t(), boolean()) :: ScreenBuffer.t()
  def set_visibility(buffer, visible) do
    new_cursor = %{buffer.cursor | visible: visible}
    %{buffer | cursor: new_cursor}
  end

  @doc """
  Checks if the cursor is visible.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  A boolean indicating cursor visibility.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Cursor.visible?(buffer)
      true
  """
  @spec visible?(ScreenBuffer.t()) :: boolean()
  def visible?(buffer) do
    buffer.cursor.visible
  end

  @doc """
  Checks if the cursor is visible.

  ## Parameters

  * `cursor` - The cursor to query

  ## Returns

  A boolean indicating cursor visibility.

  ## Examples

      iex> cursor = Cursor.init()
      iex> Cursor.visible?(cursor)
      true
  """
  @spec visible?(t()) :: boolean()
  def visible?(cursor) do
    cursor.visible
  end

  @doc """
  Sets the cursor style.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `style` - The cursor style (:block, :underline, :bar)

  ## Returns

  The updated screen buffer with new cursor style.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Cursor.set_style(buffer, :underline)
      iex> Cursor.get_style(buffer)
      :underline
  """
  @spec set_style(ScreenBuffer.t(), atom()) :: ScreenBuffer.t()
  def set_style(buffer, style) do
    new_cursor = %{buffer.cursor | style: style}
    %{buffer | cursor: new_cursor}
  end

  @doc """
  Gets the current cursor style.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  The current cursor style.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Cursor.get_style(buffer)
      :block
  """
  @spec get_style(ScreenBuffer.t()) :: atom()
  def get_style(buffer) do
    buffer.cursor.style
  end

  @doc """
  Sets the cursor blink state.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `blink` - Whether the cursor should blink

  ## Returns

  The updated screen buffer with new cursor blink state.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Cursor.set_blink(buffer, false)
      iex> Cursor.blinking?(buffer)
      false
  """
  @spec set_blink(ScreenBuffer.t(), boolean()) :: ScreenBuffer.t()
  def set_blink(buffer, blink) do
    new_cursor = %{buffer.cursor | blink_state: blink}
    %{buffer | cursor: new_cursor}
  end

  @doc """
  Checks if the cursor is blinking.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  A boolean indicating if the cursor is blinking.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Cursor.blinking?(buffer)
      true
  """
  @spec blinking?(ScreenBuffer.t()) :: boolean()
  def blinking?(buffer) do
    buffer.cursor.blink_state
  end

  @doc """
  Checks if the cursor is blinking.

  ## Parameters

  * `cursor` - The cursor to query

  ## Returns

  A boolean indicating if the cursor is blinking.

  ## Examples

      iex> cursor = Cursor.init()
      iex> Cursor.blinking?(cursor)
      true
  """
  @spec blinking?(t()) :: boolean()
  def blinking?(cursor) do
    cursor.blink_state
  end

  @doc """
  Moves the cursor up by the specified number of lines.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `lines` - Number of lines to move up

  ## Returns

  The updated screen buffer with new cursor position.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Cursor.move_up(buffer, 2)
      iex> Cursor.get_position(buffer)
      {0, 0}  # Cursor stays at top
  """
  @spec move_up(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def move_up(buffer, lines) do
    {x, y} = buffer.cursor.position
    new_y = max(0, y - lines)
    set_position(buffer, x, new_y)
  end

  @doc """
  Moves the cursor down by the specified number of lines.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `lines` - Number of lines to move down

  ## Returns

  The updated screen buffer with new cursor position.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Cursor.move_down(buffer, 2)
      iex> Cursor.get_position(buffer)
      {0, 2}
  """
  @spec move_down(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def move_down(buffer, lines) do
    {x, y} = buffer.cursor.position
    new_y = min(buffer.height - 1, y + lines)
    set_position(buffer, x, new_y)
  end

  @doc """
  Moves the cursor forward by the specified number of columns.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `columns` - Number of columns to move forward

  ## Returns

  The updated screen buffer with new cursor position.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Cursor.move_forward(buffer, 2)
      iex> Cursor.get_position(buffer)
      {2, 0}
  """
  @spec move_forward(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def move_forward(buffer, columns) do
    {x, y} = buffer.cursor.position
    new_x = min(buffer.width - 1, x + columns)
    set_position(buffer, new_x, y)
  end

  @doc """
  Moves the cursor backward by the specified number of columns.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `columns` - Number of columns to move backward

  ## Returns

  The updated screen buffer with new cursor position.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Cursor.move_backward(buffer, 2)
      iex> Cursor.get_position(buffer)
      {0, 0}  # Cursor stays at left edge
  """
  @spec move_backward(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def move_backward(buffer, columns) do
    {x, y} = buffer.cursor.position
    new_x = max(0, x - columns)
    set_position(buffer, new_x, y)
  end

  @doc """
  Moves the cursor to the specified position.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `position` - The target position as {x, y}

  ## Returns

  The updated screen buffer with new cursor position.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Cursor.move_to(buffer, {10, 5})
      iex> Cursor.get_position(buffer)
      {10, 5}
  """
  @spec move_to(ScreenBuffer.t(), {non_neg_integer(), non_neg_integer()}) ::
          ScreenBuffer.t()
  def move_to(buffer, {x, y}) do
    x = max(0, min(buffer.width - 1, x))
    y = max(0, min(buffer.height - 1, y))
    set_position(buffer, x, y)
  end

  @doc """
  Gets the cursor position as a tuple of {row, col}.

  ## Parameters

  * `cursor` - The cursor to query

  ## Returns

  A tuple {row, col} representing the cursor position.

  ## Examples

      iex> cursor = Cursor.init()
      iex> Cursor.get_cursor_position(cursor)
      {0, 0}
  """
  @spec get_cursor_position(t()) :: {non_neg_integer(), non_neg_integer()}
  def get_cursor_position(cursor) do
    cursor.position
  end

  @doc """
  Sets the cursor position.

  ## Parameters

  * `cursor` - The cursor to modify
  * `row` - The row position
  * `col` - The column position

  ## Returns

  The updated cursor with new position.

  ## Examples

      iex> cursor = Cursor.init()
      iex> cursor = Cursor.set_cursor_position(cursor, 5, 10)
      iex> Cursor.get_cursor_position(cursor)
      {5, 10}
  """
  @spec set_cursor_position(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_cursor_position(cursor, row, col) do
    %{cursor | position: {row, col}}
  end
end
