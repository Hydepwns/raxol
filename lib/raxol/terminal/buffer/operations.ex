defmodule Raxol.Terminal.Buffer.Operations do
  @moduledoc """
  Provides functions for manipulating the Raxol.Terminal.ScreenBuffer grid and state.
  Includes writing, clearing, deleting, inserting, resizing, and other operations.
  """

  require Logger

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Buffer.Writer
  alias Raxol.Terminal.Buffer.Eraser
  alias Raxol.Terminal.Buffer.Scroller
  alias Raxol.Terminal.Buffer.Updater
  alias Raxol.Terminal.Buffer.State
  alias Raxol.Terminal.Buffer.CharEditor
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
  @doc false
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
  @doc false
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
end
