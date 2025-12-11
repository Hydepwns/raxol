defmodule Raxol.Terminal.Buffer.LineOperations.Deletion do
  @moduledoc """
  Line deletion operations for terminal buffers.
  Handles deletion of single and multiple lines, with support for scroll regions.
  """

  @doc """
  Delete lines from a buffer.
  """
  def delete_lines(buffer, count) do
    {_x, y} = buffer.cursor_position
    delete_lines(buffer, y, count)
  end

  def delete_lines(buffer, start_y, count) do
    alias Raxol.Terminal.ScreenBuffer.DataAdapter

    DataAdapter.with_lines_format(buffer, fn buffer_with_lines ->
      lines = Map.get(buffer_with_lines, :lines, %{})
      height = Map.get(buffer_with_lines, :height, 24)

      # Remove the specified lines using functional patterns
      new_lines =
        0..(height - 1)
        |> Enum.map(fn new_y ->
          {new_y, map_deleted_line(lines, new_y, start_y, count, height)}
        end)
        |> Enum.reject(fn {_y, line} -> is_nil(line) end)
        |> Enum.into(%{})

      %{buffer_with_lines | lines: new_lines}
    end)
  end

  def delete_lines(buffer, start_y, count, scroll_top, scroll_bottom) do
    delete_lines_in_region(buffer, start_y, count, scroll_top, scroll_bottom)
  end

  def delete_lines(buffer, start_y, count, scroll_top, scroll_bottom, _style) do
    # delete_lines_in_region already fills with empty lines
    delete_lines_in_region(buffer, start_y, count, scroll_top, scroll_bottom)
  end

  @doc """
  Delete lines within a scroll region.
  """
  def delete_lines_in_region(buffer, start_y, count, top, bottom) do
    alias Raxol.Terminal.ScreenBuffer.DataAdapter

    DataAdapter.with_lines_format(buffer, fn buffer_with_lines ->
      lines = Map.get(buffer_with_lines, :lines, %{})

      # Build new line mapping
      new_lines =
        Enum.reduce(0..(Map.get(buffer_with_lines, :height, 24) - 1), %{}, fn y,
                                                                              acc ->
          cond do
            # Before scroll region
            y < top or y > bottom ->
              Map.put(acc, y, Map.get(lines, y))

            # Lines before deletion point
            y < start_y ->
              Map.put(acc, y, Map.get(lines, y))

            # Shift lines up after deletion
            y + count <= bottom ->
              Map.put(acc, y, Map.get(lines, y + count))

            # Fill with empty lines at bottom
            true ->
              Map.put(acc, y, create_empty_line(buffer_with_lines))
          end
        end)

      %{buffer_with_lines | lines: new_lines}
    end)
  end

  # Helper functions
  defp create_empty_line(buffer) do
    width = Map.get(buffer, :width, 80)
    Enum.map(0..(width - 1), fn _ -> %{char: " ", style: %{}} end)
  end

  # Pattern match for new line positions after deletion
  # Lines before deletion stay in same position
  defp map_deleted_line(lines, new_y, start_y, _count, _height)
       when new_y < start_y do
    Map.get(lines, new_y)
  end

  # Lines after deletion get content from shifted positions
  defp map_deleted_line(lines, new_y, start_y, count, height)
       when new_y >= start_y do
    source_y = new_y + count
    map_shifted_line(lines, source_y, height)
  end

  defp create_empty_line_with_defaults do
    Enum.map(0..79, fn _ -> %{char: " ", style: %{}} end)
  end

  defp map_shifted_line(lines, source_y, height) when source_y < height do
    Map.get(lines, source_y)
  end

  defp map_shifted_line(_lines, _source_y, _height),
    do: create_empty_line_with_defaults()
end
