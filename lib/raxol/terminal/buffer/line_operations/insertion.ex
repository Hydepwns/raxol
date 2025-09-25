defmodule Raxol.Terminal.Buffer.LineOperations.Insertion do
  @moduledoc """
  Line insertion operations for terminal buffers.
  Handles insertion of single and multiple lines with style support.
  """

  alias Raxol.Terminal.Buffer.LineOperations.Utils

  @doc """
  Insert empty lines at the current cursor position.
  """
  @spec insert_lines(map(), integer()) :: map()
  def insert_lines(buffer, count) do
    insert_lines(buffer, buffer.cursor_y, count)
  end

  @spec insert_lines(map(), integer(), integer()) :: map()
  def insert_lines(buffer, y, count) do
    do_insert_lines(buffer, y, count, %{})
  end

  @spec insert_lines(map(), integer(), integer(), map()) :: map()
  def insert_lines(buffer, y, count, style) do
    do_insert_lines(buffer, y, count, style)
  end

  @spec insert_lines(map(), integer(), integer(), integer(), integer()) :: map()
  def insert_lines(buffer, y, count, scroll_top, scroll_bottom) do
    do_insert_lines_with_style(buffer, y, count, scroll_top, scroll_bottom)
  end

  @spec insert_lines(map(), integer(), integer(), integer(), integer(), map()) ::
          map()
  def insert_lines(buffer, y, count, scroll_top, scroll_bottom, style) do
    buffer
    |> do_insert_lines_in_region(y, count, scroll_top, scroll_bottom)
    |> fill_new_lines(y, count, style)
  end

  @doc """
  Internal insertion with default style.
  """
  @spec do_insert_lines(map(), integer(), integer(), map()) :: map()
  def do_insert_lines(buffer, y, count, style) do
    lines = Map.get(buffer, :lines, %{})
    height = Map.get(buffer, :height, 24)
    width = Map.get(buffer, :width, 80)

    # Shift existing lines down
    new_lines =
      Enum.reduce(0..(height - 1), %{}, fn line_y, acc ->
        cond do
          line_y < y ->
            # Lines before insertion point stay the same
            Map.put(acc, line_y, Map.get(lines, line_y))

          line_y < y + count ->
            # Insert new empty lines
            Map.put(acc, line_y, create_empty_line(width, style))

          line_y < height ->
            # Shift remaining lines down if they fit
            source_y = line_y - count

            if source_y < height - count do
              Map.put(acc, line_y, Map.get(lines, source_y))
            else
              acc
            end

          true ->
            acc
        end
      end)

    %{buffer | lines: new_lines}
  end

  @doc """
  Insert lines with style in a scroll region.
  """
  @spec do_insert_lines_with_style(
          map(),
          integer(),
          integer(),
          integer(),
          integer()
        ) :: map()
  def do_insert_lines_with_style(buffer, y, count, scroll_top, scroll_bottom) do
    do_insert_lines_in_region(buffer, y, count, scroll_top, scroll_bottom)
  end

  # Helper functions
  defp do_insert_lines_in_region(buffer, y, count, top, bottom) do
    lines = Map.get(buffer, :lines, %{})
    height = Map.get(buffer, :height, 24)
    width = Map.get(buffer, :width, 80)

    new_lines =
      Enum.reduce(0..(height - 1), %{}, fn line_y, acc ->
        cond do
          # Outside scroll region - keep unchanged
          line_y < top or line_y > bottom ->
            Map.put(acc, line_y, Map.get(lines, line_y))

          # Before insertion point - keep unchanged
          line_y < y ->
            Map.put(acc, line_y, Map.get(lines, line_y))

          # New inserted lines
          line_y < y + count ->
            Map.put(acc, line_y, create_empty_line(width, %{}))

          # Shifted lines within region
          line_y <= bottom ->
            source_y = line_y - count

            if source_y <= bottom - count do
              Map.put(acc, line_y, Map.get(lines, source_y))
            else
              acc
            end

          true ->
            acc
        end
      end)

    %{buffer | lines: new_lines}
  end

  defp create_empty_line(width, style) do
    Enum.map(0..(width - 1), fn _ -> %{char: " ", style: style} end)
  end

  defp fill_new_lines(buffer, start_y, count, style) do
    Utils.fill_new_lines(buffer, start_y, count, style)
  end
end
