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
  alias Raxol.Terminal.Emulator
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
  defdelegate write_string(buffer, x, y, string), to: Writer

  @doc """
  Scrolls the buffer up by the specified number of lines, optionally within a specified scroll region.
  Handles cell manipulation.
  Returns `{updated_buffer, scrolled_off_lines}`.
  """
  @spec scroll_up(
          ScreenBuffer.t(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: {ScreenBuffer.t(), list(list(Cell.t()))}
  defdelegate scroll_up(buffer, lines, scroll_region_arg \\ nil), to: Scroller

  @doc """
  Scrolls the buffer down by the specified number of lines, optionally within a specified scroll region.
  Handles cell manipulation using provided lines from scrollback.
  Expects `lines_to_insert` from the caller (e.g., Buffer.Manager via Buffer.Scrollback).
  """
  @spec scroll_down(
          ScreenBuffer.t(),
          list(list(Cell.t())),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: ScreenBuffer.t()
  defdelegate scroll_down(buffer, lines_to_insert, lines, scroll_region \\ nil),
    to: Scroller

  # Helper to replace content within a scroll region (internal)
  # Operates directly on the cells list, returns the updated list.
  def replace_region_content(
        current_cells,
        scroll_start,
        scroll_end,
        new_content
      ) do
    buffer_height = length(current_cells)
    lines_before = Enum.slice(current_cells, 0, scroll_start)

    lines_after =
      Enum.slice(
        current_cells,
        scroll_end + 1,
        buffer_height - (scroll_end + 1)
      )

    lines_before ++ new_content ++ lines_after
  end

  @doc """
  Sets a scroll region in the buffer.
  """
  @spec set_scroll_region(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  defdelegate set_scroll_region(buffer, start_line, end_line), to: State

  @doc """
  Clears the scroll region setting in the buffer.
  """
  @spec clear_scroll_region(ScreenBuffer.t()) :: ScreenBuffer.t()
  defdelegate clear_scroll_region(buffer), to: State

  @doc """
  Gets the boundaries {top, bottom} of the current scroll region.
  Returns {0, height - 1} if no region is set.
  """
  @spec get_scroll_region_boundaries(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()}
  defdelegate get_scroll_region_boundaries(buffer), to: State

  @doc """
  Resizes the screen buffer to the new dimensions.
  Preserves content that fits within the new bounds. Clears selection and scroll region.
  """
  @spec resize(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  defdelegate resize(buffer, new_width, new_height), to: State

  @doc """
  Gets the current width of the screen buffer.
  """
  @spec get_width(ScreenBuffer.t()) :: non_neg_integer()
  defdelegate get_width(buffer), to: State

  @doc """
  Gets the current height of the screen buffer.
  """
  @spec get_height(ScreenBuffer.t()) :: non_neg_integer()
  defdelegate get_height(buffer), to: State

  @doc """
  Gets the dimensions {width, height} of the screen buffer.
  """
  @spec get_dimensions(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()}
  defdelegate get_dimensions(buffer), to: State

  @doc """
  Gets a specific line (list of Cells) from the buffer by index.
  Returns nil if index is out of bounds.
  """
  @spec get_line(ScreenBuffer.t(), non_neg_integer()) :: list(Cell.t()) | nil
  defdelegate get_line(buffer, line_index), to: State

  @doc """
  Gets a specific Cell from the buffer at {x, y}.
  Returns nil if coordinates are out of bounds.
  """
  @spec get_cell(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t() | nil
  defdelegate get_cell(buffer, x, y), to: State

  @doc """
  Calculates the difference between the current buffer state and a list of desired cell changes.
  Returns a list of {x, y, cell_map} tuples representing only the cells that need to be updated.
  Input `changes` must be a list of {x, y, map} tuples.
  """
  @spec diff(
          ScreenBuffer.t(),
          list({non_neg_integer(), non_neg_integer(), map()})
        ) :: list({non_neg_integer(), non_neg_integer(), map()})
  defdelegate diff(buffer, changes), to: Updater

  @doc """
  Updates the buffer state by applying a list of cell changes.
  Changes must be in the format {x, y, Cell.t() | map()}.
  Returns the updated buffer.
  """
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

  @doc """
  Clears the entire screen buffer (excluding scrollback) with empty cells.
  """
  @spec clear(ScreenBuffer.t(), Cell.Style.t() | nil) :: ScreenBuffer.t()
  defdelegate clear(buffer, style \\ TextFormatting.new()),
    to: Eraser,
    as: :clear_screen

  @doc """
  Inserts blank characters at the cursor position {x, y}, shifting existing chars right.
  Delegates to `CharEditor.insert_characters/5`.
  """
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

  @doc """
  Deletes characters at the cursor position {x, y}, shifting remaining chars left.
  Delegates to `CharEditor.delete_characters/5`.
  """
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

  @doc """
  Converts the screen buffer content to a plain text string.
  """
  @spec get_content(ScreenBuffer.t()) :: String.t()
  defdelegate get_content(buffer), to: State

  @doc """
  Gets the cell at the specified coordinates {x, y}.
  Returns nil if coordinates are out of bounds. Alias for get_cell/3.
  """
  @spec get_cell_at(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t() | nil
  defdelegate get_cell_at(buffer, x, y), to: State

  @doc """
  Clears a rectangular region of the buffer by replacing cells with empty cells.
  """
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

  @doc """
  Replaces the line at the given index with the provided list of cells.
  Returns the updated buffer.
  """
  @spec put_line(ScreenBuffer.t(), non_neg_integer(), list(Cell.t())) ::
          ScreenBuffer.t()
  defdelegate put_line(buffer, line_index, new_cells), to: State

  def clear_line(buffer, _y) do
    # TODO: Implement line clearing
    buffer
  end

  def clear_screen(buffer) do
    # TODO: Implement screen clearing
    buffer
  end

  def delete_lines(buffer, _, _, _, _), do: buffer

  @doc """
  Resizes the emulator's screen buffers.

  ## Parameters

  * `emulator` - The emulator to resize
  * `new_width` - New width in columns
  * `new_height` - New height in rows

  ## Returns

  Updated emulator with resized buffers
  """
  @spec resize(Emulator.t(), non_neg_integer(), non_neg_integer()) :: Emulator.t()
  def resize(%Emulator{} = emulator, new_width, new_height) do
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
  @spec maybe_scroll(Emulator.t()) :: Emulator.t()
  def maybe_scroll(%Emulator{} = emulator) do
    # Implementation will be moved from BufferManager
    emulator
  end

  @doc """
  Moves the cursor down one line (index operation).
  """
  @spec index(Emulator.t()) :: Emulator.t()
  def index(%Emulator{} = emulator) do
    {x, y} = get_cursor_position(emulator)
    new_y = y + 1

    # Check if we need to scroll
    if new_y >= emulator.height do
      maybe_scroll(emulator)
    else
      set_cursor_position(emulator, {x, new_y}, emulator.width, emulator.height)
    end
  end

  @doc """
  Moves the cursor to the next line.
  """
  @spec next_line(Emulator.t()) :: Emulator.t()
  def next_line(%Emulator{} = emulator) do
    {_x, _y} = get_cursor_position(emulator)
    # Implementation will be moved from emulator.ex
    emulator
  end

  @doc """
  Moves the cursor up one line (reverse index operation).
  """
  @spec reverse_index(Emulator.t()) :: Emulator.t()
  def reverse_index(%Emulator{} = emulator) do
    {x, y} = get_cursor_position(emulator)
    new_y = max(0, y - 1)
    set_cursor_position(emulator, {x, new_y}, emulator.width, emulator.height)
  end

  # Private helper functions

  defp get_cursor_position(%Emulator{cursor: cursor}), do: cursor.position

  defp set_cursor_position(emulator, position, width, height) do
    # This will be implemented to use CursorManager
    emulator
  end

  defp default_tab_stops(width) do
    # Generate tab stops every 8 columns
    for i <- 0..(width - 1), rem(i, 8) == 0, do: i
  end
end
