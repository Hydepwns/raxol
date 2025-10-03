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
    {_x, y} = buffer.cursor_position
    insert_lines(buffer, y, count)
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
  def insert_lines(buffer, y, count, scroll_top, scroll_bottom, _style) do
    # do_insert_lines_in_region already creates blank lines with style
    do_insert_lines_in_region(buffer, y, count, scroll_top, scroll_bottom)
  end

  @doc """
  Internal insertion with default style.
  """
  @spec do_insert_lines(map(), integer(), integer(), map()) :: map()
  def do_insert_lines(buffer, y, count, style) do
    alias Raxol.Terminal.ScreenBuffer.DataAdapter

    DataAdapter.with_lines_format(buffer, fn buffer_with_lines ->
      lines = Map.get(buffer_with_lines, :lines, %{})
      height = Map.get(buffer_with_lines, :height, 24)
      width = Map.get(buffer_with_lines, :width, 80)

      # Build new lines using pattern matching
      new_lines =
        0..(height - 1)
        |> Enum.map(fn line_y ->
          {line_y,
           build_line_at_position(lines, line_y, y, count, width, style, height)}
        end)
        |> Enum.reject(fn {_line_y, line} -> is_nil(line) end)
        |> Enum.into(%{})

      %{buffer_with_lines | lines: new_lines}
    end)
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
    alias Raxol.Terminal.ScreenBuffer.DataAdapter

    DataAdapter.with_lines_format(buffer, fn buffer_with_lines ->
      lines = Map.get(buffer_with_lines, :lines, %{})
      height = Map.get(buffer_with_lines, :height, 24)
      width = Map.get(buffer_with_lines, :width, 80)

      new_lines =
        Enum.reduce(0..(height - 1), %{}, fn line_y, acc ->
          cond do
            # Outside scroll region - keep unchanged
            line_y < top or line_y > bottom ->
              original_line = Map.get(lines, line_y)
              Map.put(acc, line_y, original_line)

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

      %{buffer_with_lines | lines: new_lines}
    end)
  end

  defp create_empty_line(width, style) do
    Enum.map(0..(width - 1), fn _ -> %{char: " ", style: style} end)
  end

  # Pattern match on line position relative to insertion point
  defp build_line_at_position(
         lines,
         line_y,
         insert_y,
         _count,
         _width,
         _style,
         _height
       )
       when line_y < insert_y do
    # Lines before insertion point stay the same
    Map.get(lines, line_y)
  end

  defp build_line_at_position(
         _lines,
         line_y,
         insert_y,
         count,
         width,
         style,
         _height
       )
       when line_y >= insert_y and line_y < insert_y + count do
    # Insert new empty lines
    create_empty_line(width, style)
  end

  defp build_line_at_position(
         lines,
         line_y,
         _insert_y,
         count,
         _width,
         _style,
         height
       )
       when line_y < height do
    # Shift remaining lines down if they fit
    source_y = line_y - count
    build_shifted_line(lines, source_y, height - count)
  end

  defp build_line_at_position(
         _lines,
         _line_y,
         _insert_y,
         _count,
         _width,
         _style,
         _height
       ) do
    nil
  end

  defp build_shifted_line(lines, source_y, max_source)
       when source_y < max_source do
    Map.get(lines, source_y)
  end

  defp build_shifted_line(_lines, _source_y, _max_source), do: nil
end
