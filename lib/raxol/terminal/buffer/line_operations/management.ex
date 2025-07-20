defmodule Raxol.Terminal.Buffer.LineOperations.Management do
  @moduledoc """
  Handles line management operations for the screen buffer.
  """

  import Raxol.Guards
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Prepends a specified number of empty lines to the buffer.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `count` - The number of empty lines to prepend

  ## Returns

  The updated screen buffer with empty lines prepended.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = LineOperations.Management.prepend_lines(buffer, 2)
      iex> length(buffer.cells)
      24
  """
  @spec prepend_lines(ScreenBuffer.t(), non_neg_integer()) ::
          ScreenBuffer.t()
  def prepend_lines(buffer, count) when count > 0 do
    empty_lines = create_empty_lines(buffer.width, count)
    combined = empty_lines ++ buffer.cells
    new_cells = Enum.take(combined, buffer.height)
    removed = Enum.drop(combined, buffer.height)

    new_scrollback =
      Enum.take(removed ++ buffer.scrollback, buffer.scrollback_limit)

    %{buffer | cells: new_cells, scrollback: new_scrollback}
  end

  def prepend_lines(buffer, _count), do: buffer

  @doc """
  Removes lines from the top of the buffer.
  """
  @spec pop_top_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def pop_top_lines(buffer, count) when count > 0 do
    {_popped_lines, remaining_cells} = Enum.split(buffer.cells, count)

    # Add empty lines at the bottom
    empty_lines = create_empty_lines(buffer.width, count)
    new_cells = remaining_cells ++ empty_lines

    %{buffer | cells: new_cells}
  end

  def pop_top_lines(buffer, _count), do: buffer

  @doc """
  Gets a line from the buffer.
  """
  @spec get_line(ScreenBuffer.t(), non_neg_integer()) :: list(Cell.t())
  def get_line(buffer, line_index) do
    case buffer.cells do
      nil ->
        # Return empty list if cells is nil
        []

      cells ->
        if line_index >= 0 and line_index < length(cells) do
          Enum.at(cells, line_index) || []
        else
          []
        end
    end
  end

  @doc """
  Updates a line in the buffer with new cells.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `line_index` - The index of the line to update
  * `new_line` - The new line content

  ## Returns

  The updated screen buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> new_line = List.duplicate(%Cell{char: "A"}, 80)
      iex> buffer = LineOperations.Management.update_line(buffer, 0, new_line)
      iex> LineOperations.Management.get_line(buffer, 0) |> hd() |> Map.get(:char)
  """
  @spec update_line(ScreenBuffer.t(), non_neg_integer(), list(Cell.t())) ::
          ScreenBuffer.t()
  def update_line(buffer, line_index, new_line) do
    case buffer.cells do
      nil ->
        # Return buffer unchanged if cells is nil
        buffer

      cells ->
        if line_index >= 0 and line_index < length(cells) do
          new_cells = List.replace_at(cells, line_index, new_line)
          %{buffer | cells: new_cells}
        else
          buffer
        end
    end
  end

  @doc """
  Clears a line in the buffer with optional styling.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `line_index` - The index of the line to clear
  * `style` - Optional text style for the cleared line

  ## Returns

  The updated screen buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> style = %{fg: :red, bg: :blue}
      iex> buffer = LineOperations.Management.clear_line(buffer, 0, style)
      iex> LineOperations.Management.get_line(buffer, 0) |> hd() |> Map.get(:style)
      %{fg: :red, bg: :blue}
  """
  @spec clear_line(
          ScreenBuffer.t(),
          non_neg_integer(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def clear_line(buffer, line_index, style \\ nil) do
    empty_line = create_empty_line(buffer.width, style || buffer.default_style)
    update_line(buffer, line_index, empty_line)
  end

  @doc """
  Sets a line at a specific position.
  """
  @spec set_line(ScreenBuffer.t(), non_neg_integer(), list(Cell.t())) ::
          ScreenBuffer.t()
  def set_line(buffer, position, new_line) do
    if position >= 0 and position < length(buffer.cells) do
      new_cells = List.replace_at(buffer.cells, position, new_line)
      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  @doc """
  Creates a specified number of empty lines with the given width.

  ## Parameters

  * `width` - The width of each line
  * `count` - The number of lines to create

  ## Returns

  A list of empty lines, where each line is a list of empty cells.

  ## Examples

      iex> lines = LineOperations.Management.create_empty_lines(80, 2)
      iex> length(lines)
      2
      iex> length(hd(lines))
      80
  """
  @spec create_empty_lines(non_neg_integer(), non_neg_integer()) ::
          list(list(Cell.t()))
  def create_empty_lines(width, count) do
    for _ <- 1..count do
      create_empty_line(width)
    end
  end

  @doc """
  Creates empty lines with the given width and style.

  ## Parameters

  * `width` - The width of each line
  * `count` - The number of lines to create
  * `style` - The text style for the cells

  ## Returns

  A list of empty lines with the specified style.

  ## Examples

      iex> lines = LineOperations.Management.create_empty_lines(80, 3, %{fg: :red})
      iex> length(lines)
      3
      iex> hd(hd(lines)).style.fg
      :red
  """
  @spec create_empty_lines(
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) ::
          list(list(Cell.t()))
  def create_empty_lines(width, count, style) do
    for _ <- 1..count do
      create_empty_line(width, style)
    end
  end

  @doc """
  Creates a single empty line with the given width and optional style.

  ## Parameters

  * `width` - The width of the line
  * `style` - Optional text style for the cells

  ## Returns

  A list of empty cells representing an empty line.

  ## Examples

      iex> line = LineOperations.Management.create_empty_line(80)
      iex> length(line)
      80
      iex> line = LineOperations.Management.create_empty_line(80, %{fg: :red})
      iex> hd(line).style.fg
      :red
  """
  @spec create_empty_line(non_neg_integer(), TextFormatting.text_style() | nil) ::
          list(Cell.t())
  def create_empty_line(width, style \\ nil) do
    for _ <- 1..width do
      Cell.new(" ", style)
    end
  end
end
