defmodule Raxol.Core.Runtime.Rendering.Buffer do
  @moduledoc """
  Provides a screen buffer implementation for efficient rendering in Raxol applications.

  This module is responsible for:
  * Maintaining the screen buffer state
  * Calculating diffs between buffer states
  * Optimizing rendering by only updating changed cells
  """

  require Logger

  @typedoc """
  A cell represents a single character position on the screen.

  It is represented as a tuple with the following elements:
  - `x`: X coordinate (column)
  - `y`: Y coordinate (row)
  - `ch`: Character to display
  - `fg`: Foreground color
  - `bg`: Background color
  - `attrs`: List of attributes (e.g., :bold, :underline)
  """
  @type cell :: {integer, integer, String.t, term, term, list}

  @typedoc """
  A buffer is a map containing cells indexed by their position.

  The buffer also contains metadata about its dimensions.
  """
  @type t :: %__MODULE__{
    cells: %{{integer, integer} => {String.t, term, term, list}},
    width: integer,
    height: integer,
    dirty: boolean
  }

  defstruct cells: %{},
            width: 0,
            height: 0,
            dirty: true

  @doc """
  Creates a new empty buffer with the given dimensions.

  ## Parameters
  - `width`: Width of the buffer in columns
  - `height`: Height of the buffer in rows

  ## Returns
  A new buffer struct.
  """
  def new(width, height) do
    %__MODULE__{
      cells: %{},
      width: width,
      height: height,
      dirty: true
    }
  end

  @doc """
  Builds a buffer from a list of cells.

  ## Parameters
  - `cells`: List of cells
  - `width`: Width of the buffer in columns
  - `height`: Height of the buffer in rows

  ## Returns
  A new buffer containing the cells.
  """
  def from_cells(cells, width, height) do
    # Convert list of cells to map for efficient lookup
    cell_map =
      Enum.reduce(cells, %{}, fn {x, y, ch, fg, bg, attrs}, acc ->
        if x >= 0 and x < width and y >= 0 and y < height do
          Map.put(acc, {x, y}, {ch, fg, bg, attrs})
        else
          # Skip cells outside the buffer dimensions
          acc
        end
      end)

    %__MODULE__{
      cells: cell_map,
      width: width,
      height: height,
      dirty: true
    }
  end

  @doc """
  Gets the cell at the specified position.

  ## Parameters
  - `buffer`: The buffer to query
  - `x`: X coordinate
  - `y`: Y coordinate

  ## Returns
  The cell tuple if found, nil otherwise.
  """
  def get_cell(buffer, x, y) do
    case Map.get(buffer.cells, {x, y}) do
      nil -> nil
      {ch, fg, bg, attrs} -> {x, y, ch, fg, bg, attrs}
    end
  end

  @doc """
  Sets a cell in the buffer.

  ## Parameters
  - `buffer`: The buffer to modify
  - `x`: X coordinate
  - `y`: Y coordinate
  - `ch`: Character
  - `fg`: Foreground color
  - `bg`: Background color
  - `attrs`: Attributes list

  ## Returns
  Updated buffer.
  """
  def set_cell(buffer, x, y, ch, fg, bg, attrs \\ []) do
    if x >= 0 and x < buffer.width and y >= 0 and y < buffer.height do
      updated_cells = Map.put(buffer.cells, {x, y}, {ch, fg, bg, attrs})
      %{buffer | cells: updated_cells, dirty: true}
    else
      # Ignore cells outside the buffer
      buffer
    end
  end

  @doc """
  Clears the buffer by removing all cells.

  ## Parameters
  - `buffer`: The buffer to clear

  ## Returns
  Cleared buffer.
  """
  def clear(buffer) do
    %{buffer | cells: %{}, dirty: true}
  end

  @doc """
  Resizes the buffer to new dimensions.

  Cells outside the new dimensions are discarded.

  ## Parameters
  - `buffer`: The buffer to resize
  - `width`: New width
  - `height`: New height

  ## Returns
  Resized buffer.
  """
  def resize(buffer, width, height) do
    # Filter out cells that would be outside the new dimensions
    new_cells =
      buffer.cells
      |> Enum.filter(fn {{x, y}, _} ->
        x < width and y < height
      end)
      |> Map.new()

    %{buffer | cells: new_cells, width: width, height: height, dirty: true}
  end

  @doc """
  Computes the diff between two buffers.

  The diff contains only the cells that need to be updated.

  ## Parameters
  - `old_buffer`: Previous buffer state
  - `new_buffer`: Current buffer state

  ## Returns
  List of changed cells.
  """
  def diff(old_buffer, new_buffer) do
    # Start with cells in new_buffer that differ from old_buffer
    changed_cells =
      new_buffer.cells
      |> Enum.filter(fn {{x, y}, {ch, fg, bg, attrs}} ->
        case Map.get(old_buffer.cells, {x, y}) do
          nil -> true  # Cell doesn't exist in old buffer
          {^ch, ^fg, ^bg, ^attrs} -> false  # Cell is unchanged
          _ -> true  # Cell has changed
        end
      end)
      |> Enum.map(fn {{x, y}, {ch, fg, bg, attrs}} ->
        {x, y, ch, fg, bg, attrs}
      end)

    # Add cells that exist in old_buffer but not in new_buffer (need to be cleared)
    cells_to_clear =
      old_buffer.cells
      |> Enum.filter(fn {{x, y}, _} ->
        not Map.has_key?(new_buffer.cells, {x, y})
      end)
      |> Enum.map(fn {{x, y}, _} ->
        # Use space with default colors to clear
        {x, y, " ", :default, :default, []}
      end)

    # Combine both lists
    changed_cells ++ cells_to_clear
  end

  @doc """
  Converts the buffer to a flat list of cells.

  ## Parameters
  - `buffer`: The buffer to convert

  ## Returns
  List of cells.
  """
  def to_cells(buffer) do
    buffer.cells
    |> Enum.map(fn {{x, y}, {ch, fg, bg, attrs}} ->
      {x, y, ch, fg, bg, attrs}
    end)
  end

  @doc """
  Merges another buffer's cells into this buffer.

  Cells from the other buffer overwrite cells in this buffer.

  ## Parameters
  - `buffer`: The destination buffer
  - `other`: The source buffer
  - `offset_x`: X offset to apply when merging
  - `offset_y`: Y offset to apply when merging

  ## Returns
  Updated buffer.
  """
  def merge(buffer, other, offset_x \\ 0, offset_y \\ 0) do
    # Transform and merge cells from the other buffer
    merged_cells =
      other.cells
      |> Enum.reduce(buffer.cells, fn {{x, y}, cell}, acc ->
        new_x = x + offset_x
        new_y = y + offset_y

        if new_x >= 0 and new_x < buffer.width and new_y >= 0 and new_y < buffer.height do
          Map.put(acc, {new_x, new_y}, cell)
        else
          acc
        end
      end)

    %{buffer | cells: merged_cells, dirty: true}
  end
end
