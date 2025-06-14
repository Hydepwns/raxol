defmodule Raxol.Terminal.Buffer.Scroller do
  alias Raxol.Terminal.ScreenBuffer
  @moduledoc """
  Handles scrolling operations (up and down) within the Raxol.Terminal.ScreenBuffer,
  considering scroll regions.
  """

  alias Raxol.Terminal.Cell
  import Raxol.Terminal.Buffer.ScrollRegion, only: [replace_region_content: 4]

  defstruct [:cells, :width, :height]

  @type t :: %__MODULE__{
    cells: list(list(Raxol.Terminal.Buffer.Cell.t())),
    width: non_neg_integer(),
    height: non_neg_integer()
  }

  @type scroll_region :: {non_neg_integer(), non_neg_integer()}

  @doc """
  Scrolls the buffer up by the specified number of lines, optionally within a specified scroll region.
  Handles cell manipulation.
  Returns `{updated_buffer, scrolled_off_lines}`.
  """
  @spec scroll_up_scroller(
          ScreenBuffer.t(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: {ScreenBuffer.t(), list(list(Cell.t()))}
  def scroll_up_scroller(%ScreenBuffer{} = buffer, lines, scroll_region_arg \\ nil)
      when lines > 0 do
    # Determine effective scroll region boundaries
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
      # If scrolling more than region size, clear region and return all old lines
      scrolled_off_lines = Enum.slice(buffer.cells, scroll_start..scroll_end)

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

      # Return the updated buffer struct and scrolled lines
      {%{buffer | cells: updated_cells}, scrolled_off_lines}
    else
      scroll_region_lines = Enum.slice(buffer.cells, scroll_start..scroll_end)
      {scrolled_lines, remaining_lines} = Enum.split(scroll_region_lines, lines)

      empty_lines =
        List.duplicate(List.duplicate(Cell.new(), buffer.width), lines)

      new_region_content = remaining_lines ++ empty_lines

      # Return updated buffer struct and the lines scrolled off
      # Use imported helper
      updated_cells =
        replace_region_content(
          buffer.cells,
          scroll_start,
          scroll_end,
          new_region_content
        )

      # Return the updated buffer struct and scrolled lines
      {%{buffer | cells: updated_cells}, scrolled_lines}
    end
  end

  @doc """
  Scrolls the buffer down by the specified number of lines, optionally within a specified scroll region.
  Handles cell manipulation using provided lines from scrollback.
  Expects `lines_to_insert` from the caller (e.g., Buffer.Manager via Buffer.Scrollback).
  """
  @spec scroll_down(
          ScreenBuffer.t(),
          list(list(Cell.t())),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: ScreenBuffer.t()
  def scroll_down(
        %ScreenBuffer{} = buffer,
        lines_to_insert,
        lines,
        # Changed name from scroll_region
        scroll_region_arg \\ nil
      )
      when lines > 0 do
    # Determine effective scroll region boundaries (Same logic as scroll_up)
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
      # If scrolling more than region size, clear region (no lines inserted)
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
      # Handle scrollback and non-scrollback cases
      if lines_to_insert != [] do
        # Insert lines FROM scrollback
        actual_lines_to_insert = Enum.take(lines_to_insert, lines)
        scroll_region_lines = Enum.slice(buffer.cells, scroll_start..scroll_end)

        shifted_lines =
          Enum.drop(scroll_region_lines, -length(actual_lines_to_insert))

        new_region_content = actual_lines_to_insert ++ shifted_lines

        # Use imported helper
        updated_cells =
          replace_region_content(
            buffer.cells,
            scroll_start,
            scroll_end,
            new_region_content
          )

        %{buffer | cells: updated_cells}
      else
        # Insert BLANK lines (no scrollback)
        blank_line = List.duplicate(Cell.new(), buffer.width)
        blank_lines_to_insert = List.duplicate(blank_line, lines)

        scroll_region_lines = Enum.slice(buffer.cells, scroll_start..scroll_end)
        # Keep lines from the start, dropping lines from the end to make space
        shifted_lines = Enum.take(scroll_region_lines, visible_lines - lines)
        new_region_content = blank_lines_to_insert ++ shifted_lines

        # Use imported helper
        updated_cells =
          replace_region_content(
            buffer.cells,
            scroll_start,
            scroll_end,
            new_region_content
          )

        %{buffer | cells: updated_cells}
      end
    end
  end

  @doc """
  Scrolls the buffer up by the specified number of lines within the scroll region.
  """
  @spec scroll_up(t(), non_neg_integer(), scroll_region()) :: {t(), list(list(Cell.t()))}
  def scroll_up(buffer, lines, scroll_region) do
    {top, bottom} = scroll_region
    scroll_amount = min(lines, bottom - top + 1)

    # Get the lines to be scrolled
    lines_to_scroll = Enum.slice(buffer.cells, top, bottom - top + 1)

    # Create empty lines for the bottom
    empty_lines = Enum.map(1..scroll_amount, fn _ ->
      Enum.map(1..buffer.width, fn _ -> Cell.new() end)
    end)

    # Create new lines for the top
    new_lines = Enum.map(1..scroll_amount, fn _ ->
      Enum.map(1..buffer.width, fn _ -> Cell.new() end)
    end)

    # Update the buffer cells
    new_cells = buffer.cells
      |> List.replace_slice(top, top + scroll_amount - 1, new_lines)
      |> List.replace_slice(bottom - scroll_amount + 1, bottom, empty_lines)

    # Update the buffer
    new_buffer = %{buffer | cells: new_cells}

    {new_buffer, lines_to_scroll}
  end
end
