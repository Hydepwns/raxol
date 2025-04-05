defmodule Raxol.Terminal.ScreenBuffer do
  @moduledoc """
  Terminal screen buffer module.
  
  This module manages the terminal screen buffer, including:
  - Buffer initialization and resizing
  - Character cell operations
  - Selection handling
  - Scrolling
  """

  alias Raxol.Terminal.Cell

  @type t :: %__MODULE__{
    width: non_neg_integer(),
    height: non_neg_integer(),
    cells: list(list(Cell.t())),
    scrollback: list(list(Cell.t())),
    scrollback_limit: non_neg_integer(),
    selection: {integer(), integer()} | nil
  }

  defstruct [
    :width,
    :height,
    :cells,
    :scrollback,
    :scrollback_limit,
    :selection
  ]

  @doc """
  Creates a new screen buffer with the given dimensions.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScreenBuffer.width(buffer)
      80
      iex> ScreenBuffer.height(buffer)
      24
  """
  def new(width, height, scrollback_limit \\ 1000) do
    %__MODULE__{
      width: width,
      height: height,
      cells: initialize_cells(width, height),
      scrollback: [],
      scrollback_limit: scrollback_limit,
      selection: nil
    }
  end

  @doc """
  Gets the width of the screen buffer.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScreenBuffer.width(buffer)
      80
  """
  def width(%__MODULE__{} = buffer) do
    buffer.width
  end

  @doc """
  Gets the height of the screen buffer.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScreenBuffer.height(buffer)
      24
  """
  def height(%__MODULE__{} = buffer) do
    buffer.height
  end

  @doc """
  Resizes the screen buffer to the given dimensions.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.resize(buffer, 100, 30)
      iex> ScreenBuffer.width(buffer)
      100
      iex> ScreenBuffer.height(buffer)
      30
  """
  def resize(%__MODULE__{} = buffer, width, height) do
    new_cells = initialize_cells(width, height)
    
    # Copy existing content
    new_cells = Enum.with_index(new_cells)
    |> Enum.map(fn {row, y} ->
      Enum.with_index(row)
      |> Enum.map(fn {cell, x} ->
        if y < buffer.height and x < buffer.width do
          get_cell(buffer, x, y)
        else
          cell
        end
      end)
    end)

    %{buffer | 
      width: width,
      height: height,
      cells: new_cells
    }
  end

  @doc """
  Gets a cell at the given coordinates.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> cell = ScreenBuffer.get_cell(buffer, 0, 0)
      iex> Cell.is_empty?(cell)
      true
  """
  def get_cell(%__MODULE__{} = buffer, x, y) when x >= 0 and y >= 0 do
    if y < buffer.height and x < buffer.width do
      Enum.at(buffer.cells, y)
      |> Enum.at(x)
    else
      Cell.new()
    end
  end

  @doc """
  Sets a cell at the given coordinates.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> cell = Cell.new("A", %{foreground: :red})
      iex> buffer = ScreenBuffer.set_cell(buffer, 0, 0, cell)
      iex> cell = ScreenBuffer.get_cell(buffer, 0, 0)
      iex> Cell.get_char(cell)
      "A"
  """
  def set_cell(%__MODULE__{} = buffer, x, y, cell) when x >= 0 and y >= 0 do
    if y < buffer.height and x < buffer.width do
      new_cells = Enum.with_index(buffer.cells)
      |> Enum.map(fn {row, row_y} ->
        if row_y == y do
          Enum.with_index(row)
          |> Enum.map(fn {_, col_x} ->
            if col_x == x do
              cell
            else
              Enum.at(row, col_x)
            end
          end)
        else
          row
        end
      end)

      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  @doc """
  Clears the screen buffer.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.clear(buffer)
      iex> Enum.all?(buffer.cells, fn row ->
      ...>   Enum.all?(row, &Cell.is_empty?/1)
      ...> end)
      true
  """
  def clear(%__MODULE__{} = buffer) do
    %{buffer | cells: initialize_cells(buffer.width, buffer.height)}
  end

  @doc """
  Scrolls the screen buffer up by the given number of lines.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.scroll_up(buffer, 5)
      iex> length(buffer.scrollback)
      5
  """
  def scroll_up(%__MODULE__{} = buffer, lines) when lines > 0 do
    {scrollback, cells} = Enum.split(buffer.cells, lines)
    
    new_scrollback = scrollback ++ buffer.scrollback
    |> Enum.take(buffer.scrollback_limit)
    
    new_cells = cells ++ List.duplicate(
      List.duplicate(Cell.new(), buffer.width),
      lines
    )

    %{buffer |
      cells: new_cells,
      scrollback: new_scrollback
    }
  end

  @doc """
  Scrolls the screen buffer down by the given number of lines.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.scroll_down(buffer, 5)
      iex> length(buffer.scrollback)
      0
  """
  def scroll_down(%__MODULE__{} = buffer, lines) when lines > 0 do
    if length(buffer.scrollback) >= lines do
      {new_scrollback, scroll_lines} = Enum.split(buffer.scrollback, lines)
      
      new_cells = Enum.reverse(scroll_lines) ++ buffer.cells
      |> Enum.take(buffer.height)

      %{buffer |
        cells: new_cells,
        scrollback: new_scrollback
      }
    else
      buffer
    end
  end

  @doc """
  Sets the selection range.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.set_selection(buffer, {0, 0}, {10, 5})
      iex> buffer.selection
      {{0, 0}, {10, 5}}
  """
  def set_selection(%__MODULE__{} = buffer, start_pos, end_pos) do
    %{buffer | selection: {start_pos, end_pos}}
  end

  @doc """
  Clears the selection.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.set_selection(buffer, {0, 0}, {10, 5})
      iex> buffer = ScreenBuffer.clear_selection(buffer)
      iex> buffer.selection
      nil
  """
  def clear_selection(%__MODULE__{} = buffer) do
    %{buffer | selection: nil}
  end

  # Private functions

  defp initialize_cells(width, height) do
    List.duplicate(
      List.duplicate(Cell.new(), width),
      height
    )
  end

  defp initialize_cells(width, height) do
    List.duplicate(
      List.duplicate(Cell.new(), width),
      height
    )
  end

  defp create_empty_buffer(width, height) do
    List.duplicate(
      List.duplicate(Cell.new(), width),
      height
    )
  end

  defp clear_row_from_cursor(row, x) do
    Enum.with_index(row)
    |> Enum.map(fn {cell, i} ->
      if i >= x do
        Cell.new()
      else
        cell
      end
    end)
  end

  defp clear_row_to_cursor(row, x) do
    Enum.with_index(row)
    |> Enum.map(fn {cell, i} ->
      if i <= x do
        Cell.new()
      else
        cell
      end
    end)
  end

  defp get_text_in_region(buffer, start_x, start_y, end_x, end_y) do
    buffer.buffer
    |> Enum.with_index()
    |> Enum.filter(fn {_, y} -> y >= start_y and y <= end_y end)
    |> Enum.map(fn {row, y} ->
      row
      |> Enum.with_index()
      |> Enum.filter(fn {_, x} ->
        cond do
          y == start_y and y == end_y -> x >= start_x and x <= end_x
          y == start_y -> x >= start_x
          y == end_y -> x <= end_x
          true -> true
        end
      end)
      |> Enum.map(fn {cell, _} -> Cell.get_char(cell) end)
      |> Enum.join("")
    end)
    |> Enum.join("\n")
  end

  defp cell_attributes(cell) do
    cell.attributes
  end

  defp calculate_buffer_size(buffer) do
    # Rough estimation of memory usage based on buffer size and content
    total_cells = buffer
    |> Enum.map(&length/1)
    |> Enum.sum()
    
    cell_size = 100  # Estimated bytes per cell
    total_cells * cell_size
  end

  defp minimize_cell_attributes(cell) do
    # Keep only essential attributes
    %{cell | attributes: Map.take(cell.attributes, [:foreground, :background])}
  end
end 