defmodule Raxol.Terminal.Buffer.Operations do
  @moduledoc """
  Handles buffer-related operations for the terminal emulator.
  This module is responsible for managing screen buffer operations like resizing,
  scrolling, and cursor movement within the buffer.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Buffer.Writer
  alias Raxol.Terminal.Buffer.Eraser
  alias Raxol.Terminal.Buffer.Scroller
  alias Raxol.Terminal.Buffer.Updater
  alias Raxol.Terminal.Buffer.State
  alias Raxol.Terminal.Buffer.CharEditor
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  # Needed for scroll functions
  # alias Raxol.Terminal.Buffer.Scrollback

  @doc """
  Writes a character to the buffer at the specified position.
  Handles wide characters by taking up two cells when necessary.
  Accepts an optional style to apply to the cell.
  """
  # Suppress spurious exact_eq warning
  @dialyzer {:nowarn_function, write_char: 5}
  defdelegate write_char(buffer, x, y, char, style \\ nil), to: Writer

  defdelegate write_string(buffer, x, y, string), to: Writer

  @spec scroll_up(ScreenBuffer.t(), non_neg_integer(), {non_neg_integer(), non_neg_integer()} | nil) :: {ScreenBuffer.t(), list(list(Cell.t()))}
  defdelegate scroll_up(buffer, lines, scroll_region_arg \\ nil), to: Scroller

  @spec scroll_down(ScreenBuffer.t(), list(list(Cell.t())), non_neg_integer(), {non_neg_integer(), non_neg_integer()} | nil) :: ScreenBuffer.t()
  defdelegate scroll_down(buffer, lines_to_insert, lines, scroll_region \\ nil), to: Scroller

  @doc """
  Replaces the content of a region in the buffer with new content.

  ## Parameters

  * `cells` - The current cells in the buffer
  * `start_line` - The starting line of the region to replace
  * `end_line` - The ending line of the region to replace
  * `new_content` - The new content to insert in the region

  ## Returns

  The updated cells with the region replaced.
  """
  @spec replace_region_content(list(list(Cell.t())), non_neg_integer(), non_neg_integer(), list(list(Cell.t()))) :: list(list(Cell.t()))
  def replace_region_content(cells, start_line, end_line, new_content) do
    {before, after_part} = Enum.split(cells, start_line)
    {_, after_part} = Enum.split(after_part, end_line - start_line + 1)
    before ++ new_content ++ after_part
  end

  @doc false
  @spec set_scroll_region(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  defdelegate set_scroll_region(buffer, start_line, end_line), to: State

  @doc false
  @spec clear_scroll_region(ScreenBuffer.t()) :: ScreenBuffer.t()
  defdelegate clear_scroll_region(buffer), to: State

  @doc false
  @spec get_scroll_region_boundaries(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()}
  defdelegate get_scroll_region_boundaries(buffer), to: State

  @doc false
  @spec get_width(ScreenBuffer.t()) :: non_neg_integer()
  defdelegate get_width(buffer), to: State

  @doc false
  @spec get_height(ScreenBuffer.t()) :: non_neg_integer()
  defdelegate get_height(buffer), to: State

  @doc false
  @spec get_dimensions(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()}
  defdelegate get_dimensions(buffer), to: State

  @doc false
  @spec get_line(ScreenBuffer.t(), non_neg_integer()) :: list(Cell.t()) | nil
  defdelegate get_line(buffer, line_index), to: State

  @doc false
  @spec get_cell(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t() | nil
  defdelegate get_cell(buffer, x, y), to: State

  @doc false
  @spec diff(
          ScreenBuffer.t(),
          list({non_neg_integer(), non_neg_integer(), map()})
        ) :: list({non_neg_integer(), non_neg_integer(), map()})
  defdelegate diff(buffer, changes), to: Updater

  @doc false
  @spec update(
          ScreenBuffer.t(),
          list({non_neg_integer(), non_neg_integer(), Cell.t() | map()})
        ) :: ScreenBuffer.t()
  defdelegate update(buffer, changes), to: Updater

  @doc """
  Erases parts of the display based on cursor position (:to_end, :to_beginning, :all).
  Requires cursor state {x, y}.
  """
  @spec erase_in_display(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          atom(),
          Cell.Style.t() | nil
        ) :: ScreenBuffer.t()
  defdelegate erase_in_display(
                buffer,
                cursor_pos,
                type,
                style \\ TextFormatting.new()
              ),
              to: Eraser

  @doc """
  Erases parts of the current line based on cursor position (:to_end, :to_beginning, :all).
  Requires cursor state {x, y}.
  """
  @spec erase_in_line(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          atom(),
          Cell.Style.t() | nil
        ) :: ScreenBuffer.t()
  defdelegate erase_in_line(
                buffer,
                cursor_pos,
                type,
                style \\ TextFormatting.new()
              ),
              to: Eraser

  @doc false
  @spec clear(ScreenBuffer.t(), Cell.Style.t() | nil) :: ScreenBuffer.t()
  defdelegate clear(buffer, style \\ TextFormatting.new()),
    to: Eraser,
    as: :clear_screen

  @doc false
  @spec insert_characters(
          State.t(),
          row :: non_neg_integer(),
          col :: non_neg_integer(),
          count :: non_neg_integer(),
          style :: Cell.Style.t() | nil
        ) :: State.t()
  defdelegate insert_characters(
                buffer,
                row,
                col,
                count,
                style \\ TextFormatting.new()
              ),
              to: CharEditor

  @doc false
  @spec delete_characters(
          State.t(),
          row :: non_neg_integer(),
          col :: non_neg_integer(),
          count :: non_neg_integer(),
          style :: Cell.Style.t() | nil
        ) :: State.t()
  defdelegate delete_characters(
                buffer,
                row,
                col,
                count,
                style \\ TextFormatting.new()
              ),
              to: CharEditor

  @doc false
  @spec get_content(ScreenBuffer.t()) :: String.t()
  defdelegate get_content(buffer), to: State

  @doc false
  @spec get_cell_at(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t() | nil
  defdelegate get_cell_at(buffer, x, y), to: State

  @doc false
  @spec clear_region(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Cell.Style.t() | nil
        ) :: ScreenBuffer.t()
  defdelegate clear_region(
                buffer,
                start_x,
                start_y,
                end_x,
                end_y,
                style \\ TextFormatting.new()
              ),
              to: Eraser

  @doc false
  @spec put_line(ScreenBuffer.t(), non_neg_integer(), list(Cell.t())) ::
          ScreenBuffer.t()
  defdelegate put_line(buffer, line_index, new_cells), to: State

  @doc """
  Clears a line in the buffer by replacing all cells with empty cells.
  """
  @spec clear_line(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def clear_line(buffer, y) do
    width = buffer.width
    empty_cells = List.duplicate(%Cell{char: " ", style: %{}}, width)
    put_line(buffer, y, empty_cells)
  end

  @doc """
  Clears the entire screen by clearing each line.
  """
  @spec clear_screen(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear_screen(buffer) do
    Enum.reduce(0..(buffer.height - 1), buffer, fn y, acc ->
      clear_line(acc, y)
    end)
  end

  @doc """
  Deletes 'count' lines starting at 'y', scrolling up the lines below.
  Respects the scroll region if specified.
  """
  @spec delete_lines(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_lines(buffer, y, count) do
    {scroll_top, scroll_bottom} = get_scroll_region_boundaries(buffer)
    y = max(y, scroll_top)
    count = min(count, scroll_bottom - y + 1)

    if count > 0 do
      {buffer, _} = scroll_up(buffer, count, {scroll_top, scroll_bottom})
      buffer
    else
      buffer
    end
  end

  @doc """
  Inserts 'count' lines at 'y', scrolling down the lines below.
  Respects the scroll region if specified.
  """
  @spec insert_lines(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_lines(buffer, y, count) do
    {scroll_top, scroll_bottom} = get_scroll_region_boundaries(buffer)
    y = max(y, scroll_top)
    count = min(count, scroll_bottom - y + 1)

    if count > 0 do
      empty_lines = List.duplicate(List.duplicate(%Cell{char: " ", style: %{}}, buffer.width), count)
      scroll_down(buffer, empty_lines, count, {scroll_top, scroll_bottom})
    else
      buffer
    end
  end

  @doc """
  Sets the cursor position in the buffer.
  """
  @spec set_cursor_position(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def set_cursor_position(buffer, x, y) do
    %{buffer | cursor_position: {x, y}}
  end

  @doc """
  Gets the current cursor position from the buffer.
  """
  @spec get_cursor_position(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()}
  def get_cursor_position(buffer) do
    buffer.cursor_position
  end

  @doc """
  Marks a region of the buffer as damaged.
  """
  @spec mark_damaged(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def mark_damaged(buffer, x, y, width, height) do
    %{buffer | damage_regions: [{x, y, width, height} | buffer.damage_regions]}
  end

  @doc """
  Gets all damaged regions in the buffer.
  """
  @spec get_damage_regions(ScreenBuffer.t()) :: [{non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}]
  def get_damage_regions(buffer) do
    buffer.damage_regions
  end

  @doc """
  Resizes the emulator's screen buffers and updates related state.
  This function handles resizing both main and alternate screen buffers,
  updates tab stops, and adjusts cursor position and scroll region.
  """
  @spec resize(EmulatorStruct.t(), non_neg_integer(), non_neg_integer()) :: EmulatorStruct.t()
  def resize(%EmulatorStruct{} = emulator, new_width, new_height) do
    # Resize both buffers
    new_main_buffer =
      ScreenBuffer.resize(emulator.main_screen_buffer, new_width, new_height)

    new_alt_buffer =
      ScreenBuffer.resize(
        emulator.alternate_screen_buffer,
        new_width,
        new_height
      )

    # Update tab stops for the new width
    new_tab_stops = default_tab_stops(new_width)

    # Clamp cursor position
    {cur_x, cur_y} = get_cursor_position(emulator)
    clamped_x = min(max(cur_x, 0), new_width - 1)
    clamped_y = min(max(cur_y, 0), new_height - 1)
    new_cursor = %{emulator.cursor | position: {clamped_x, clamped_y}}

    # Clamp or reset scroll region
    new_scroll_region =
      case emulator.scroll_region do
        {top, bottom}
        when is_integer(top) and is_integer(bottom) and top < bottom and
               top >= 0 and bottom < new_height ->
          {top, bottom}

        _ ->
          nil
      end

    # Return updated emulator
    %{
      emulator
      | main_screen_buffer: new_main_buffer,
        alternate_screen_buffer: new_alt_buffer,
        tab_stops: new_tab_stops,
        cursor: new_cursor,
        scroll_region: new_scroll_region,
        width: new_width,
        height: new_height
    }
  end

  @doc """
  Checks if the cursor is below the scroll region and scrolls up if necessary.
  Called after operations like LF, IND, NEL that might move the cursor off-screen.
  """
  @spec maybe_scroll(EmulatorStruct.t()) :: EmulatorStruct.t()
  def maybe_scroll(%EmulatorStruct{} = emulator) do
    {_, cursor_y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)
    buffer = EmulatorStruct.get_active_buffer(emulator)
    height = ScreenBuffer.get_height(buffer)

    if cursor_y >= height do
      # Need to scroll
      {top, bottom} =
        case emulator.scroll_region do
          nil -> {0, height - 1}
          region -> region
        end

      # Scroll up by the amount the cursor is below the screen
      scroll_amount = cursor_y - bottom
      {new_buffer, _} = Scroller.scroll_up(buffer, scroll_amount, {top, bottom})
      EmulatorStruct.update_active_buffer(emulator, new_buffer)
    else
      emulator
    end
  end

  @doc """
  Moves the cursor down one line (index operation).
  """
  @spec index(EmulatorStruct.t()) :: EmulatorStruct.t()
  def index(%EmulatorStruct{} = emulator) do
    {x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)
    buffer = EmulatorStruct.get_active_buffer(emulator)
    height = ScreenBuffer.get_height(buffer)
    new_y = y + 1

    # Check if we need to scroll
    if new_y >= height do
      maybe_scroll(emulator)
    else
      cursor = Raxol.Terminal.Cursor.Manager.move_to(
        emulator.cursor,
        {x, new_y},
        ScreenBuffer.get_width(buffer),
        height
      )
      %{emulator | cursor: cursor}
    end
  end

  @doc """
  Moves the cursor to the next line.
  """
  @spec next_line(EmulatorStruct.t()) :: EmulatorStruct.t()
  def next_line(emulator) do
    index(emulator)
  end

  @doc """
  Moves the cursor up one line (reverse index operation).
  """
  @spec reverse_index(EmulatorStruct.t()) :: EmulatorStruct.t()
  def reverse_index(%EmulatorStruct{} = emulator) do
    {x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)
    buffer = EmulatorStruct.get_active_buffer(emulator)
    height = ScreenBuffer.get_height(buffer)
    new_y = max(0, y - 1)

    cursor = Raxol.Terminal.Cursor.Manager.move_to(
      emulator.cursor,
      {x, new_y},
      ScreenBuffer.get_width(buffer),
      height
    )
    %{emulator | cursor: cursor}
  end

  # Private helper functions

  defp default_tab_stops(width) do
    # Generate tab stops every 8 columns
    for i <- 0..(width - 1), rem(i, 8) == 0, do: i
  end

  @doc """
  Creates a new buffer with the specified options.
  """
  def new(opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    ScreenBuffer.new(width, height)
  end

  @doc """
  Writes data to the buffer.
  """
  def write(buffer, data, _opts \\ []) do
    case data do
      char when is_binary(char) and byte_size(char) == 1 ->
        write_char(buffer, 0, 0, char)
      string when is_binary(string) ->
        write_string(buffer, 0, 0, string)
      _ ->
        buffer
    end
  end

  @doc """
  Reads data from the buffer.
  """
  def read(buffer, _opts \\ []) do
    {get_content(buffer), buffer}
  end

  @doc """
  Scrolls the buffer by the specified number of lines.
  """
  def scroll(buffer, lines) when lines > 0 do
    scroll_up(buffer, lines)
  end
  def scroll(buffer, lines) when lines < 0 do
    {new_buffer, _} = scroll_down(buffer, [], abs(lines))
    new_buffer
  end
  def scroll(buffer, 0), do: buffer

  @doc """
  Sets a cell in the buffer at the specified coordinates.
  """
  def set_cell(buffer, x, y, cell) do
    put_line(buffer, y, List.replace_at(get_line(buffer, y), x, cell))
  end

  @doc """
  Gets a cell from the buffer at the specified coordinates.
  """
  @spec get_cell(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: Cell.t() | nil
  def get_cell(buffer, x, y) do
    buffer.cells
    |> Enum.at(y)
    |> Enum.at(x)
  end

  @doc """
  Resizes the buffer to the specified dimensions.
  """
  @spec resize(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def resize(buffer, new_width, new_height) do
    State.resize(buffer, new_width, new_height)
  end

  @doc """
  Scrolls the screen up by the specified number of lines.
  """
  @spec scroll_up_screen(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def scroll_up_screen(buffer, lines) do
    # Move lines from bottom to scrollback
    {to_scrollback, remaining_cells} = Enum.split(buffer.cells, lines)
    new_scrollback = (buffer.scrollback || []) ++ to_scrollback

    # Add empty lines at the top
    new_cells = remaining_cells ++ create_empty_grid(buffer.width, lines)

    %{buffer |
      cells: new_cells,
      scrollback: new_scrollback
    }
  end

  @doc """
  Scrolls the screen down by the specified number of lines.
  """
  @spec scroll_down(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def scroll_down(buffer, lines) do
    # Move lines from scrollback to top
    {to_restore, remaining_scrollback} = Enum.split(buffer.scrollback || [], lines)
    new_cells = Enum.reverse(to_restore) ++ buffer.cells

    # Remove excess lines from bottom
    new_cells = Enum.take(new_cells, buffer.height)

    %{buffer |
      cells: new_cells,
      scrollback: remaining_scrollback
    }
  end

  @doc """
  Sets the scroll region boundaries.
  """
  @spec set_scroll_region(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def set_scroll_region(buffer, start_line, end_line) do
    %{buffer | scroll_region: {start_line, end_line}}
  end

  @doc """
  Clears the scroll region.
  """
  @spec clear_scroll_region(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear_scroll_region(buffer) do
    %{buffer | scroll_region: nil}
  end

  @doc """
  Gets the scroll region boundaries.
  """
  @spec get_scroll_region_boundaries(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()}
  def get_scroll_region_boundaries(buffer) do
    case buffer.scroll_region do
      {start, end_} -> {start, end_}
      nil -> {0, buffer.height - 1}
    end
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
  Gets the dimensions of the buffer.
  """
  @spec get_dimensions(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()}
  def get_dimensions(buffer) do
    {buffer.width, buffer.height}
  end

  @doc """
  Gets a line from the buffer.
  """
  @spec get_line(ScreenBuffer.t(), non_neg_integer()) :: list(Cell.t()) | nil
  def get_line(buffer, line_index) do
    Enum.at(buffer.cells, line_index)
  end

  # Private helper functions

  defp create_empty_grid(width, height) do
    for _y <- 0..(height - 1) do
      for _x <- 0..(width - 1) do
        Cell.new()
      end
    end
  end
end
