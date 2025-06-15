defmodule Raxol.Terminal.Commands.Scrolling do
  @moduledoc """
  Handles scrolling operations for the terminal screen buffer.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Buffer.Operations
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
    {effective_top, effective_bottom} = get_scroll_region(buffer, scroll_region)
    region_height = effective_bottom - effective_top + 1

    if count > 0 and region_height > 0 do
      actual_scroll_count = min(count, region_height)
      preserved_lines_source_start = effective_top + actual_scroll_count
      preserved_lines_count = region_height - actual_scroll_count

      buffer
      |> shift_lines_up(
        effective_top,
        preserved_lines_source_start,
        preserved_lines_count
      )
      |> fill_blank_lines(
        effective_top + preserved_lines_count,
        actual_scroll_count,
        blank_style
      )
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

  @doc """
  Scrolls the buffer down by the specified number of lines.

  ## Parameters
    * `buffer` - The screen buffer to modify
    * `count` - The number of lines to scroll down
    * `scroll_region` - Optional scroll region override {top, bottom}
    * `blank_style` - Style to apply to blank lines

  ## Returns
    Updated screen buffer
  """
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
    case Operations.scroll_down(buffer, count,
           scroll_region: scroll_region,
           blank_style: blank_style
         ) do
      {:ok, new_buffer} ->
        new_buffer

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning(
          "Failed to scroll down: #{inspect(reason)}"
        )

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

  defp get_scroll_region(buffer, scroll_region) do
    case scroll_region do
      {top, bottom}
      when is_integer(top) and is_integer(bottom) and top >= 0 and
             bottom < buffer.height ->
        {top, bottom}

      _ ->
        {0, buffer.height - 1}
    end
  end

  defp shift_lines_up(buffer, target_start, source_start, count) do
    shift_lines(buffer, target_start, source_start, count)
  end

  defp shift_lines_down(buffer, target_start, source_start, count) do
    shift_lines(buffer, target_start, source_start, count)
  end

  defp shift_lines(buffer, target_start, source_start, count) do
    {before, _region} = Enum.split(buffer.cells, target_start)
    {_region, after_part} = Enum.split(_region, count)
    {_, source_region} = Enum.split(buffer.cells, source_start)
    {source_region, _} = Enum.split(source_region, count)
    updated_cells = before ++ source_region ++ after_part
    %{buffer | cells: updated_cells}
  end

  defp fill_blank_lines(buffer, start_line, count, style) do
    empty_line = List.duplicate(Cell.new(style), buffer.width)
    empty_lines = List.duplicate(empty_line, count)
    {before, after_part} = Enum.split(buffer.cells, start_line)
    updated_cells = before ++ empty_lines ++ after_part
    %{buffer | cells: updated_cells}
  end
end
