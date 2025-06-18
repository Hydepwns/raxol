defmodule Raxol.Terminal.Buffer do
  @moduledoc """
  Manages the terminal buffer state and operations.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.{Cell, TextFormatting, Operations}

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          cells: list(list(Cell.t())),
          cursor_x: non_neg_integer(),
          cursor_y: non_neg_integer(),
          scroll_region_top: non_neg_integer(),
          scroll_region_bottom: non_neg_integer(),
          damage_regions:
            list(
              {non_neg_integer(), non_neg_integer(), non_neg_integer(),
               non_neg_integer()}
            )
        }

  defstruct [
    :width,
    :height,
    :cells,
    :cursor_x,
    :cursor_y,
    :scroll_region_top,
    :scroll_region_bottom,
    :damage_regions
  ]

  @doc """
  Creates a new buffer with the specified dimensions.
  Raises ArgumentError if dimensions are invalid.
  """
  @spec new({non_neg_integer(), non_neg_integer()}) :: t()
  def new({width, height})
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    %__MODULE__{
      width: width,
      height: height,
      cells: create_empty_grid(width, height),
      cursor_x: 0,
      cursor_y: 0,
      scroll_region_top: 0,
      scroll_region_bottom: height - 1,
      damage_regions: []
    }
  end

  def new({width, height}) when is_integer(width) and is_integer(height) do
    raise ArgumentError,
          "Invalid buffer dimensions: width and height must be positive integers"
  end

  def new(invalid) do
    raise ArgumentError,
          "Invalid buffer dimensions: expected {width, height} tuple, got #{inspect(invalid)}"
  end

  @doc """
  Sets a cell in the buffer at the specified coordinates.
  Raises ArgumentError if coordinates or cell data are invalid.
  """
  @spec set_cell(t(), non_neg_integer(), non_neg_integer(), Cell.t()) :: t()
  def set_cell(buffer, x, y, cell)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 and
             x < buffer.width and y < buffer.height do
    if not Cell.valid?(cell) do
      raise ArgumentError, "Invalid cell data: #{inspect(cell)}"
    end

    new_cells =
      List.update_at(buffer.cells, y, fn row ->
        List.update_at(row, x, fn _ -> cell end)
      end)

    %{buffer | cells: new_cells}
  end

  def set_cell(buffer, x, y, _cell) when is_integer(x) and is_integer(y) do
    raise ArgumentError,
          "Coordinates out of bounds: (#{x}, #{y}) for buffer size #{buffer.width}x#{buffer.height}"
  end

  def set_cell(_buffer, x, y, _cell) do
    raise ArgumentError,
          "Invalid coordinates: expected non-negative integers, got (#{inspect(x)}, #{inspect(y)})"
  end

  @doc """
  Writes data to the buffer at the current cursor position.
  """
  @spec write(t(), String.t(), keyword()) :: t()
  def write(buffer, data, _opts \\ []) do
    screen_buffer = to_screen_buffer(buffer)

    updated_screen_buffer =
      Operations.write_string(
        screen_buffer,
        buffer.cursor_x,
        buffer.cursor_y,
        data
      )

    from_screen_buffer(updated_screen_buffer, buffer)
  end

  @doc """
  Reads data from the buffer.
  """
  @spec read(t(), keyword()) :: {String.t(), t()}
  def read(buffer, _opts \\ []) do
    screen_buffer = to_screen_buffer(buffer)
    {Operations.get_content(screen_buffer), buffer}
  end

  @doc """
  Clears the buffer.
  """
  @spec clear(t(), keyword()) :: t()
  def clear(buffer, _opts \\ []) do
    screen_buffer = to_screen_buffer(buffer)

    updated_screen_buffer =
      Raxol.Terminal.Buffer.Eraser.clear_screen(screen_buffer)

    from_screen_buffer(updated_screen_buffer, buffer)
  end

  @doc """
  Sets the cursor position.
  """
  @spec set_cursor_position(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_cursor_position(buffer, x, y) do
    screen_buffer = to_screen_buffer(buffer)

    updated_screen_buffer =
      Raxol.Terminal.Buffer.Eraser.set_cursor_position(screen_buffer, x, y)

    from_screen_buffer(updated_screen_buffer, buffer)
  end

  @doc """
  Gets the current cursor position.
  """
  @spec get_cursor_position(t()) :: {non_neg_integer(), non_neg_integer()}
  def get_cursor_position(buffer) do
    screen_buffer = to_screen_buffer(buffer)
    Raxol.Terminal.Buffer.Eraser.get_cursor_position(screen_buffer)
  end

  @doc """
  Sets the scroll region.
  """
  @spec set_scroll_region(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_scroll_region(buffer, top, bottom) do
    screen_buffer = to_screen_buffer(buffer)

    updated_screen_buffer =
      Raxol.Terminal.Buffer.Eraser.set_scroll_region(screen_buffer, top, bottom)

    from_screen_buffer(updated_screen_buffer, buffer)
  end

  @doc """
  Scrolls the buffer by the specified number of lines.
  """
  @spec scroll(t(), integer()) :: t()
  def scroll(buffer, lines) do
    screen_buffer = to_screen_buffer(buffer)
    {updated_screen_buffer, _} = Operations.scroll_up(screen_buffer, abs(lines))
    from_screen_buffer(updated_screen_buffer, buffer)
  end

  @doc """
  Marks a region of the buffer as damaged.
  """
  @spec mark_damaged(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: t()
  def mark_damaged(buffer, x, y, width, height) do
    screen_buffer = to_screen_buffer(buffer)

    updated_screen_buffer =
      Raxol.Terminal.Buffer.Eraser.mark_damaged(
        screen_buffer,
        x,
        y,
        width,
        height
      )

    from_screen_buffer(updated_screen_buffer, buffer)
  end

  @doc """
  Gets all damaged regions in the buffer.
  """
  @spec get_damage_regions(t()) :: [
          {non_neg_integer(), non_neg_integer(), non_neg_integer(),
           non_neg_integer()}
        ]
  def get_damage_regions(buffer) do
    screen_buffer = to_screen_buffer(buffer)
    Raxol.Terminal.Buffer.Eraser.get_damage_regions(screen_buffer)
  end

  @doc """
  Adds content to the buffer at the current cursor position.

  ## Examples

      iex> buffer = Buffer.new({80, 24})
      iex> buffer = Buffer.add(buffer, "Hello, World!")
      iex> {content, _} = Buffer.read(buffer)
      iex> content
      "Hello, World!"
  """
  @spec add(t(), String.t()) :: t()
  def add(buffer, content) do
    write(buffer, content)
  end

  # Private functions

  defp create_empty_grid(width, height) do
    for _y <- 0..(height - 1) do
      for _x <- 0..(width - 1) do
        Cell.new(" ", TextFormatting.new())
      end
    end
  end

  defp to_screen_buffer(buffer) do
    %ScreenBuffer{
      width: buffer.width,
      height: buffer.height,
      cells: buffer.cells,
      scroll_region: {buffer.scroll_region_top, buffer.scroll_region_bottom},
      cursor_position: {buffer.cursor_x, buffer.cursor_y},
      damage_regions: buffer.damage_regions
    }
  end

  defp from_screen_buffer(screen_buffer, original_buffer) do
    {cursor_x, cursor_y} = screen_buffer.cursor_position

    %{
      original_buffer
      | cells: screen_buffer.cells,
        cursor_x: cursor_x,
        cursor_y: cursor_y,
        scroll_region_top: elem(screen_buffer.scroll_region, 0),
        scroll_region_bottom: elem(screen_buffer.scroll_region, 1),
        damage_regions: screen_buffer.damage_regions
    }
  end
end
