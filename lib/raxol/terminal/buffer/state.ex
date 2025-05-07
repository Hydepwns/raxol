defmodule Raxol.Terminal.Buffer.State do
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
    old_width = buffer.width
    old_height = buffer.height

    # Calculate dimensions for copying
    copy_height = min(old_height, new_height)
    copy_width = min(old_width, new_width)

    # Create a new empty grid of the correct size, initialize with non-dirty cells
    default_padding_cell = Cell.new(" ", TextFormatting.new(), false)
    new_grid = List.duplicate(List.duplicate(default_padding_cell, new_width), new_height)

    # Efficiently copy the relevant part of the old grid
    updated_grid =
      Enum.reduce(0..(copy_height - 1), new_grid, fn y, current_grid ->
        # Get the corresponding row slice from the old grid (preserving original cells)
        old_row_slice_to_copy = buffer.cells |> Enum.at(y) |> Enum.slice(0, copy_width)

        # Update the new row, replacing the beginning part with the copied slice
        List.update_at(current_grid, y, fn _row_placeholder ->
          # Calculate needed padding size
          padding_size = max(0, new_width - copy_width)
          # Create padding with non-dirty default cells
          padding = List.duplicate(default_padding_cell, padding_size)
          # Combine the copied slice and the padding
          old_row_slice_to_copy ++ padding
        end)
      end)

    %{
      buffer
      | cells: updated_grid,
        width: new_width,
        height: new_height,
        scroll_region: nil,
        selection: nil
    }
  end

  @doc """
  Gets the current width of the screen buffer.
  """
  @spec get_width(ScreenBuffer.t()) :: non_neg_integer()
  def get_width(%ScreenBuffer{} = buffer) do
    buffer.width
  end

  @doc """
  Gets the current height of the screen buffer.
  """
  @spec get_height(ScreenBuffer.t()) :: non_neg_integer()
  def get_height(%ScreenBuffer{} = buffer) do
    buffer.height
  end

  @doc """
  Gets the dimensions {width, height} of the screen buffer.
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
  def get_line(%ScreenBuffer{} = buffer, line_index) when line_index >= 0 do
    Enum.at(buffer.cells, line_index)
  end

  @doc """
  Gets a specific Cell from the buffer at {x, y}.
  Returns nil if coordinates are out of bounds.
  """
  @spec get_cell(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t() | nil
  def get_cell(%ScreenBuffer{} = buffer, x, y) when x >= 0 and y >= 0 do
    buffer.cells |> Enum.at(y) |> Enum.at(x)
  end

  @doc """
  Gets the cell at the specified coordinates {x, y}.
  Returns nil if coordinates are out of bounds. Alias for get_cell/3.
  """
  @spec get_cell_at(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t() | nil
  def get_cell_at(buffer, x, y), do: get_cell(buffer, x, y)

  @doc """
  Sets a scroll region in the buffer.
  """
  @spec set_scroll_region(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def set_scroll_region(%ScreenBuffer{} = buffer, start_line, end_line)
      when start_line >= 0 and end_line >= start_line do
    %{buffer | scroll_region: {start_line, end_line}}
  end

  @doc """
  Clears the scroll region setting in the buffer.
  """
  @spec clear_scroll_region(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear_scroll_region(%ScreenBuffer{} = buffer) do
    %{buffer | scroll_region: nil}
  end

  @doc """
  Gets the boundaries {top, bottom} of the current scroll region.
  Returns {0, height - 1} if no region is set.
  """
  @spec get_scroll_region_boundaries(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()}
  def get_scroll_region_boundaries(%ScreenBuffer{} = buffer) do
    case buffer.scroll_region do
      {start, ending} -> {start, ending}
      nil -> {0, buffer.height - 1}
    end
  end

  @doc """
  Converts the screen buffer content to a plain text string.
  """
  @spec get_content(ScreenBuffer.t()) :: String.t()
  def get_content(%ScreenBuffer{} = buffer) do
    buffer.cells
    |> Enum.map(fn row ->
      row |> Enum.map_join("", &Cell.get_char/1) |> String.trim_trailing()
    end)
    |> Enum.join("\n")
  end
end
