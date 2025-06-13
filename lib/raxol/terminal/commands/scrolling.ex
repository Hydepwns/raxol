defmodule Raxol.Terminal.Commands.Scrolling do
  @moduledoc """
  Handles scrolling operations for the terminal screen buffer.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  require Raxol.Core.Runtime.Log

  @spec scroll_up(
          ScreenBuffer.t(),
          non_neg_integer(),
          {integer(), integer()} | nil,
          Raxol.Terminal.ANSI.TextFormatting.text_style()
        ) :: ScreenBuffer.t()

  # Handles invalid region {top, bottom} where top > bottom
  def scroll_up(buffer, _count, {region_top, region_bottom}, _blank_style)
      when is_integer(region_top) and is_integer(region_bottom) and
             region_top > region_bottom do
    Raxol.Core.Runtime.Log.debug(
      "Scroll Up: Invalid region (top > bottom). Region: #{inspect({region_top, region_bottom})}. No scroll."
    )

    buffer
  end

  # Main scrolling logic for scroll_up
  def scroll_up(%{__struct__: _} = buffer, count, scroll_region, blank_style)
      when count > 0 do
    {effective_top, effective_bottom, region_height} = get_scroll_region(buffer, scroll_region)

    if validate_scroll_params(effective_top, effective_bottom, count, region_height) do
      actual_scroll_count = min(count, region_height)
      preserved_lines_source_start = effective_top + actual_scroll_count
      preserved_lines_count = region_height - actual_scroll_count

      buffer
      |> shift_lines_up(effective_top, preserved_lines_source_start, preserved_lines_count)
      |> fill_blank_lines(effective_top + preserved_lines_count, actual_scroll_count, blank_style)
    else
      buffer
    end
  end

  def scroll_up(buffer, _count, _scroll_region, _blank_style)
      when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  # No scroll or invalid count
  def scroll_up(buffer, count, _scroll_region, _blank_style) when count <= 0,
    do: buffer

  def execute_scroll_up(buffer, count, region, blank_style) do
    {effective_top, effective_bottom, region_height} = get_scroll_region(buffer, region)

    if validate_scroll_params(effective_top, effective_bottom, count, region_height) do
      actual_scroll_count = min(count, region_height)
      preserved_lines_source_start = effective_top + actual_scroll_count
      preserved_lines_count = region_height - actual_scroll_count

      buffer
      |> shift_lines_up(effective_top, preserved_lines_source_start, preserved_lines_count)
      |> fill_blank_lines(effective_top + preserved_lines_count, actual_scroll_count, blank_style)
    else
      buffer
    end
  end

  @spec scroll_down(
          ScreenBuffer.t(),
          non_neg_integer(),
          {integer(), integer()} | nil,
          Raxol.Terminal.ANSI.TextFormatting.text_style()
        ) :: ScreenBuffer.t()

  # Handles invalid region {top, bottom} where top > bottom
  def scroll_down(buffer, _count, {region_top, region_bottom}, _blank_style)
      when is_integer(region_top) and is_integer(region_bottom) and
             region_top > region_bottom do
    Raxol.Core.Runtime.Log.debug(
      "Scroll Down: Invalid region (top > bottom). Region: #{inspect({region_top, region_bottom})}. No scroll."
    )

    buffer
  end

  def scroll_down(%{__struct__: _} = buffer, count, scroll_region, blank_style)
      when count > 0 do
    {top_limit, bottom_limit} =
      case scroll_region do
        {rt, rb} -> {rt, rb}
        nil -> {0, buffer.height - 1}
      end

    effective_top = max(0, top_limit)
    effective_bottom = min(buffer.height - 1, bottom_limit)
    region_height = effective_bottom - effective_top + 1

    if validate_scroll_down_params(effective_top, effective_bottom, count, region_height) do
      actual_scroll_count = min(count, region_height)
      preserved_lines_count = region_height - actual_scroll_count

      buffer
      |> shift_lines_down(effective_top, preserved_lines_count, actual_scroll_count)
      |> fill_blank_lines(effective_top, actual_scroll_count, blank_style)
    else
      buffer
    end
  end

  def scroll_down(buffer, _count, _scroll_region, _blank_style)
      when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  # No scroll or invalid count
  def scroll_down(buffer, count, _scroll_region, _blank_style) when count <= 0,
    do: buffer

  # Private helper functions
  defp shift_lines_up(buffer, _effective_top, _preserved_lines_source_start, preserved_lines_count)
       when preserved_lines_count <= 0, do: buffer

  defp shift_lines_up(buffer, effective_top, preserved_lines_source_start, preserved_lines_count) do
    Enum.reduce(0..(preserved_lines_count - 1), buffer, fn i, acc_buffer ->
      source_row = preserved_lines_source_start + i
      target_row = effective_top + i
      case ScreenBuffer.get_line(acc_buffer, source_row) do
        cells when is_list(cells) -> ScreenBuffer.put_line(acc_buffer, target_row, cells)
        _ -> acc_buffer
      end
    end)
  end

  defp shift_lines_down(buffer, _effective_top, preserved_lines_count, _actual_scroll_count)
       when preserved_lines_count <= 0, do: buffer

  defp shift_lines_down(buffer, effective_top, preserved_lines_count, actual_scroll_count) do
    0..(preserved_lines_count - 1)
    |> Enum.reverse()
    |> Enum.reduce(buffer, fn i, acc_buffer ->
      source_row = effective_top + i
      target_row = effective_top + actual_scroll_count + i
      case ScreenBuffer.get_line(acc_buffer, source_row) do
        cells when is_list(cells) -> ScreenBuffer.put_line(acc_buffer, target_row, cells)
        _ -> acc_buffer
      end
    end)
  end

  defp get_scroll_region(buffer, {region_top, region_bottom}) do
    {top_limit, bottom_limit} =
      case {region_top, region_bottom} do
        {rt, rb} -> {rt, rb}
        _ -> {0, buffer.height - 1}
      end

    effective_top = max(0, top_limit)
    effective_bottom = min(buffer.height - 1, bottom_limit)
    region_height = effective_bottom - effective_top + 1
    {effective_top, effective_bottom, region_height}
  end

  defp fill_blank_lines(buffer, start_row, count, blank_style) do
    blank_line_cells = List.duplicate(Cell.new(" ", blank_style), buffer.width)
    Enum.reduce(0..(count - 1), buffer, fn i, acc_buffer ->
      ScreenBuffer.put_line(acc_buffer, start_row + i, blank_line_cells)
    end)
  end

  defp validate_scroll_params(effective_top, effective_bottom, count, region_height) do
    if region_height <= 0 or count <= 0 or count > region_height do
      Raxol.Core.Runtime.Log.debug(
        "scroll_up_command: No effective scroll. Top: #{effective_top}, Bottom: #{effective_bottom}, Count: #{count}, Region Height: #{region_height}"
      )
      false
    else
      true
    end
  end

  defp validate_scroll_down_params(effective_top, effective_bottom, count, region_height) do
    if region_height <= 0 or count <= 0 or count > region_height do
      Raxol.Core.Runtime.Log.debug(
        "Scroll Down: No effective scroll. Top: #{effective_top}, Bottom: #{effective_bottom}, Count: #{count}, Region Height: #{region_height}"
      )
      false
    else
      true
    end
  end
end
