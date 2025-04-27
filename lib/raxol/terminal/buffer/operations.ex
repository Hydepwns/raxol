defmodule Raxol.Terminal.Buffer.Operations do
  @moduledoc """
  Provides functions for manipulating the Raxol.Terminal.ScreenBuffer grid and state.
  Includes writing, clearing, deleting, inserting, resizing, and other operations.
  """

  require Logger

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.CharacterHandling
  alias Raxol.Terminal.ANSI.TextFormatting
  # Needed for scroll functions
  # alias Raxol.Terminal.Buffer.Scrollback

  @doc """
  Writes a character to the buffer at the specified position.
  Handles wide characters by taking up two cells when necessary.
  Accepts an optional style to apply to the cell.
  """
  # Suppress spurious exact_eq warning
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
      width = CharacterHandling.get_char_width(char)
      cell_style = style || %{}

      cells =
        List.update_at(buffer.cells, y, fn row ->
          new_cell = Cell.new(char, cell_style)

          if width == 2 and x + 1 < buffer.width do
            row
            |> List.update_at(x, fn _ -> new_cell end)
            |> List.update_at(x + 1, fn _ ->
              Cell.new_wide_placeholder(cell_style)
            end)
          else
            List.update_at(row, x, fn _ -> new_cell end)
          end
        end)

      %{buffer | cells: cells}
    else
      buffer
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
    segments = CharacterHandling.process_bidi_text(string)

    Enum.reduce(segments, {buffer, x}, fn {_type, segment},
                                          {acc_buffer, acc_x} ->
      {new_buffer, new_x} = write_segment(acc_buffer, acc_x, y, segment)
      {new_buffer, new_x}
    end)
    |> elem(0)
  end

  # Silence potential spurious no_return warning
  @dialyzer {:nowarn_function, write_segment: 4}
  @spec write_segment(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t()
        ) ::
          {ScreenBuffer.t(), non_neg_integer()}
  defp write_segment(buffer, x, y, segment) do
    Enum.reduce(String.graphemes(segment), {buffer, x}, fn char,
                                                           {acc_buffer, acc_x} ->
      width = CharacterHandling.get_char_width(char)

      if acc_x + width <= acc_buffer.width do
        {write_char(acc_buffer, acc_x, y, char), acc_x + width}
      else
        {acc_buffer, acc_x}
      end
    end)
  end

  @doc """
  Scrolls the buffer up by the specified number of lines, optionally within a specified scroll region.
  Handles cell manipulation.
  Returns `{updated_cells, scrolled_off_lines}`.
  """
  @spec scroll_up(
          ScreenBuffer.t(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: {list(list(Cell.t())), list(list(Cell.t()))}
  def scroll_up(%ScreenBuffer{} = buffer, lines, scroll_region \\ nil)
      when lines > 0 do
    effective_scroll_region = scroll_region || buffer.scroll_region
    buffer_with_region = %{buffer | scroll_region: effective_scroll_region}

    {scroll_start, scroll_end} =
      get_scroll_region_boundaries(buffer_with_region)

    visible_lines = scroll_end - scroll_start + 1

    if lines >= visible_lines do
      # If scrolling more than region size, clear region and return all old lines
      {scroll_start, scroll_end} =
        get_scroll_region_boundaries(%{buffer | scroll_region: effective_scroll_region})
      scrolled_off_lines = Enum.slice(buffer.cells, scroll_start..scroll_end)
      empty_region_cells = List.duplicate(List.duplicate(Cell.new(), buffer.width), visible_lines)
      updated_cells = replace_region_content(buffer.cells, scroll_start, scroll_end, empty_region_cells)
      {updated_cells, scrolled_off_lines}
    else
      scroll_region_lines = Enum.slice(buffer.cells, scroll_start..scroll_end)
      {scrolled_lines, remaining_lines} = Enum.split(scroll_region_lines, lines)

      empty_lines =
        List.duplicate(List.duplicate(Cell.new(), buffer.width), lines)

      new_region_content = remaining_lines ++ empty_lines

      # Return updated cells grid and the lines scrolled off
      updated_cells = replace_region_content(buffer.cells, scroll_start, scroll_end, new_region_content)
      {updated_cells, scrolled_lines}
    end
  end

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
  def scroll_down(%ScreenBuffer{} = buffer, lines_to_insert, lines, scroll_region \\ nil)
      when lines > 0 do
    effective_scroll_region = scroll_region || buffer.scroll_region
    buffer_with_region = %{buffer | scroll_region: effective_scroll_region}

    {scroll_start, scroll_end} =
      get_scroll_region_boundaries(buffer_with_region)

    visible_lines = scroll_end - scroll_start + 1

    if lines >= visible_lines do
      # If scrolling more than region size, clear region (no lines inserted)
      empty_region_cells = List.duplicate(List.duplicate(Cell.new(), buffer.width), visible_lines)
      updated_cells = replace_region_content(buffer.cells, scroll_start, scroll_end, empty_region_cells)
      %{buffer | cells: updated_cells}
    else
      # Only proceed if we actually have lines to insert
      if lines_to_insert != [] do
        # Ensure we don't insert more lines than requested/available space
        actual_lines_to_insert = Enum.take(lines_to_insert, lines)

        scroll_region_lines = Enum.slice(buffer.cells, scroll_start..scroll_end)
        # Drop lines from the end to make space
        shifted_lines = Enum.drop(scroll_region_lines, -length(actual_lines_to_insert))
        new_region_content = actual_lines_to_insert ++ shifted_lines

        updated_cells = replace_region_content(buffer.cells, scroll_start, scroll_end, new_region_content)
        %{buffer | cells: updated_cells}
      else
        # No lines provided from scrollback, buffer remains unchanged
        buffer
      end
    end
  end

  # Helper to clear a scroll region (internal)
  defp clear_scroll_region(
         %ScreenBuffer{} = buffer,
         cells, # Pass cells grid explicitly
         scroll_start,
         scroll_end,
         visible_lines
       ) do
    empty_region =
      List.duplicate(List.duplicate(Cell.new(), buffer.width), visible_lines)
    # Returns only the updated cells grid
    replace_region_content(cells, scroll_start, scroll_end, empty_region)
  end

  # Helper to replace content within a scroll region (internal)
  # Operates directly on the cells list, returns the updated list.
  defp replace_region_content(current_cells, scroll_start, scroll_end, new_content) do
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

    new_cells =
      List.duplicate(List.duplicate(Cell.new(), new_width), new_height)

    max_y_copy = min(old_height, new_height)
    max_x_copy = min(old_width, new_width)

    copied_cells =
      Enum.reduce(0..(max_y_copy - 1), new_cells, fn y, acc_new_cells ->
        # Keep top content on shrink
        old_row_index = y

        if old_row_index >= 0 and old_row_index < old_height do
          old_row = Enum.at(buffer.cells, old_row_index)
          new_row = Enum.at(acc_new_cells, y)

          updated_new_row =
            Enum.reduce(0..(max_x_copy - 1), new_row, fn x, acc_new_row ->
              if old_row do
                old_cell = Enum.at(old_row, x)
                List.replace_at(acc_new_row, x, old_cell)
              else
                acc_new_row
              end
            end)

          List.replace_at(acc_new_cells, y, updated_new_row)
        else
          acc_new_cells
        end
      end)

    %{
      buffer
      | cells: copied_cells,
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
  Clears a rectangular region of the buffer by replacing cells with empty cells.
  """
  @spec clear_region(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def clear_region(%ScreenBuffer{} = buffer, start_x, start_y, end_x, end_y) do
    Enum.reduce(start_y..end_y, buffer, fn y, acc_buffer ->
      if y >= 0 and y < acc_buffer.height do
        row = Enum.at(acc_buffer.cells, y)

        new_row =
          Enum.reduce(start_x..end_x, row, fn x, acc_row ->
            if x >= 0 and x < acc_buffer.width do
              List.replace_at(acc_row, x, Cell.new())
            else
              acc_row
            end
          end)

        %{
          acc_buffer
          | cells: List.update_at(acc_buffer.cells, y, fn _ -> new_row end)
        }
      else
        acc_buffer
      end
    end)
  end

  @doc """
  Deletes `n` lines starting from `start_y` within the scroll region.
  Lines below are shifted up, blank lines added at the bottom of the region.
  """
  @spec delete_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: ScreenBuffer.t()
  def delete_lines(%ScreenBuffer{} = buffer, start_y, n, scroll_region)
      when n > 0 do
    {scroll_start, scroll_end} =
      get_scroll_region_boundaries(%{
        buffer
        | scroll_region: scroll_region || buffer.scroll_region
      })

    if start_y < scroll_start or start_y > scroll_end do
      buffer
    else
      visible_lines = scroll_end - scroll_start + 1
      lines_to_delete = min(n, scroll_end - start_y + 1)

      if lines_to_delete == 0 do
        buffer
      else
        scroll_region_cells = Enum.slice(buffer.cells, scroll_start..scroll_end)
        relative_start_y = start_y - scroll_start

        {before_deleted, rest} =
          Enum.split(scroll_region_cells, relative_start_y)

        {_deleted_lines, after_deleted} = Enum.split(rest, lines_to_delete)

        blank_lines =
          List.duplicate(
            List.duplicate(Cell.new(), buffer.width),
            lines_to_delete
          )

        new_region_content = before_deleted ++ after_deleted ++ blank_lines
        new_region_content = Enum.take(new_region_content, visible_lines)

        clear_scroll_region(
          buffer,
          scroll_start,
          scroll_end,
          new_region_content,
          buffer.scrollback
        )
      end
    end
  end

  # No-op if n is not positive
  def delete_lines(buffer, _, n, _) when n <= 0, do: buffer

  @doc """
  Gets the cell at the specified coordinates {x, y}.
  Returns nil if coordinates are out of bounds. Alias for get_cell/3.
  """
  @spec get_cell_at(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          Cell.t() | nil
  def get_cell_at(buffer, x, y), do: get_cell(buffer, x, y)

  @doc """
  Calculates the difference between the current buffer state and a list of desired cell changes.
  Returns a list of {x, y, cell_map} tuples representing only the cells that need to be updated.
  Input `changes` must be a list of {x, y, map} tuples.
  """
  @spec diff(
          ScreenBuffer.t(),
          list({non_neg_integer(), non_neg_integer(), map()})
        ) :: list({non_neg_integer(), non_neg_integer(), map()})
  def diff(%ScreenBuffer{} = buffer, changes) when is_list(changes) do
    # Ensure changes are in the expected {x, y, map} format
    if Enum.empty?(changes) or match?([{_, _, _} | _], changes) do
      Enum.filter(changes, fn {x, y, desired_cell_map} ->
        current_cell_struct = get_cell_at(buffer, x, y)
        # Convert map for comparison
        desired_cell_struct = Cell.from_map(desired_cell_map)

        case {desired_cell_struct, current_cell_struct} do
          # Invalid desired cell map
          {nil, _} -> false
          # Current cell doesn't exist (e.g., outside buffer), needs update if desired is valid
          {_, nil} -> true
          {desired, current} -> not Cell.equals?(current, desired)
        end
      end)
    else
      Logger.warning(
        "Invalid format passed to ScreenBuffer.Operations.diff/2. Expected list of {x, y, map}. Got: #{inspect(changes)}"
      )

      # Return empty list for invalid input format
      []
    end
  end

  @doc """
  Updates the buffer state by applying a list of cell changes.
  Changes must be in the format {x, y, Cell.t() | map()}.
  Returns the updated buffer.
  """
  @spec update(
          ScreenBuffer.t(),
          list({non_neg_integer(), non_neg_integer(), Cell.t() | map()})
        ) :: ScreenBuffer.t()
  def update(%ScreenBuffer{} = buffer, changes) when is_list(changes) do
    Enum.reduce(changes, buffer, fn
      {x, y, %Cell{} = cell}, acc_buffer when is_integer(x) and is_integer(y) ->
        apply_cell_update(acc_buffer, x, y, cell)

      {x, y, cell_map}, acc_buffer
      when is_integer(x) and is_integer(y) and is_map(cell_map) ->
        case Cell.from_map(cell_map) do
          nil ->
            Logger.warning(
              "[ScreenBuffer.Operations.update] Failed to convert cell map: #{inspect(cell_map)} at (#{x}, #{y})"
            )

            acc_buffer

          cell_struct ->
            apply_cell_update(acc_buffer, x, y, cell_struct)
        end

      invalid_change, acc_buffer ->
        Logger.warning(
          "[ScreenBuffer.Operations.update] Invalid change format: #{inspect(invalid_change)}"
        )

        acc_buffer
    end)
  end

  # Helper for applying a single cell update, handling wide chars
  defp apply_cell_update(%ScreenBuffer{} = buffer, x, y, %Cell{} = cell) do
    if y >= 0 and y < buffer.height and x >= 0 and x < buffer.width do
      is_wide =
        CharacterHandling.get_char_width(cell.char) == 2 and
          not cell.is_wide_placeholder

      new_cells =
        List.update_at(buffer.cells, y, fn row ->
          row_with_primary = List.replace_at(row, x, cell)

          if is_wide and x + 1 < buffer.width do
            List.replace_at(
              row_with_primary,
              x + 1,
              Cell.new_wide_placeholder(cell.style)
            )
          else
            row_with_primary
          end
        end)

      %{buffer | cells: new_cells}
    else
      # Ignore updates outside bounds
      buffer
    end
  end

  @doc """
  Erases parts of the display based on cursor position (:to_end, :to_beginning, :all).
  Requires cursor state {x, y}.
  """
  @spec erase_in_display(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          atom()
        ) :: ScreenBuffer.t()
  def erase_in_display(%ScreenBuffer{} = buffer, {cursor_x, cursor_y}, type) do
    blank_cell = Cell.new()

    case type do
      :to_end ->
        buffer_after_line_erase =
          erase_line_part(
            buffer,
            cursor_y,
            cursor_x,
            buffer.width - 1,
            blank_cell
          )

        Enum.reduce(
          (cursor_y + 1)..(buffer.height - 1),
          buffer_after_line_erase,
          fn y, acc_buffer ->
            erase_line_part(acc_buffer, y, 0, buffer.width - 1, blank_cell)
          end
        )

      :to_beginning ->
        buffer_after_line_erase =
          erase_line_part(buffer, cursor_y, 0, cursor_x, blank_cell)

        Enum.reduce(0..(cursor_y - 1), buffer_after_line_erase, fn y,
                                                                   acc_buffer ->
          erase_line_part(acc_buffer, y, 0, buffer.width - 1, blank_cell)
        end)

      :all ->
        %{
          buffer
          | cells:
              List.duplicate(
                List.duplicate(blank_cell, buffer.width),
                buffer.height
              )
        }

      _ ->
        buffer
    end
  end

  @doc """
  Erases parts of the current line based on cursor position (:to_end, :to_beginning, :all).
  Requires cursor state {x, y}.
  """
  @spec erase_in_line(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          atom()
        ) :: ScreenBuffer.t()
  def erase_in_line(%ScreenBuffer{} = buffer, {cursor_x, cursor_y}, type) do
    blank_cell = Cell.new()

    case type do
      :to_end ->
        erase_line_part(
          buffer,
          cursor_y,
          cursor_x,
          buffer.width - 1,
          blank_cell
        )

      :to_beginning ->
        erase_line_part(buffer, cursor_y, 0, cursor_x, blank_cell)

      :all ->
        erase_line_part(buffer, cursor_y, 0, buffer.width - 1, blank_cell)

      _ ->
        buffer
    end
  end

  # Helper to erase part of a single line (internal)
  defp erase_line_part(%ScreenBuffer{} = buffer, y, start_x, end_x, fill_cell) do
    if y >= 0 and y < buffer.height do
      start_col = max(0, start_x)
      end_col = min(buffer.width - 1, end_x)

      if start_col <= end_col do
        new_cells =
          List.update_at(buffer.cells, y, fn row ->
            Enum.reduce(start_col..end_col, row, fn x, acc_row ->
              List.replace_at(acc_row, x, fill_cell)
            end)
          end)

        %{buffer | cells: new_cells}
      else
        buffer
      end
    else
      buffer
    end
  end

  @doc """
  Clears the entire screen buffer (excluding scrollback) with empty cells.
  """
  @spec clear(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear(%ScreenBuffer{width: width, height: height} = buffer) do
    new_cells = List.duplicate(List.duplicate(Cell.new(), width), height)
    %{buffer | cells: new_cells}
  end

  @doc """
  Inserts blank characters at the cursor position {x, y}, shifting existing chars right.
  """
  @spec insert_characters(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer(),
          TextFormatting.text_style() | nil
        ) :: ScreenBuffer.t()
  def insert_characters(buffer, pos, count, style \\ nil)

  def insert_characters(%ScreenBuffer{} = buffer, {x, y}, count, style)
      when y >= 0 and y < buffer.height and x >= 0 and x < buffer.width and
             count > 0 do
    blank_cell = Cell.new(" ", style || %{})
    blanks_to_insert = List.duplicate(blank_cell, count)

    new_cells =
      List.update_at(buffer.cells, y, fn row ->
        {prefix, suffix} = Enum.split(row, x)
        remaining_suffix_length = max(0, buffer.width - x - count)
        new_suffix = Enum.take(suffix, remaining_suffix_length)
        prefix ++ blanks_to_insert ++ new_suffix
      end)

    %{buffer | cells: new_cells}
  end

  # No-op if count is not positive
  def insert_characters(buffer, _, count, _) when count <= 0, do: buffer
  # No-op if y is out of bounds
  def insert_characters(buffer, {_, y}, _, _) when y < 0 or y >= buffer.height,
    do: buffer

  # No-op if x is out of bounds
  def insert_characters(buffer, {x, _}, _, _) when x < 0 or x >= buffer.width,
    do: buffer

  @doc """
  Deletes characters at the cursor position {x, y}, shifting remaining chars left.
  """
  @spec delete_characters(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def delete_characters(%ScreenBuffer{} = buffer, {x, y}, count)
      when y >= 0 and y < buffer.height and x >= 0 and x < buffer.width and
             count > 0 do
    blank_cell = Cell.new()

    new_cells =
      List.update_at(buffer.cells, y, fn row ->
        {prefix, rest} = Enum.split(row, x)
        suffix_to_keep = Enum.drop(rest, max(0, count))

        blanks_needed =
          max(0, buffer.width - length(prefix) - length(suffix_to_keep))

        trailing_blanks = List.duplicate(blank_cell, blanks_needed)
        prefix ++ suffix_to_keep ++ trailing_blanks
      end)

    %{buffer | cells: new_cells}
  end

  # No-op if count is not positive
  def delete_characters(buffer, _, count) when count <= 0, do: buffer
  # No-op if y is out of bounds
  def delete_characters(buffer, {_, y}, _) when y < 0 or y >= buffer.height,
    do: buffer

  # No-op if x is out of bounds
  def delete_characters(buffer, {x, _}, _) when x < 0 or x >= buffer.width,
    do: buffer

  @doc """
  Inserts `n` blank lines at `start_y` within the scroll region, shifting lines down.
  """
  @spec insert_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: ScreenBuffer.t()
  def insert_lines(%ScreenBuffer{} = buffer, start_y, n, scroll_region)
      when start_y >= 0 and n > 0 do
    {scroll_start, scroll_end} =
      get_scroll_region_boundaries(%{
        buffer
        | scroll_region: scroll_region || buffer.scroll_region
      })

    visible_lines_in_region = scroll_end - scroll_start + 1

    if start_y >= scroll_start and start_y <= scroll_end do
      blank_line = List.duplicate(Cell.new(), buffer.width)
      blank_lines_to_insert = List.duplicate(blank_line, n)
      scroll_region_cells = Enum.slice(buffer.cells, scroll_start..scroll_end)
      relative_insert_y = start_y - scroll_start

      {lines_before_insert, lines_at_and_after_insert} =
        Enum.split(scroll_region_cells, relative_insert_y)

      lines_to_keep_count =
        max(0, visible_lines_in_region - length(lines_before_insert) - n)

      lines_to_keep = Enum.take(lines_at_and_after_insert, lines_to_keep_count)

      new_region_content =
        lines_before_insert ++ blank_lines_to_insert ++ lines_to_keep

      new_region_content =
        Enum.take(new_region_content, visible_lines_in_region)

      clear_scroll_region(
        buffer,
        scroll_start,
        scroll_end,
        new_region_content,
        buffer.scrollback
      )
    else
      buffer
    end
  end

  def insert_lines(buffer, _, n, _) when n <= 0, do: buffer
  def insert_lines(buffer, start_y, _, _) when start_y < 0, do: buffer

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
