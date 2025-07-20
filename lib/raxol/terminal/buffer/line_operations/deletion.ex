defmodule Raxol.Terminal.Buffer.LineOperations.Deletion do
  @moduledoc """
  Handles line deletion operations for the screen buffer.
  """

  import Raxol.Guards
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
    if y >= top and y <= bottom do
      # Split the content at the cursor position
      {before, after_cursor} = Enum.split(buffer.cells, y)

      # Remove the specified number of lines and shift remaining lines up
      remaining_lines = Enum.drop(after_cursor, count)

      # Add blank lines at the bottom
      blank_lines = create_empty_lines(buffer.width, count)
      new_cells = before ++ remaining_lines ++ blank_lines

      %{buffer | cells: new_cells}
    else
      buffer
    end
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
    if cursor_y >= scroll_top and cursor_y <= scroll_bottom do
      # Split the content at the cursor position
      {before, after_cursor} = Enum.split(buffer.cells, cursor_y)

      # Remove the specified number of lines and shift remaining lines up
      remaining_lines = Enum.drop(after_cursor, count)

      # Add blank lines at the bottom
      blank_lines = create_empty_lines(buffer.width, count)
      new_cells = before ++ remaining_lines ++ blank_lines

      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  @doc """
  Deletes lines at a specific position.
  """
  @spec delete_lines(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def delete_lines(buffer, position, count) do
    if position >= 0 and position < length(buffer.cells) and count > 0 do
      {before, after_cursor} = Enum.split(buffer.cells, position)
      remaining_lines = Enum.drop(after_cursor, count)
      blank_lines = create_empty_lines(buffer.width, count)
      new_cells = before ++ remaining_lines ++ blank_lines
      %{buffer | cells: new_cells}
    else
      buffer
    end
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
    if y >= top and y <= bottom and count > 0 do
      do_delete_lines_in_region(buffer, y, count, style, top, bottom)
    else
      buffer
    end
  end

  def delete_lines(buffer, _y, _count, _style, region)
      when not is_tuple(region),
      do: buffer

  @doc """
  Deletes lines at the specified position within the scroll region.
  """
  def delete_lines_in_region(buffer, lines, y, top, bottom) do
    # Ensure we're within the scroll region
    y = max(top, min(y, bottom - 1))

    # Calculate how many lines we can actually delete
    available_lines = bottom - y
    lines_to_delete = min(lines, available_lines)

    if lines_to_delete > 0 do
      # Delete lines from y to y + lines_to_delete - 1
      # This shifts content up from below the deleted region
      buffer
      |> delete_lines_from_position(y, lines_to_delete, bottom)
    else
      buffer
    end
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
    # Shift lines from below the deletion region up
    Enum.reduce(start_y..(bottom - count - 1), buffer, fn y, acc ->
      # Get the line that should move up
      source_line = get_line(acc, y + count)
      # Set it at the current position
      set_line(acc, y, source_line)
    end)
    |> then(fn acc ->
      # Fill the bottom lines with empty content
      Enum.reduce((bottom - count)..(bottom - 1), acc, fn y, acc ->
        set_line(acc, y, create_empty_line())
      end)
    end)
  end

  defp create_empty_line do
    # Create an empty line with default attributes
    # Use the existing function with default width
    create_empty_line(80)
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
        if line_index >= 0 and line_index < length(cells) do
          Enum.at(cells, line_index) || []
        else
          []
        end
    end
  end

  defp set_line(buffer, position, new_line) do
    if position >= 0 and position < length(buffer.cells) do
      new_cells = List.replace_at(buffer.cells, position, new_line)
      %{buffer | cells: new_cells}
    else
      buffer
    end
  end
end
