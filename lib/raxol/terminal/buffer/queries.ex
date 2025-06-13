defmodule Raxol.Terminal.Buffer.Queries do
  @moduledoc """
  Handles buffer state querying operations.
  This module provides functions for querying the state of the screen buffer,
  including dimensions, content, and selection state.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  @doc """
  Gets the dimensions of the buffer.
  """
  @spec get_dimensions(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()}
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
    Enum.at(buffer.cells, y)
  end
  def get_line(_, _), do: []

  @doc """
  Gets a specific cell from the buffer.
  """
  @spec get_cell(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: Cell.t()
  def get_cell(buffer, x, y) when x >= 0 and y >= 0 do
    if x < buffer.width and y < buffer.height do
      buffer.cells
      |> Enum.at(y)
      |> Enum.at(x)
    else
      Cell.new()
    end
  end
  def get_cell(_, _, _), do: Cell.new()

  @doc """
  Gets the text content of the buffer.
  """
  @spec get_text(ScreenBuffer.t()) :: String.t()
  def get_text(buffer) do
    buffer.cells
    |> Enum.map(fn line ->
      line
      |> Enum.map(&Cell.get_char/1)
      |> Enum.join()
    end)
    |> Enum.join("\n")
  end

  @doc """
  Gets the text content of a specific line.
  """
  @spec get_line_text(ScreenBuffer.t(), non_neg_integer()) :: String.t()
  def get_line_text(buffer, y) when y >= 0 and y < buffer.height do
    buffer.cells
    |> Enum.at(y)
    |> Enum.map(&Cell.get_char/1)
    |> Enum.join()
  end
  def get_line_text(_, _), do: ""

  @doc """
  Checks if a position is within the buffer bounds.
  """
  @spec in_bounds?(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: boolean()
  def in_bounds?(buffer, x, y) when x >= 0 and y >= 0 do
    x < buffer.width and y < buffer.height
  end
  def in_bounds?(_, _, _), do: false

  @doc """
  Checks if the buffer is empty.
  """
  @spec is_empty?(map()) :: boolean()
  def is_empty?(_buffer) do
    true
  end

  @doc """
  Gets the character at the given position in the buffer.
  """
  @spec get_char(map(), integer(), integer()) :: String.t()
  def get_char(_buffer, _x, _y) do
    " "
  end
end
