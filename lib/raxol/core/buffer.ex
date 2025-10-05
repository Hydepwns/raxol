defmodule Raxol.Core.Buffer do
  @moduledoc """
  Lightweight terminal buffer primitives for Raxol v2.0.

  This module provides pure functional buffer operations without framework dependencies.
  Designed to be used standalone or as the foundation for higher-level abstractions.

  ## Buffer Structure

      %{
        lines: [
          %{cells: [
            %{char: " ", style: %{bold: false, fg_color: nil, bg_color: nil}}
          ]}
        ],
        width: 80,
        height: 24
      }

  ## Performance Targets

  - Operations complete in < 1ms for 80x24 buffer
  - Zero external dependencies
  - Memory efficient

  ## Examples

      # Create a blank buffer
      buffer = Raxol.Core.Buffer.create_blank_buffer(80, 24)

      # Write text at coordinates
      buffer = Raxol.Core.Buffer.write_at(buffer, 5, 3, "Hello, Raxol!")

      # Get a specific cell
      cell = Raxol.Core.Buffer.get_cell(buffer, 5, 3)

      # Render to string
      output = Raxol.Core.Buffer.to_string(buffer)

  """

  @type cell :: %{
          char: String.t(),
          style: map()
        }

  @type line :: %{cells: list(cell())}

  @type t :: %{
          lines: list(line()),
          width: non_neg_integer(),
          height: non_neg_integer()
        }

  @doc """
  Creates a blank buffer with the specified dimensions.

  ## Parameters

    - `width` - Width of the buffer in characters
    - `height` - Height of the buffer in lines

  ## Examples

      iex> buffer = Raxol.Core.Buffer.create_blank_buffer(80, 24)
      iex> buffer.width
      80
      iex> buffer.height
      24

  """
  @spec create_blank_buffer(non_neg_integer(), non_neg_integer()) :: t()
  def create_blank_buffer(width, height) do
    blank_cell = %{char: " ", style: %{}}
    blank_line = %{cells: List.duplicate(blank_cell, width)}
    lines = List.duplicate(blank_line, height)

    %{
      lines: lines,
      width: width,
      height: height
    }
  end

  @doc """
  Writes text at the specified coordinates with optional styling.

  ## Parameters

    - `buffer` - The buffer to write to
    - `x` - X coordinate (column)
    - `y` - Y coordinate (row)
    - `content` - Text to write
    - `style` - Optional style map (default: %{})

  ## Examples

      iex> buffer = Raxol.Core.Buffer.create_blank_buffer(80, 24)
      iex> buffer = Raxol.Core.Buffer.write_at(buffer, 0, 0, "Hello")
      iex> cell = Raxol.Core.Buffer.get_cell(buffer, 0, 0)
      iex> cell.char
      "H"

  """
  @spec write_at(t(), non_neg_integer(), non_neg_integer(), String.t(), map()) ::
          t()
  def write_at(buffer, x, y, content, style \\ %{}) do
    content
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, index}, acc_buffer ->
      set_cell(acc_buffer, x + index, y, char, style)
    end)
  end

  @doc """
  Retrieves the cell at the specified coordinates.

  ## Parameters

    - `buffer` - The buffer to read from
    - `x` - X coordinate (column)
    - `y` - Y coordinate (row)

  ## Returns

  The cell at the specified position, or `nil` if out of bounds.

  """
  @spec get_cell(t(), non_neg_integer(), non_neg_integer()) :: cell() | nil
  def get_cell(%{lines: lines, width: width, height: height}, x, y) do
    cond do
      y >= height or y < 0 ->
        nil

      x >= width or x < 0 ->
        nil

      true ->
        lines
        |> Enum.at(y)
        |> Map.get(:cells)
        |> Enum.at(x)
    end
  end

  @doc """
  Updates a single cell at the specified coordinates.

  ## Parameters

    - `buffer` - The buffer to update
    - `x` - X coordinate (column)
    - `y` - Y coordinate (row)
    - `char` - Character to set
    - `style` - Style to apply

  """
  @spec set_cell(t(), non_neg_integer(), non_neg_integer(), String.t(), map()) ::
          t()
  def set_cell(
        %{lines: lines, width: width, height: height} = buffer,
        x,
        y,
        char,
        style
      ) do
    cond do
      y >= height or y < 0 ->
        buffer

      x >= width or x < 0 ->
        buffer

      true ->
        new_cell = %{char: char, style: style}

        updated_lines =
          List.update_at(lines, y, fn line ->
            updated_cells =
              List.update_at(line.cells, x, fn _old_cell -> new_cell end)

            %{cells: updated_cells}
          end)

        %{buffer | lines: updated_lines}
    end
  end

  @doc """
  Clears the buffer, resetting all cells to blank.

  ## Parameters

    - `buffer` - The buffer to clear

  """
  @spec clear(t()) :: t()
  def clear(%{width: width, height: height}) do
    create_blank_buffer(width, height)
  end

  @doc """
  Resizes the buffer to new dimensions.

  ## Parameters

    - `buffer` - The buffer to resize
    - `width` - New width
    - `height` - New height

  """
  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  def resize(%{lines: old_lines, width: old_width}, new_width, new_height) do
    blank_cell = %{char: " ", style: %{}}

    resized_lines =
      old_lines
      |> Enum.take(new_height)
      |> Enum.map(fn line ->
        cells = line.cells

        cond do
          new_width > old_width ->
            %{cells: cells ++ List.duplicate(blank_cell, new_width - old_width)}

          new_width < old_width ->
            %{cells: Enum.take(cells, new_width)}

          true ->
            line
        end
      end)

    lines_to_add = new_height - length(resized_lines)

    new_lines =
      if lines_to_add > 0 do
        blank_line = %{cells: List.duplicate(blank_cell, new_width)}
        resized_lines ++ List.duplicate(blank_line, lines_to_add)
      else
        resized_lines
      end

    %{
      lines: new_lines,
      width: new_width,
      height: new_height
    }
  end

  @doc """
  Converts the buffer to a string representation for debugging.

  ## Parameters

    - `buffer` - The buffer to convert

  """
  @spec to_string(t()) :: String.t()
  def to_string(%{lines: lines}) do
    lines
    |> Enum.map(fn line ->
      line.cells
      |> Enum.map(fn cell -> cell.char end)
      |> Enum.join("")
    end)
    |> Enum.join("\n")
  end
end
