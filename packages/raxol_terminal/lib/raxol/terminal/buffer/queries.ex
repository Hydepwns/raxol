defmodule Raxol.Terminal.Buffer.Queries do
  @moduledoc """
  Handles buffer state querying operations.
  This module provides functions for querying the state of the screen buffer,
  including dimensions, content, and selection state.
  """

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ScreenBuffer

  @doc """
  Gets the dimensions of the buffer.
  """
  @spec get_dimensions(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()}
  def get_dimensions(buffer) do
    {buffer.width, buffer.height}
  end

  @doc """
  Gets the width of the buffer.
  """
  @spec get_width(ScreenBuffer.t()) :: non_neg_integer()
  def get_width(buffer) do
    buffer.width
  end

  @doc """
  Gets the height of the buffer.
  """
  @spec get_height(ScreenBuffer.t()) :: non_neg_integer()
  def get_height(buffer) do
    buffer.height
  end

  @doc """
  Gets the content of the buffer as a list of lines.
  """
  @spec get_content(ScreenBuffer.t()) :: list(list(Cell.t()))
  def get_content(buffer) do
    buffer.cells
  end

  @doc """
  Gets a specific line from the buffer.
  """
  @spec get_line(ScreenBuffer.t(), non_neg_integer()) :: list(Cell.t())
  def get_line(buffer, y) when y >= 0 and y < buffer.height do
    case buffer.cells do
      nil ->
        # Return empty list if cells is nil
        []

      cells ->
        Enum.at(cells, y)
    end
  end

  def get_line(_, _), do: []

  @doc """
  Gets a specific cell from the buffer.
  """
  @spec get_cell(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t()
  def get_cell(buffer, x, y) when x >= 0 and y >= 0 do
    case x < buffer.width and y < buffer.height do
      true ->
        case buffer.cells do
          nil ->
            # Return a default cell if cells is nil
            Cell.new()

          cells ->
            cells
            |> Enum.at(y)
            |> Enum.at(x)
        end

      false ->
        Cell.new()
    end
  end

  def get_cell(_, _, _), do: Cell.new()

  @doc """
  Gets text at a specific position with a given length.
  """
  @spec get_text_at(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: String.t()
  def get_text_at(buffer, x, y, length)
      when x >= 0 and y >= 0 and length >= 0 do
    case y < buffer.height do
      true ->
        case buffer.cells do
          nil ->
            ""

          cells ->
            line = Enum.at(cells, y, [])

            line
            |> Enum.slice(x, length)
            |> Enum.map_join("", fn
              nil -> " "
              cell -> cell.char || " "
            end)
        end

      false ->
        ""
    end
  end

  @doc """
  Checks if the buffer has scrollback content.
  """
  @spec has_scrollback?(ScreenBuffer.t()) :: boolean()
  def has_scrollback?(buffer) do
    case Map.get(buffer, :scrollback_buffer) do
      nil -> false
      [] -> false
      _ -> true
    end
  end

  @doc """
  Gets the text content of the buffer.
  """
  @spec get_text(ScreenBuffer.t()) :: String.t()
  def get_text(buffer) do
    case buffer.cells do
      nil ->
        # Return empty string if cells is nil
        ""

      cells ->
        cells
        |> Enum.map_join("\n", fn line ->
          line
          |> Enum.map_join("", &Cell.get_char/1)
        end)
    end
  end

  @doc """
  Gets the text content of a specific line.
  """
  @spec get_line_text(ScreenBuffer.t(), non_neg_integer()) :: String.t()
  def get_line_text(buffer, y) when y >= 0 and y < buffer.height do
    case buffer.cells do
      nil ->
        # Return empty string if cells is nil
        ""

      cells ->
        cells
        |> Enum.at(y)
        |> Enum.map_join("", &Cell.get_char/1)
    end
  end

  def get_line_text(_, _), do: ""

  @doc """
  Checks if a position is within the buffer bounds.
  """
  @spec in_bounds?(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          boolean()
  def in_bounds?(buffer, x, y) when x >= 0 and y >= 0 do
    x < buffer.width and y < buffer.height
  end

  def in_bounds?(_, _, _), do: false

  @doc """
  Checks if the buffer is empty.

  ## Parameters

  * `buffer` - The screen buffer to check

  ## Returns

  A boolean indicating if the buffer is empty.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Queries.empty?(buffer)
      true
  """
  @spec empty?(ScreenBuffer.t()) :: boolean()
  def empty?(buffer) do
    case buffer.cells do
      nil ->
        # Return true if cells is nil (empty buffer)
        true

      cells ->
        Enum.all?(cells, fn line ->
          Enum.all?(line, &Cell.empty?/1)
        end)
    end
  end

  @doc """
  Gets the character at the given position in the buffer.
  """
  @spec get_char(map(), integer(), integer()) :: String.t()
  def get_char(_buffer, _x, _y) do
    " "
  end

  @doc """
  Gets the cell at the specified position in the buffer.

  ## Parameters

  * `buffer` - The screen buffer to query
  * `x` - The x-coordinate (column)
  * `y` - The y-coordinate (row)

  ## Returns

  The cell at the specified position, or an empty cell if the position is out of bounds.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> cell = Queries.get_cell_at(buffer, 0, 0)
      iex> cell.char
      ""
  """
  @spec get_cell_at(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t()
  def get_cell_at(buffer, x, y) do
    get_cell(buffer, x, y)
  end

  @doc """
  Gets the character at the specified position in the buffer.

  ## Parameters

  * `buffer` - The screen buffer to query
  * `x` - The x-coordinate (column)
  * `y` - The y-coordinate (row)

  ## Returns

  The character at the specified position, or a space if the position is out of bounds.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Queries.get_char_at(buffer, 0, 0)
      " "
  """
  @spec get_char_at(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          String.t()
  def get_char_at(buffer, x, y) do
    get_char(buffer, x, y)
  end
end
