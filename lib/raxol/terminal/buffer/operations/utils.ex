defmodule Raxol.Terminal.Buffer.Operations.Utils do
  @moduledoc """
  Utility operations for terminal buffers including buffer creation, resizing, and cell operations.
  """

  alias Raxol.Terminal.Buffer.Cell

  @doc """
  Resizes the buffer to the specified dimensions.
  """
  def resize(buffer, rows, cols)
      when is_list(buffer) and is_integer(rows) and is_integer(cols) do
    rows = max(1, rows)
    cols = max(1, cols)
    copy_and_resize_rows(buffer, rows, cols)
  end

  defp copy_and_resize_rows(buffer, rows, cols) do
    buffer
    |> Enum.take(rows)
    |> Enum.map(fn row ->
      row
      |> Enum.take(cols)
      |> Enum.concat(List.duplicate(Cell.new(), max(0, cols - length(row))))
    end)
    |> Enum.concat(
      List.duplicate(
        List.duplicate(Cell.new(), cols),
        max(0, rows - length(buffer))
      )
    )
  end

  @doc """
  Creates a new buffer with the specified dimensions.
  """
  def new(opts) do
    rows = Keyword.get(opts, :rows, 24)
    cols = Keyword.get(opts, :cols, 80)

    for _ <- 1..rows do
      for _ <- 1..cols do
        Cell.new()
      end
    end
  end

  @doc """
  Reads data from the buffer.
  """
  def read(buffer, opts \\ [])

  def read(%Raxol.Terminal.Buffer.Manager.BufferImpl{} = buffer, opts) do
    # Handle BufferImpl structs
    case Keyword.get(opts, :line) do
      nil ->
        {Raxol.Terminal.Buffer.Manager.BufferImpl.get_content(buffer), buffer}

      line when is_integer(line) ->
        {Raxol.Terminal.Buffer.Manager.BufferImpl.get_line(buffer, line),
         buffer}
    end
  end

  def read(buffer, opts) do
    # Handle ScreenBuffer and other buffer types
    case Keyword.get(opts, :line) do
      nil ->
        {Raxol.Terminal.Buffer.Content.get_content(buffer), buffer}

      line when is_integer(line) ->
        {Raxol.Terminal.Buffer.Content.get_line(buffer, line), buffer}
    end
  end

  @doc """
  Gets the content of the buffer.
  """
  def get_content(buffer) do
    Raxol.Terminal.Buffer.Content.get_content(buffer)
  end

  @doc """
  Gets a cell from the buffer at the specified coordinates.

  ## Parameters

  * `buffer` - The screen buffer
  * `x` - The x coordinate (column)
  * `y` - The y coordinate (row)

  ## Returns

  The cell at the specified coordinates, or a default cell if out of bounds.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Operations.Utils.get_cell(buffer, 0, 0)
      %Cell{char: "", style: %{}}
  """
  @spec get_cell(
          Raxol.Terminal.ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          Cell.t()
  def get_cell(buffer, x, y)
      when is_list(buffer) and is_integer(x) and is_integer(y) do
    case get_in(buffer, [Access.at(y), Access.at(x)]) do
      nil -> Cell.new()
      cell -> cell
    end
  end

  @doc """
  Fills a region of the buffer with a specified cell.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `x` - The starting x coordinate
  * `y` - The starting y coordinate
  * `width` - The width of the region
  * `height` - The height of the region
  * `cell` - The cell to fill the region with

  ## Returns

  The modified buffer with the region filled.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> cell = %Cell{char: "X", style: %{bold: true}}
      iex> Operations.Utils.fill_region(buffer, 0, 0, 10, 5, cell)
      [%Cell{char: "X", style: %{bold: true}}, ...]
  """
  @spec fill_region(
          Raxol.Terminal.ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Cell.t()
        ) :: Raxol.Terminal.ScreenBuffer.t()
  def fill_region(buffer, x, y, width, height, cell) when is_list(buffer) do
    buffer
    |> Enum.with_index()
    |> Enum.map(fn {row, row_y} ->
      case row_y >= y and row_y < y + height do
        true -> fill_row_region(row, x, width, cell)
        false -> row
      end
    end)
  end

  defp fill_row_region(row, x, width, cell) do
    row
    |> Enum.with_index()
    |> Enum.map(fn {col_cell, col_x} ->
      case col_x >= x and col_x < x + width do
        true -> cell
        false -> col_cell
      end
    end)
  end
end
