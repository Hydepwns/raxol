defmodule Raxol.Terminal.Buffer.BufferState do
  @moduledoc """
  Handles state management and accessors for the Raxol.Terminal.ScreenBuffer.
  Includes resizing, getting dimensions, accessing cells/lines, managing scroll regions,
  and getting content.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.TextFormatting

  @doc """
  Resizes the screen buffer to the new dimensions.
  Preserves content that fits within the new bounds. Clears selection and scroll region.
  """
  @spec resize(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def resize(%ScreenBuffer{} = buffer, new_width, new_height)
      when is_integer(new_width) and new_width > 0 and is_integer(new_height) and
             new_height > 0 do
    {copy_width, copy_height} =
      calculate_copy_dimensions(buffer, new_width, new_height)

    new_grid = create_empty_grid(new_width, new_height)

    updated_grid =
      copy_old_content(buffer, new_grid, copy_width, copy_height, new_width)

    %{
      buffer
      | cells: updated_grid,
        width: new_width,
        height: new_height,
        scroll_region: nil,
        selection: nil
    }
  end

  def resize(buffer, _new_width, _new_height) when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  defp calculate_copy_dimensions(buffer, new_width, new_height) do
    {min(buffer.width, new_width), min(buffer.height, new_height)}
  end

  defp create_empty_grid(width, height) do
    default_cell = Cell.new(" ", TextFormatting.new())
    List.duplicate(List.duplicate(default_cell, width), height)
  end

  defp copy_old_content(buffer, new_grid, copy_width, copy_height, new_width) do
    case buffer.cells do
      nil ->
        # Return new grid if cells is nil
        new_grid

      cells ->
        Enum.reduce(0..(copy_height - 1), new_grid, fn y, current_grid ->
          old_row_slice = cells |> Enum.at(y) |> Enum.slice(0, copy_width)

          padding =
            List.duplicate(
              Cell.new(" ", TextFormatting.new()),
              max(0, new_width - copy_width)
            )

          List.update_at(current_grid, y, fn _ -> old_row_slice ++ padding end)
        end)
    end
  end

  @doc """
  Gets the current width of the screen buffer.
  """
  @spec get_width(ScreenBuffer.t()) :: non_neg_integer()
  def get_width(%{__struct__: _} = buffer) do
    buffer.width
  end

  def get_width(buffer) when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  @doc """
  Gets the current height of the screen buffer.
  """
  @spec get_height(ScreenBuffer.t()) :: non_neg_integer()
  def get_height(%{__struct__: _} = buffer) do
    buffer.height
  end

  def get_height(buffer) when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  @doc """
  Gets the dimensions {width, height} of the screen buffer.
  WARNING: This returns a tuple, NOT a buffer struct. Do not pass its result as a buffer!
  """
  @spec get_dimensions(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()}
  def get_dimensions(%ScreenBuffer{} = buffer) do
    {buffer.width, buffer.height}
  end

  @doc """
  Gets a specific line (list of Cells) from the buffer by index.
  Returns nil if index is out of bounds.
  """
  @spec get_line(ScreenBuffer.t(), non_neg_integer()) :: list(Cell.t()) | nil
  def get_line(%{__struct__: _} = buffer, line_index) when line_index >= 0 do
    case buffer.cells do
      nil ->
        # Return nil if cells is nil
        nil

      cells ->
        Enum.at(cells, line_index)
    end
  end

  def get_line(buffer, _line_index) when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  @doc """
  Gets a specific Cell from the buffer at {x, y}.
  Returns nil if coordinates are out of bounds.
  """
  @spec get_cell(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t() | nil
  def get_cell(%{__struct__: _} = buffer, x, y) when x >= 0 and y >= 0 do
    case buffer.cells do
      nil ->
        # Return nil if cells is nil
        nil

      cells ->
        cells |> Enum.at(y) |> Enum.at(x)
    end
  end

  def get_cell(buffer, _x, _y) when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  @doc """
  Gets the cell at the specified coordinates {x, y}.
  Returns nil if coordinates are out of bounds. Alias for get_cell/3.
  """
  @spec get_cell_at(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t() | nil
  def get_cell_at(%{__struct__: _} = buffer, x, y), do: get_cell(buffer, x, y)

  def get_cell_at(buffer, _x, _y) when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  @doc """
  Sets a scroll region in the buffer.
  """
  @spec set_scroll_region(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def set_scroll_region(%{__struct__: _} = buffer, start_line, end_line)
      when start_line >= 0 and end_line >= start_line do
    %{buffer | scroll_region: {start_line, end_line}}
  end

  def set_scroll_region(buffer, _start_line, _end_line)
      when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  @doc """
  Clears the scroll region setting in the buffer.
  """
  @spec clear_scroll_region(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear_scroll_region(%{__struct__: _} = buffer) do
    %{buffer | scroll_region: nil}
  end

  def clear_scroll_region(buffer) when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  @doc """
  Gets the boundaries {top, bottom} of the current scroll region.
  Returns {0, height - 1} if no region is set.
  """
  @spec get_scroll_region_boundaries(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()}
  def get_scroll_region_boundaries(%{__struct__: _} = buffer) do
    case buffer.scroll_region do
      {start, ending} -> {start, ending}
      nil -> {0, buffer.height - 1}
    end
  end

  def get_scroll_region_boundaries(buffer) when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  @doc """
  Converts the screen buffer content to a plain text string.
  """
  @spec get_content(ScreenBuffer.t()) :: String.t()
  def get_content(%{__struct__: _} = buffer) do
    case buffer.cells do
      nil ->
        # Return empty string if cells is nil
        ""

      cells ->
        cells
        |> Enum.map_join("\n", fn row ->
          row |> Enum.map_join("", &Cell.get_char/1) |> String.trim_trailing()
        end)
    end
  end

  def get_content(buffer) when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  @doc """
  Replaces the line at the given index with the provided list of cells.
  Returns the updated buffer.
  """
  @spec put_line(ScreenBuffer.t(), non_neg_integer(), list(Cell.t())) ::
          ScreenBuffer.t()
  def put_line(%{__struct__: _} = buffer, line_index, new_cells)
      when line_index >= 0 do
    case {line_index < buffer.height, is_list(new_cells),
          length(new_cells) == buffer.width} do
      {true, true, true} ->
        updated_cells = List.replace_at(buffer.cells, line_index, new_cells)
        %{buffer | cells: updated_cells}

      _ ->
        buffer
    end
  end

  def put_line(buffer, _line_index, _new_cells) when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end
end
