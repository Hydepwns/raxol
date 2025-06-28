defmodule Raxol.Terminal.Buffer.Content do
  @moduledoc """
  Handles content operations for the screen buffer.
  This module provides functions for writing and reading content from the buffer,
  including character and string operations.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Writes a character at the specified position with optional styling.
  """
  @spec write_char(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def write_char(buffer, x, y, char, style \\ nil) when x >= 0 and y >= 0 do
    if x < buffer.width and y < buffer.height do
      cell = Cell.new(char, style)
      %{buffer | cells: put_in(buffer.cells, [y, x], cell)}
    else
      buffer
    end
  end

  @doc """
  Writes a string starting at the specified position.
  """
  @spec write_string(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def write_string(buffer, x, y, string, style \\ nil) when x >= 0 and y >= 0 do
    string
    |> String.graphemes()
    |> Enum.reduce({buffer, x}, fn char, {buffer, x} ->
      if x < buffer.width do
        {write_char(buffer, x, y, char, style), x + 1}
      else
        {buffer, x}
      end
    end)
    |> elem(0)
  end

  @doc """
  Gets a character at the specified position.
  """
  @spec get_char(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          String.t()
  def get_char(buffer, x, y) when x >= 0 and y >= 0 do
    if x < buffer.width and y < buffer.height do
      buffer.cells
      |> Enum.at(y)
      |> Enum.at(x)
      |> Cell.get_char()
    else
      ""
    end
  end

  @doc """
  Gets a cell at the specified position.
  """
  @spec get_cell(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t()
  def get_cell(buffer, x, y) when x >= 0 and y >= 0 do
    if x < buffer.width and y < buffer.height do
      buffer.cells
      |> Enum.at(y)
      |> Enum.at(x)
    else
      Cell.new()
    end
  end

  @doc """
  Gets the entire buffer content as a string.
  """
  @spec get_content(ScreenBuffer.t()) :: String.t()
  def get_content(%ScreenBuffer{cells: cells}) do
    cells
    |> Enum.map(fn row ->
      row
      |> Enum.map_join("", & &1.char)
      |> String.trim_trailing()
    end)
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end

  @doc """
  Gets a line of cells from the buffer.
  """
  @spec get_line(ScreenBuffer.t(), non_neg_integer()) :: list(Cell.t())
  def get_line(%ScreenBuffer{cells: cells}, line_index) when line_index >= 0 do
    Enum.at(cells, line_index, [])
  end

  @doc """
  Updates a line in the buffer with new cells.
  """
  @spec put_line(ScreenBuffer.t(), non_neg_integer(), list(Cell.t())) ::
          ScreenBuffer.t()
  def put_line(%ScreenBuffer{cells: cells} = buffer, line_index, new_cells)
      when line_index >= 0 and line_index < length(cells) do
    new_cells = List.duplicate(new_cells, 1)
    new_cells_list = List.replace_at(cells, line_index, new_cells)
    %{buffer | cells: new_cells_list}
  end

  @doc """
  Calculates the difference between the current buffer state and a list of changes.
  """
  @spec diff(
          ScreenBuffer.t(),
          list({non_neg_integer(), non_neg_integer(), map()})
        ) ::
          list({non_neg_integer(), non_neg_integer(), map()})
  def diff(%ScreenBuffer{cells: cells}, changes) do
    Enum.filter(changes, fn {y, x, _} ->
      case get_in(cells, [y, x]) do
        nil -> false
        cell -> cell != %Cell{}
      end
    end)
  end

  @doc """
  Updates the buffer with a list of changes.
  """
  @spec update(
          ScreenBuffer.t(),
          list({non_neg_integer(), non_neg_integer(), Cell.t() | map()})
        ) :: ScreenBuffer.t()
  def update(%ScreenBuffer{cells: cells} = buffer, changes) do
    new_cells =
      Enum.reduce(changes, cells, fn {y, x, cell_or_map}, acc_cells ->
        cell =
          if is_map(cell_or_map),
            do: struct(Cell, cell_or_map),
            else: cell_or_map

        put_in(acc_cells, [y, x], cell)
      end)

    %{buffer | cells: new_cells}
  end
end
