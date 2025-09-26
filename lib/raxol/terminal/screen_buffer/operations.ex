defmodule Raxol.Terminal.ScreenBuffer.Operations do
  @moduledoc """
  All buffer mutation operations.
  Consolidates: Operations, Ops, OperationsCached, Writer, Updater, CharEditor,
  LineOperations, Eraser, Content, Paste functionality.
  """

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ScreenBuffer.Core
  alias Raxol.Terminal.ScreenBuffer.SharedOperations
  alias Raxol.Terminal.CharacterHandling

  @doc """
  Writes a character at the specified position.
  """
  @spec write_char(
          Core.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map() | nil
        ) :: Core.t()
  def write_char(buffer, x, y, char, style \\ nil) do
    if Core.within_bounds?(buffer, x, y) do
      style = style || buffer.default_style
      char_width = CharacterHandling.get_char_width(char)

      # Check if we can fit a wide character (need space for placeholder)
      can_write_wide = char_width == 2 and Core.within_bounds?(buffer, x + 1, y)

      cell = Cell.new(char, style)

      new_cells =
        List.update_at(buffer.cells, y, fn row ->
          case {char_width, can_write_wide} do
            {2, true} ->
              # Write wide character + placeholder
              placeholder = Cell.new_wide_placeholder(style)

              row
              |> List.replace_at(x, cell)
              |> List.replace_at(x + 1, placeholder)

            _ ->
              # Write single-width character or wide char at edge
              List.replace_at(row, x, cell)
          end
        end)

      damage_width = if char_width == 2 and can_write_wide, do: 2, else: 1

      %{
        buffer
        | cells: new_cells,
          damage_regions:
            add_damage_region(buffer.damage_regions, x, y, damage_width, 1)
      }
    else
      buffer
    end
  end

  @doc """
  Writes a sixel graphics character at the specified position with the sixel flag set.
  """
  @spec write_sixel_char(
          Core.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map() | nil
        ) :: Core.t()
  def write_sixel_char(buffer, x, y, char, style \\ nil) do
    if Core.within_bounds?(buffer, x, y) do
      style = style || buffer.default_style
      cell = Raxol.Terminal.Cell.new_sixel(char, style)

      new_cells =
        List.update_at(buffer.cells, y, fn row ->
          List.replace_at(row, x, cell)
        end)

      %{
        buffer
        | cells: new_cells,
          damage_regions: add_damage_region(buffer.damage_regions, x, y, 1, 1)
      }
    else
      buffer
    end
  end

  @doc """
  Writes a string starting at the specified position.
  """
  @spec write_text(
          Core.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map() | nil
        ) :: Core.t()
  def write_text(buffer, x, y, text, style \\ nil) do
    style = style || buffer.default_style

    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, index}, acc ->
      write_x = x + index

      # Handle line wrapping
      if write_x >= acc.width do
        write_y = y + div(write_x, acc.width)
        write_x = rem(write_x, acc.width)
        write_char(acc, write_x, write_y, char, style)
      else
        write_char(acc, write_x, y, char, style)
      end
    end)
  end

  @doc """
  Inserts a character at the cursor position, shifting content right.
  """
  @spec insert_char(Core.t(), String.t(), map() | nil) :: Core.t()
  def insert_char(buffer, char, style \\ nil) do
    {x, y} = buffer.cursor_position

    updated_buffer =
      SharedOperations.insert_char_core_logic(buffer, x, y, char, style)

    # Add damage tracking if buffer was modified
    if updated_buffer != buffer do
      %{
        updated_buffer
        | damage_regions:
            add_damage_region(buffer.damage_regions, x, y, buffer.width - x, 1)
      }
    else
      buffer
    end
  end

  @doc """
  Inserts a character at the specified position.
  """
  @spec insert_char(Core.t(), non_neg_integer(), non_neg_integer(), String.t()) ::
          Core.t()
  def insert_char(buffer, x, y, char) do
    insert_char(buffer, x, y, char, nil)
  end

  @doc """
  Inserts a character at the specified position with style.
  """
  @spec insert_char(
          Core.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map() | nil
        ) :: Core.t()
  def insert_char(buffer, x, y, char, style) do
    updated_buffer =
      SharedOperations.insert_char_core_logic(buffer, x, y, char, style)

    # Add damage tracking if buffer was modified
    if updated_buffer != buffer do
      %{
        updated_buffer
        | damage_regions:
            add_damage_region(buffer.damage_regions, x, y, buffer.width - x, 1)
      }
    else
      buffer
    end
  end

  @doc """
  Writes a string starting at the specified position (alias for write_text).
  """
  @spec write_string(Core.t(), non_neg_integer(), non_neg_integer(), String.t()) ::
          Core.t()
  def write_string(buffer, x, y, string), do: write_text(buffer, x, y, string)

  @doc """
  Writes a string starting at the specified position with style.
  """
  @spec write_string(
          Core.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map()
        ) :: Core.t()
  def write_string(buffer, x, y, string, style),
    do: write_text(buffer, x, y, string, style)

  @doc """
  Deletes a character at the cursor position, shifting content left.
  """
  @spec delete_char(Core.t()) :: Core.t()
  def delete_char(buffer) do
    {x, y} = buffer.cursor_position

    if Core.within_bounds?(buffer, x, y) do
      new_cells =
        List.update_at(buffer.cells, y, fn row ->
          {before, after_} = Enum.split(row, x)

          case after_ do
            [] -> before
            [_ | rest] -> before ++ rest ++ [Cell.empty()]
          end
        end)

      %{
        buffer
        | cells: new_cells,
          damage_regions:
            add_damage_region(buffer.damage_regions, x, y, buffer.width - x, 1)
      }
    else
      buffer
    end
  end

  @doc """
  Clears a line.
  """
  @spec clear_line(Core.t(), non_neg_integer()) :: Core.t()
  def clear_line(buffer, y) when y >= 0 and y < buffer.height do
    new_cells = List.replace_at(buffer.cells, y, create_empty_row(buffer.width))

    %{
      buffer
      | cells: new_cells,
        damage_regions:
          add_damage_region(buffer.damage_regions, 0, y, buffer.width, 1)
    }
  end

  def clear_line(buffer, _y), do: buffer

  @doc """
  Clears from cursor to end of line.
  """
  @spec clear_to_end_of_line(Core.t()) :: Core.t()
  def clear_to_end_of_line(buffer) do
    {x, y} = buffer.cursor_position
    require Raxol.Core.Runtime.Log

    Raxol.Core.Runtime.Log.debug(
      "[Operations.clear_to_end_of_line] cursor at (#{x}, #{y}), clearing region (#{x}, #{y}, #{buffer.width - x}, 1)"
    )

    result = clear_region(buffer, x, y, buffer.width - x, 1)

    Raxol.Core.Runtime.Log.debug(
      "[Operations.clear_to_end_of_line] operation complete"
    )

    result
  end

  @doc """
  Clears from cursor to beginning of line.
  """
  @spec clear_to_beginning_of_line(Core.t()) :: Core.t()
  def clear_to_beginning_of_line(buffer) do
    {x, y} = buffer.cursor_position
    clear_region(buffer, 0, y, x + 1, 1)
  end

  @doc """
  Clears from cursor to end of screen.
  """
  @spec clear_to_end_of_screen(Core.t()) :: Core.t()
  def clear_to_end_of_screen(buffer) do
    {_x, y} = buffer.cursor_position

    # Clear from cursor to end of current line
    buffer = clear_to_end_of_line(buffer)

    # Clear all lines below
    Enum.reduce((y + 1)..(buffer.height - 1), buffer, fn line_y, acc ->
      clear_line(acc, line_y)
    end)
  end

  @doc """
  Clears from cursor to beginning of screen.
  """
  @spec clear_to_beginning_of_screen(Core.t()) :: Core.t()
  def clear_to_beginning_of_screen(buffer) do
    {_x, y} = buffer.cursor_position

    # Clear from cursor to beginning of current line
    buffer = clear_to_beginning_of_line(buffer)

    # Clear all lines above
    Enum.reduce(0..(y - 1), buffer, fn line_y, acc ->
      clear_line(acc, line_y)
    end)
  end

  @doc """
  Clears a rectangular region.
  """
  @spec clear_region(
          Core.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Core.t()
  def clear_region(buffer, x, y, width, height) do
    x_end = min(x + width, buffer.width)
    y_end = min(y + height, buffer.height)

    new_cells =
      buffer.cells
      |> Enum.with_index()
      |> Enum.map(fn {row, row_y} ->
        if row_y >= y and row_y < y_end do
          row
          |> Enum.with_index()
          |> Enum.map(fn {cell, col_x} ->
            if col_x >= x and col_x < x_end do
              Cell.empty()
            else
              cell
            end
          end)
        else
          row
        end
      end)

    %{
      buffer
      | cells: new_cells,
        damage_regions:
          add_damage_region(buffer.damage_regions, x, y, width, height)
    }
  end

  @doc """
  Inserts a blank line at the specified position.
  """
  @spec insert_line(Core.t(), non_neg_integer()) :: Core.t()
  def insert_line(buffer, y) when y >= 0 and y < buffer.height do
    empty_line = create_empty_row(buffer.width)

    {before, after_} = Enum.split(buffer.cells, y)

    new_cells =
      before ++ [empty_line] ++ Enum.take(after_, buffer.height - y - 1)

    %{
      buffer
      | cells: new_cells,
        damage_regions:
          add_damage_region(
            buffer.damage_regions,
            0,
            y,
            buffer.width,
            buffer.height - y
          )
    }
  end

  def insert_line(buffer, _y), do: buffer

  @doc """
  Deletes a line at the specified position.
  """
  @spec delete_line(Core.t(), non_neg_integer()) :: Core.t()
  def delete_line(buffer, y) when y >= 0 and y < buffer.height do
    {before, after_} = Enum.split(buffer.cells, y)

    new_cells =
      case after_ do
        [] -> before ++ [create_empty_row(buffer.width)]
        [_ | rest] -> before ++ rest ++ [create_empty_row(buffer.width)]
      end

    %{
      buffer
      | cells: new_cells,
        damage_regions:
          add_damage_region(
            buffer.damage_regions,
            0,
            y,
            buffer.width,
            buffer.height - y
          )
    }
  end

  def delete_line(buffer, _y), do: buffer

  @doc """
  Fills a region with a character.
  """
  @spec fill_region(
          Core.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map() | nil
        ) :: Core.t()
  def fill_region(buffer, x, y, width, height, char, style \\ nil) do
    Enum.reduce(y..(y + height - 1), buffer, fn row_y, acc ->
      Enum.reduce(x..(x + width - 1), acc, fn col_x, acc2 ->
        write_char(acc2, col_x, row_y, char, style)
      end)
    end)
  end

  @doc """
  Copies a region to another location.
  """
  @spec copy_region(
          Core.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: Core.t()
  def copy_region(buffer, src_x, src_y, width, height, dest_x, dest_y) do
    # Extract the region
    region =
      for dy <- 0..(height - 1) do
        for dx <- 0..(width - 1) do
          Core.get_cell(buffer, src_x + dx, src_y + dy) || Cell.empty()
        end
      end

    # Write the region to destination
    region
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {row, dy}, acc ->
      row
      |> Enum.with_index()
      |> Enum.reduce(acc, fn {cell, dx}, acc2 ->
        if Core.within_bounds?(acc2, dest_x + dx, dest_y + dy) do
          new_cells =
            List.update_at(acc2.cells, dest_y + dy, fn row ->
              List.replace_at(row, dest_x + dx, cell)
            end)

          %{acc2 | cells: new_cells}
        else
          acc2
        end
      end)
    end)
    |> Map.update!(
      :damage_regions,
      &add_damage_region(&1, dest_x, dest_y, width, height)
    )
  end

  # Private helper functions

  defp create_empty_row(width) do
    List.duplicate(Cell.empty(), width)
  end

  defp add_damage_region(regions, x, y, width, height) do
    new_region = {x, y, x + width - 1, y + height - 1}
    merge_damage_regions([new_region | regions])
  end

  defp merge_damage_regions(regions) do
    # Simple implementation - could be optimized
    # For now, just keep last 10 regions
    Enum.take(regions, 10)
  end

  @doc """
  Puts a line of cells at the specified y position.
  Used by scrolling operations and for backward compatibility.
  """
  @spec put_line(Core.t(), non_neg_integer(), list(Cell.t())) :: Core.t()
  def put_line(buffer, y, line) when y >= 0 and y < buffer.height do
    # Ensure line is correct width
    line =
      cond do
        length(line) > buffer.width ->
          Enum.take(line, buffer.width)

        length(line) < buffer.width ->
          line ++ List.duplicate(Cell.new(), buffer.width - length(line))

        true ->
          line
      end

    new_cells = List.replace_at(buffer.cells, y, line)

    %{
      buffer
      | cells: new_cells,
        damage_regions:
          add_damage_region(buffer.damage_regions, 0, y, buffer.width, 1)
    }
  end

  def put_line(buffer, _y, _line), do: buffer

  # === Stub Implementations for Test Compatibility ===
  # These functions are referenced by delegations but not critical for core functionality

  @doc """
  Clears a line (stub).
  """
  @spec clear_line(Core.t(), non_neg_integer(), atom()) :: Core.t()
  def clear_line(buffer, _y, _mode), do: buffer

  @doc """
  Deletes characters at cursor position.
  """
  @spec delete_chars(Core.t(), non_neg_integer()) :: Core.t()
  def delete_chars(buffer, count) do
    alias Raxol.Terminal.Buffer.LineOperations
    LineOperations.delete_chars(buffer, count)
  end

  @doc """
  Deletes lines (stub with 2 args).
  """
  @spec delete_lines(Core.t(), non_neg_integer()) :: Core.t()
  def delete_lines(buffer, _count), do: buffer

  @doc """
  Deletes lines in region (stub with 5 args).
  """
  @spec delete_lines(Core.t(), integer(), integer(), integer(), integer()) ::
          Core.t()
  def delete_lines(buffer, _x1, _y1, _x2, _y2), do: buffer

  @doc """
  Erases characters (stub with 2 args).
  """
  @spec erase_chars(Core.t(), non_neg_integer()) :: Core.t()
  def erase_chars(buffer, count) do
    {x, y} = buffer.cursor_position

    case y < buffer.height and x < buffer.width do
      true ->
        line = Enum.at(buffer.cells, y, [])
        empty_cell = Cell.empty()

        # Erase count characters starting at x - delete them and shift content left
        {before, after_x} = Enum.split(line, x)
        {_erased, remaining} = Enum.split(after_x, count)
        # Pad at end to maintain line width
        erased_count = length(after_x) - length(remaining)
        padding = List.duplicate(empty_cell, erased_count)
        new_line = before ++ remaining ++ padding

        new_cells = List.replace_at(buffer.cells, y, new_line)

        %{
          buffer
          | cells: new_cells,
            damage_regions:
              add_damage_region(buffer.damage_regions, x, y, count, 1)
        }

      false ->
        buffer
    end
  end

  @doc """
  Erases characters at position (stub with 4 args).
  """
  @spec erase_chars(Core.t(), integer(), integer(), non_neg_integer()) ::
          Core.t()
  def erase_chars(buffer, _x, _y, _count), do: buffer

  @doc """
  Erases display (stub).
  """
  @spec erase_display(Core.t(), atom()) :: Core.t()
  def erase_display(buffer, _mode), do: buffer

  @doc """
  Erases line (stub with 2 args).
  """
  @spec erase_line(Core.t(), atom()) :: Core.t()
  def erase_line(buffer, _mode), do: buffer

  @doc """
  Erases line at position (stub with 3 args).
  """
  @spec erase_line(Core.t(), non_neg_integer(), atom()) :: Core.t()
  def erase_line(buffer, _y, _mode), do: buffer

  @doc """
  Gets scroll region (stub).
  """
  @spec get_region(Core.t()) :: {integer(), integer()} | nil
  def get_region(buffer), do: buffer.scroll_region

  @doc """
  Inserts spaces at cursor position, shifting content to the right.
  Cursor remains at its original position after the operation.
  """
  @spec insert_chars(Core.t(), non_neg_integer()) :: Core.t()
  def insert_chars(buffer, count) when count > 0 do
    {x, y} = buffer.cursor_position

    case Core.within_bounds?(buffer, x, y) do
      false ->
        buffer

      true ->
        # Get the current row
        row = Enum.at(buffer.cells, y, [])

        # Split the row at cursor position
        {before_cursor, at_and_after} = Enum.split(row, x)

        # Create spaces to insert
        spaces =
          Enum.map(1..count, fn _ ->
            %Cell{char: " ", style: buffer.default_style}
          end)

        # Reconstruct row: before + spaces + shifted content (truncated to width)
        new_row =
          (before_cursor ++
             spaces ++ Enum.take(at_and_after, buffer.width - x - count))
          # Ensure we don't exceed buffer width
          |> Enum.take(buffer.width)

        # Update cells
        new_cells = List.replace_at(buffer.cells, y, new_row)

        # Return buffer with updated cells and damage region
        # IMPORTANT: Do not update cursor_position - it stays where it was
        %{
          buffer
          | cells: new_cells,
            damage_regions:
              add_damage_region(
                buffer.damage_regions,
                x,
                y,
                buffer.width - x,
                1
              )
        }
    end
  end

  def insert_chars(buffer, _count), do: buffer

  @doc """
  Inserts lines at cursor position (stub with 2 args).
  """
  @spec insert_lines(Core.t(), non_neg_integer()) :: Core.t()
  def insert_lines(buffer, _count), do: buffer

  @doc """
  Inserts lines in region (stub with 4 args).
  """
  @spec insert_lines(Core.t(), integer(), integer(), non_neg_integer()) ::
          Core.t()
  def insert_lines(buffer, _x, _y, _count), do: buffer

  @doc """
  Inserts lines in region with style (stub with 5 args).
  """
  @spec insert_lines(Core.t(), integer(), integer(), non_neg_integer(), map()) ::
          Core.t()
  def insert_lines(buffer, _x, _y, _count, _style), do: buffer

  @doc """
  Prepends lines to buffer.
  """
  @spec prepend_lines(Core.t(), integer()) :: Core.t()
  def prepend_lines(buffer, count) when is_integer(count) do
    alias Raxol.Terminal.Buffer.LineOperations
    LineOperations.prepend_lines(buffer, count)
  end

  @spec prepend_lines(Core.t(), list()) :: Core.t()
  def prepend_lines(buffer, lines) when is_list(lines) do
    alias Raxol.Terminal.Buffer.LineOperations
    LineOperations.prepend_lines(buffer, lines)
  end

  @doc """
  Scrolls content down (stub).
  """
  @spec scroll_down(Core.t(), non_neg_integer()) :: Core.t()
  def scroll_down(buffer, _count), do: buffer

  @doc """
  Scrolls content up (stub).
  """
  @spec scroll_up(Core.t(), non_neg_integer()) :: Core.t()
  def scroll_up(buffer, _count), do: buffer

  @doc """
  Scrolls to position (stub).
  """
  @spec scroll_to(Core.t(), integer(), integer(), map()) :: Core.t()
  def scroll_to(buffer, _x, _y, _opts), do: buffer

  @doc """
  Sets scroll region (stub).
  """
  @spec set_region(Core.t(), integer(), integer()) :: Core.t()
  def set_region(buffer, top, bottom) do
    %{buffer | scroll_region: {top, bottom}}
  end

  @doc """
  Shifts region to line (stub).
  """
  @spec shift_region_to_line(Core.t(), integer(), integer()) :: Core.t()
  def shift_region_to_line(buffer, _from_line, _to_line), do: buffer
end
