defmodule Raxol.Terminal.Buffer.ScrollRegion do
  @moduledoc """
  Handles scroll region operations for the screen buffer.
  This module manages the scroll region boundaries and provides functions
  for scrolling content within the defined region.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  @doc """
  Sets the scroll region boundaries.
  """
  @spec set_region(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def set_region(buffer, top, bottom) when top >= 0 and bottom < buffer.height and top < bottom do
    %{buffer | scroll_region: {top, bottom}}
  end
  def set_region(buffer, _top, _bottom), do: %{buffer | scroll_region: nil}

  @doc """
  Clears the scroll region, resetting to full screen.
  """
  @spec clear_region(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear_region(buffer) do
    %{buffer | scroll_region: nil}
  end

  @doc """
  Gets the current scroll region boundaries.
  """
  @spec get_region(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()} | nil
  def get_region(%ScreenBuffer{scroll_region: region}), do: region

  @doc """
  Gets the current scroll region boundaries.
  Returns {0, height-1} if no region is set.
  """
  @spec get_boundaries(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()}
  def get_boundaries(%ScreenBuffer{scroll_region: nil, height: height}) do
    {0, height - 1}
  end
  def get_boundaries(%ScreenBuffer{scroll_region: {top, bottom}}), do: {top, bottom}

  @doc """
  Scrolls the content up within the scroll region.
  """
  @spec scroll_up_region(ScreenBuffer.t(), non_neg_integer(), {non_neg_integer(), non_neg_integer()} | nil) :: ScreenBuffer.t()
  def scroll_up_region(buffer, lines, scroll_region_arg \\ nil) when lines > 0 do
    {scroll_start, scroll_end} =
      case scroll_region_arg do
        # 1. Use valid argument directly
        {start, ending}
        when is_integer(start) and start >= 0 and is_integer(ending) and
               ending >= start ->
          # Clamp end to buffer height
          {start, min(buffer.height - 1, ending)}

        # 2. If arg is nil or invalid, use buffer.scroll_region if set and valid
        _ when is_tuple(buffer.scroll_region) ->
          {start, ending} = buffer.scroll_region

          if is_integer(start) and start >= 0 and is_integer(ending) and
               ending >= start do
            # Clamp end to buffer height
            {start, min(buffer.height - 1, ending)}
          else
            # Buffer region invalid, use full height
            {0, buffer.height - 1}
          end

        # 3. Otherwise (arg and buffer region are nil/invalid), use full height
        _ ->
          {0, buffer.height - 1}
      end

    visible_lines = scroll_end - scroll_start + 1

    if lines >= visible_lines do
      # If scrolling more than region size, clear region
      empty_region_cells =
        List.duplicate(List.duplicate(Cell.new(), buffer.width), visible_lines)

      # Use imported helper
      updated_cells =
        replace_region_content(
          buffer.cells,
          scroll_start,
          scroll_end,
          empty_region_cells
        )

      %{buffer | cells: updated_cells}
    else
      # Scroll up by moving lines up and adding empty lines at bottom
      {before, region} = Enum.split(buffer.cells, scroll_start)
      {region, after_part} = Enum.split(region, visible_lines)
      {scroll_lines, remaining} = Enum.split(region, lines)
      empty_line = List.duplicate(Cell.new(), buffer.width)
      new_region = remaining ++ List.duplicate(empty_line, length(scroll_lines))
      updated_cells = before ++ new_region ++ after_part
      %{buffer | cells: updated_cells}
    end
  end

  @doc """
  Scrolls the content down within the scroll region.
  """
  @spec scroll_down(ScreenBuffer.t(), non_neg_integer(), {non_neg_integer(), non_neg_integer()} | nil) :: ScreenBuffer.t()
  def scroll_down(buffer, lines, scroll_region_arg \\ nil) when lines > 0 do
    {scroll_start, scroll_end} =
      case scroll_region_arg do
        # 1. Use valid argument directly
        {start, ending}
        when is_integer(start) and start >= 0 and is_integer(ending) and
               ending >= start ->
          # Clamp end to buffer height
          {start, min(buffer.height - 1, ending)}

        # 2. If arg is nil or invalid, use buffer.scroll_region if set and valid
        _ when is_tuple(buffer.scroll_region) ->
          {start, ending} = buffer.scroll_region

          if is_integer(start) and start >= 0 and is_integer(ending) and
               ending >= start do
            # Clamp end to buffer height
            {start, min(buffer.height - 1, ending)}
          else
            # Buffer region invalid, use full height
            {0, buffer.height - 1}
          end

        # 3. Otherwise (arg and buffer region are nil/invalid), use full height
        _ ->
          {0, buffer.height - 1}
      end

    visible_lines = scroll_end - scroll_start + 1

    if lines >= visible_lines do
      # If scrolling more than region size, clear region
      empty_region_cells =
        List.duplicate(List.duplicate(Cell.new(), buffer.width), visible_lines)

      # Use imported helper
      updated_cells =
        replace_region_content(
          buffer.cells,
          scroll_start,
          scroll_end,
          empty_region_cells
        )

      %{buffer | cells: updated_cells}
    else
      # Scroll down by moving lines down and adding empty lines at top
      {before, region} = Enum.split(buffer.cells, scroll_start)
      {region, after_part} = Enum.split(region, visible_lines)
      {remaining, scroll_lines} = Enum.split(region, length(region) - lines)
      empty_line = List.duplicate(Cell.new(), buffer.width)
      new_region = List.duplicate(empty_line, length(scroll_lines)) ++ remaining
      updated_cells = before ++ new_region ++ after_part
      %{buffer | cells: updated_cells}
    end
  end

  @doc """
  Clears the scroll region.
  """
  @spec clear(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear(buffer) do
    %{buffer | scroll_region: nil}
  end

  @doc """
  Replaces the content of a region in the buffer with new content.

  ## Parameters

  * `cells` - The current cells in the buffer
  * `start_line` - The starting line of the region to replace
  * `end_line` - The ending line of the region to replace
  * `new_content` - The new content to insert in the region

  ## Returns

  The updated cells with the region replaced.
  """
  @spec replace_region_content(list(list(Cell.t())), non_neg_integer(), non_neg_integer(), list(list(Cell.t()))) :: list(list(Cell.t()))
  def replace_region_content(cells, start_line, end_line, new_content) do
    {before, after_part} = Enum.split(cells, start_line)
    {_, after_part} = Enum.split(after_part, end_line - start_line + 1)
    before ++ new_content ++ after_part
  end
end
