defmodule Raxol.Terminal.Buffer.LineOperations.Deletion do
  @moduledoc """
  Handles line deletion operations for the screen buffer.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Deletes a specified number of lines starting from the current cursor position.
  Lines below the deleted lines are shifted up, and blank lines are added at the bottom.
  """
  @spec delete_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def delete_lines(buffer, count) when is_integer(count) and count > 0 do
    {_x, y} = buffer.cursor_position

    {top, bottom} =
      Raxol.Terminal.ScreenBuffer.ScrollRegion.get_boundaries(
        buffer.scroll_region
      )

    # Only delete lines within the scroll region
    in_scroll_region = y >= top and y <= bottom
    handle_delete_lines_in_region(in_scroll_region, buffer, y, count)
  end

  @doc """
  Deletes a specified number of lines with explicit parameters.
  """
  def delete_lines(
        buffer,
        count,
        cursor_y,
        _cursor_x,
        scroll_top,
        scroll_bottom
      ) do
    in_scroll_region = cursor_y >= scroll_top and cursor_y <= scroll_bottom
    handle_delete_lines_with_cursor(in_scroll_region, buffer, cursor_y, count)
  end

  @doc """
  Deletes lines at a specific position.
  """
  @spec delete_lines(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def delete_lines(buffer, position, count) do
    valid_position =
      position >= 0 and position < length(buffer.cells) and count > 0

    handle_delete_at_position(valid_position, buffer, position, count)
  end

  @doc """
  Deletes lines at a specific position with style and region boundaries.
  """
  @spec delete_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style(),
          {non_neg_integer(), non_neg_integer()}
        ) ::
          ScreenBuffer.t()
  def delete_lines(buffer, y, count, style, {top, bottom}) do
    valid_deletion = y >= top and y <= bottom and count > 0
    handle_styled_deletion(valid_deletion, buffer, y, count, style, top, bottom)
  end

  def delete_lines(buffer, _y, _count, _style, region)
      when not is_tuple(region),
      do: buffer

  @doc """
  Deletes lines at the specified position within the scroll region.
  """
  def delete_lines_in_region(buffer, lines, y, top, bottom) do
    # Only operate if cursor is within the scroll region
    in_region = y >= top and y <= bottom

    handle_delete_lines_in_scroll_region(
      in_region,
      buffer,
      lines,
      y,
      top,
      bottom
    )
  end

  defp do_delete_lines_in_region(buffer, y, count, style, top, bottom) do
    # Split buffer into parts: before region, region, after region
    {before_region, rest} = Enum.split(buffer.cells, top)
    {region, after_region} = Enum.split(rest, bottom - top + 1)

    # Calculate relative position within the region
    rel_y = y - top

    # Split region at cursor position
    {region_before_cursor, region_at_and_after_cursor} =
      Enum.split(region, rel_y)

    # Remove the lines to be deleted
    region_after_deleted = Enum.drop(region_at_and_after_cursor, count)

    # Create blank lines to add at the bottom of the region
    blank_lines = create_empty_lines(buffer.width, count, style)

    # Reassemble the region: before cursor + after deleted + blank lines at bottom
    new_region = region_before_cursor ++ region_after_deleted ++ blank_lines

    # Reassemble the entire buffer
    new_cells = before_region ++ new_region ++ after_region

    # Ensure buffer maintains its height
    final_cells = Enum.take(new_cells, buffer.height)
    %{buffer | cells: final_cells}
  end

  defp delete_lines_from_position(buffer, start_y, count, bottom) do
    # Calculate the number of lines that need to be shifted up
    lines_to_shift = max(0, bottom - start_y - count)

    # Shift lines from below the deletion region up
    buffer =
      handle_line_shifting(
        lines_to_shift > 0,
        buffer,
        start_y,
        count,
        lines_to_shift
      )

    # Fill the bottom lines with empty content
    Enum.reduce((bottom - count)..(bottom - 1), buffer, fn y, acc ->
      set_line(acc, y, create_empty_line(buffer.width))
    end)
  end

  # Helper functions
  defp create_empty_lines(width, count) do
    for _ <- 1..count do
      create_empty_line(width)
    end
  end

  defp create_empty_lines(width, count, style) do
    for _ <- 1..count do
      create_empty_line(width, style)
    end
  end

  defp create_empty_line(width, style \\ nil) do
    for _ <- 1..width do
      Raxol.Terminal.Cell.new(" ", style)
    end
  end

  defp get_line(buffer, line_index) do
    case buffer.cells do
      nil ->
        # Return empty list if cells is nil
        []

      cells ->
        get_line_at_index(
          line_index >= 0 and line_index < length(cells),
          cells,
          line_index
        )
    end
  end

  defp set_line(buffer, position, new_line) do
    valid_pos = position >= 0 and position < length(buffer.cells)
    update_line_at_position(valid_pos, buffer, position, new_line)
  end

  # Helper functions for refactored if statements
  defp handle_delete_lines_in_region(true, buffer, y, count) do
    # Split the content at the cursor position
    {before, after_cursor} = Enum.split(buffer.cells, y)

    # Remove the specified number of lines and shift remaining lines up
    remaining_lines = Enum.drop(after_cursor, count)

    # Add blank lines at the bottom
    blank_lines = create_empty_lines(buffer.width, count)
    new_cells = before ++ remaining_lines ++ blank_lines

    %{buffer | cells: new_cells}
  end

  defp handle_delete_lines_in_region(false, buffer, _y, _count), do: buffer

  defp handle_delete_lines_with_cursor(true, buffer, cursor_y, count) do
    # Split the content at the cursor position
    {before, after_cursor} = Enum.split(buffer.cells, cursor_y)

    # Remove the specified number of lines and shift remaining lines up
    remaining_lines = Enum.drop(after_cursor, count)

    # Add blank lines at the bottom
    blank_lines = create_empty_lines(buffer.width, count)
    new_cells = before ++ remaining_lines ++ blank_lines

    %{buffer | cells: new_cells}
  end

  defp handle_delete_lines_with_cursor(false, buffer, _cursor_y, _count),
    do: buffer

  defp handle_delete_at_position(true, buffer, position, count) do
    {before, after_cursor} = Enum.split(buffer.cells, position)
    remaining_lines = Enum.drop(after_cursor, count)
    blank_lines = create_empty_lines(buffer.width, count)
    new_cells = before ++ remaining_lines ++ blank_lines
    %{buffer | cells: new_cells}
  end

  defp handle_delete_at_position(false, buffer, _position, _count), do: buffer

  defp handle_styled_deletion(true, buffer, y, count, style, top, bottom) do
    do_delete_lines_in_region(buffer, y, count, style, top, bottom)
  end

  defp handle_styled_deletion(false, buffer, _y, _count, _style, _top, _bottom),
    do: buffer

  defp handle_delete_lines_in_scroll_region(true, buffer, lines, y, top, bottom) do
    # Calculate how many lines we can actually delete within the region
    available_lines = bottom - y + 1
    lines_to_delete = min(lines, available_lines)

    handle_lines_to_delete(
      lines_to_delete > 0,
      buffer,
      y,
      lines_to_delete,
      bottom
    )
  end

  defp handle_delete_lines_in_scroll_region(
         false,
         buffer,
         _lines,
         _y,
         _top,
         _bottom
       ),
       do: buffer

  defp handle_lines_to_delete(true, buffer, y, lines_to_delete, bottom) do
    # Delete lines from y to y + lines_to_delete - 1
    # This shifts content up from below the deleted region
    buffer
    |> delete_lines_from_position(y, lines_to_delete, bottom + 1)
  end

  defp handle_lines_to_delete(false, buffer, _y, _lines_to_delete, _bottom),
    do: buffer

  defp handle_line_shifting(true, buffer, start_y, count, lines_to_shift) do
    Enum.reduce(0..(lines_to_shift - 1), buffer, fn offset, acc ->
      target_y = start_y + offset
      source_y = start_y + count + offset
      # Get the line that should move up
      source_line = get_line(acc, source_y)
      # Set it at the current position
      set_line(acc, target_y, source_line)
    end)
  end

  defp handle_line_shifting(false, buffer, _start_y, _count, _lines_to_shift),
    do: buffer

  defp get_line_at_index(true, cells, line_index) do
    Enum.at(cells, line_index) || []
  end

  defp get_line_at_index(false, _cells, _line_index), do: []

  defp update_line_at_position(true, buffer, position, new_line) do
    new_cells = List.replace_at(buffer.cells, position, new_line)
    %{buffer | cells: new_cells}
  end

  defp update_line_at_position(false, buffer, _position, _new_line), do: buffer
end
