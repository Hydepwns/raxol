defmodule Raxol.Terminal.Buffer.LineOperations.Deletion do
  @moduledoc """
  Line deletion operations for terminal buffers.
  Handles deletion of single and multiple lines, with support for scroll regions.
  """

  alias Raxol.Terminal.Buffer.LineOperations.Utils

  @doc """
  Delete lines from a buffer.
  """
  @spec delete_lines(map(), integer()) :: map()
  def delete_lines(buffer, count) do
    delete_lines(buffer, buffer.cursor_y, count)
  end

  @spec delete_lines(map(), integer(), integer()) :: map()
  def delete_lines(buffer, start_y, count) do
    lines = Map.get(buffer, :lines, %{})
    height = Map.get(buffer, :height, 24)

    # Remove the specified lines
    new_lines =
      Enum.reduce(0..(height - 1), %{}, fn y, acc ->
        cond do
          y < start_y -> Map.put(acc, y, Map.get(lines, y))
          # Skip deleted lines
          y < start_y + count -> acc
          true -> Map.put(acc, y - count, Map.get(lines, y))
        end
      end)

    %{buffer | lines: new_lines}
  end

  @spec delete_lines(map(), integer(), integer(), integer(), integer()) :: map()
  def delete_lines(buffer, start_y, count, scroll_top, scroll_bottom) do
    delete_lines_in_region(buffer, start_y, count, scroll_top, scroll_bottom)
  end

  @spec delete_lines(map(), integer(), integer(), integer(), integer(), map()) ::
          map()
  def delete_lines(buffer, start_y, count, scroll_top, scroll_bottom, style) do
    buffer
    |> delete_lines_in_region(start_y, count, scroll_top, scroll_bottom)
    |> fill_new_lines(scroll_bottom - count + 1, count, style)
  end

  @doc """
  Delete lines within a scroll region.
  """
  @spec delete_lines_in_region(
          map(),
          integer(),
          integer(),
          integer(),
          integer()
        ) :: map()
  def delete_lines_in_region(buffer, start_y, count, top, bottom) do
    lines = Map.get(buffer, :lines, %{})

    # Build new line mapping
    new_lines =
      Enum.reduce(0..(Map.get(buffer, :height, 24) - 1), %{}, fn y, acc ->
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
            Map.put(acc, y, create_empty_line(buffer))
        end
      end)

    %{buffer | lines: new_lines}
  end

  # Helper functions
  defp create_empty_line(buffer) do
    width = Map.get(buffer, :width, 80)
    Enum.map(0..(width - 1), fn _ -> %{char: " ", style: %{}} end)
  end

  defp fill_new_lines(buffer, start_y, count, style) do
    Utils.fill_new_lines(buffer, start_y, count, style)
  end
end
