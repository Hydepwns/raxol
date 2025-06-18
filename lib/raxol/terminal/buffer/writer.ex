defmodule Raxol.Terminal.Buffer.Writer do
  @moduledoc """
  Handles writing characters and strings to the Raxol.Terminal.ScreenBuffer.
  Responsible for character width, bidirectional text segmentation, and cell creation.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Writes a character to the buffer at the specified position.
  Handles wide characters by taking up two cells when necessary.
  Accepts an optional style to apply to the cell.
  """
  @dialyzer {:nowarn_function, write_char: 5}
  @spec write_char(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def write_char(%ScreenBuffer{} = buffer, x, y, char, style \\ nil)
      when x >= 0 and y >= 0 do
    if y < buffer.height and x < buffer.width do
      codepoint = hd(String.to_charlist(char))
      width = Raxol.Terminal.CharacterHandling.get_char_width(codepoint)
      cell_style = create_cell_style(style)
      log_char_write(char, x, y, cell_style)
      cells = update_cells(buffer, x, y, char, cell_style, width)
      %{buffer | cells: cells}
    else
      buffer
    end
  end

  @doc """
  Creates a cell style by merging the provided style with default formatting.

  ## Parameters

  * `style` - The style to merge with default formatting, or nil for default style

  ## Returns

  A map containing the merged text formatting style.

  ## Examples

      iex> Writer.create_cell_style(%{fg: :red})
      %{fg: :red, bg: :default, bold: false, ...}
  """
  @spec create_cell_style(TextFormatting.text_style() | nil) :: TextFormatting.text_style()
  def create_cell_style(nil), do: TextFormatting.new()

  def create_cell_style(style) when is_map(style),
    do: Map.merge(TextFormatting.new(), style)

  def create_cell_style(_), do: TextFormatting.new()

  @doc """
  Logs character write operations for debugging purposes.

  ## Parameters

  * `char` - The character being written
  * `x` - The x-coordinate where the character is being written
  * `y` - The y-coordinate where the character is being written
  * `cell_style` - The style being applied to the cell

  ## Returns

  :ok

  ## Examples

      iex> Writer.log_char_write("A", 0, 0, %{fg: :red})
      :ok
  """
  @spec log_char_write(String.t(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style()) :: :ok
  def log_char_write(char, x, y, cell_style) do
    require Raxol.Core.Runtime.Log

    Raxol.Core.Runtime.Log.debug(
      "[Buffer.Writer] Writing char '#{char}' at {#{x}, #{y}} with style: #{inspect(cell_style)}"
    )
  end

  @doc """
  Updates cells in the buffer at the specified position.

  ## Parameters

  * `buffer` - The screen buffer to update
  * `x` - The x-coordinate to update
  * `y` - The y-coordinate to update
  * `char` - The character to write
  * `cell_style` - The style to apply
  * `width` - The width of the character (1 or 2 for wide characters)

  ## Returns

  The updated list of cells.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Writer.update_cells(buffer, 0, 0, "A", %{fg: :red}, 1)
      [%Cell{char: "A", style: %{fg: :red}}, ...]
  """
  @spec update_cells(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), String.t(), TextFormatting.text_style(), 1..2) :: list(list(Cell.t()))
  def update_cells(buffer, x, y, char, cell_style, width) do
    List.update_at(
      buffer.cells,
      y,
      &update_row(&1, x, char, cell_style, width, buffer.width)
    )
  end

  @doc """
  Updates a row in the buffer at the specified position.

  ## Parameters

  * `row` - The row to update
  * `x` - The x-coordinate to update
  * `char` - The character to write
  * `cell_style` - The style to apply
  * `width` - The width of the character (1 or 2 for wide characters)
  * `buffer_width` - The total width of the buffer

  ## Returns

  The updated row of cells.

  ## Examples

      iex> row = List.duplicate(Cell.new(), 80)
      iex> Writer.update_row(row, 0, "A", %{fg: :red}, 1, 80)
      [%Cell{char: "A", style: %{fg: :red}}, ...]
  """
  @spec update_row(list(Cell.t()), non_neg_integer(), String.t(), TextFormatting.text_style(), 1..2, non_neg_integer()) :: list(Cell.t())
  def update_row(row, x, char, cell_style, width, buffer_width) do
    new_cell = Cell.new(char, cell_style)

    if width == 2 and x + 1 < buffer_width do
      row
      |> List.update_at(x, fn _ -> new_cell end)
      |> List.update_at(x + 1, fn _ -> Cell.new_wide_placeholder(cell_style) end)
    else
      List.update_at(row, x, fn _ -> new_cell end)
    end
  end

  @doc """
  Writes a string to the buffer at the specified position.
  Handles wide characters and bidirectional text.
  """
  @spec write_string(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t()
        ) ::
          ScreenBuffer.t()
  def write_string(%ScreenBuffer{} = buffer, x, y, string)
      when x >= 0 and y >= 0 do
    segments = Raxol.Terminal.CharacterHandling.process_bidi_text(string)

    Enum.reduce(segments, {buffer, x}, fn {_type, segment},
                                          {acc_buffer, acc_x} ->
      {new_buffer, new_x} = write_segment(acc_buffer, acc_x, y, segment)
      {new_buffer, new_x}
    end)
    |> elem(0)
  end

  @doc """
  Writes a segment of text to the buffer.

  ## Parameters

  * `buffer` - The screen buffer to write to
  * `x` - The x-coordinate to start writing at
  * `y` - The y-coordinate to write at
  * `segment` - The text segment to write

  ## Returns

  A tuple containing the updated buffer and the new x-coordinate.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> {new_buffer, new_x} = Writer.write_segment(buffer, 0, 0, "Hello")
      iex> new_x
      5
  """
  @spec write_segment(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), String.t()) :: {ScreenBuffer.t(), non_neg_integer()}
  def write_segment(buffer, x, y, segment) do
    Enum.reduce(String.graphemes(segment), {buffer, x}, fn char,
                                                           {acc_buffer, acc_x} ->
      codepoint = hd(String.to_charlist(char))
      width = Raxol.Terminal.CharacterHandling.get_char_width(codepoint)
      {write_char(acc_buffer, acc_x, y, char), acc_x + width}
    end)
  end
end
