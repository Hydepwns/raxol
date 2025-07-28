defmodule Raxol.Terminal.Buffer.LineOperations.Insertion do
  @moduledoc """
  Handles line insertion operations for the screen buffer.
  """

  import Raxol.Guards
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Inserts blank lines at the cursor position, shifting lines down and pushing out the bottom lines.
  Lines below the cursor are shifted down, and lines shifted off the bottom are discarded.
  """
  @spec insert_lines(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def insert_lines(buffer, count) when integer?(count) and count > 0 do
    {_, y} = buffer.cursor_position

    # Split the content at the cursor position
    {before_cursor, after_cursor} = Enum.split(buffer.cells, y)

    # Create blank lines
    blank_lines = create_empty_lines(buffer.width, count)

    # Combine: before cursor + blank lines + after cursor
    combined = before_cursor ++ blank_lines ++ after_cursor

    # Take only the first buffer.height lines (truncate if necessary)
    new_cells = Enum.take(combined, buffer.height)

    %{buffer | cells: new_cells}
  end

  @doc """
  Inserts a specified number of lines with explicit parameters.
  """
  def insert_lines(
        buffer,
        count,
        cursor_y,
        _cursor_x,
        scroll_top,
        scroll_bottom
      ) do
    if cursor_y >= scroll_top and cursor_y <= scroll_bottom do
      # Split the content at the cursor position
      {before_cursor, after_cursor} = Enum.split(buffer.cells, cursor_y)

      # Create blank lines
      blank_lines = create_empty_lines(buffer.width, count)

      # Calculate how many lines to keep from after_cursor
      lines_to_keep = max(0, scroll_bottom - cursor_y - count + 1)
      kept_lines = Enum.take(after_cursor, lines_to_keep)

      # Combine the parts
      new_cells = before_cursor ++ blank_lines ++ kept_lines

      # Ensure the buffer maintains its correct size
      final_cells =
        if length(new_cells) < length(buffer.cells) do
          # Add any additional blank lines needed
          additional_lines =
            create_empty_lines(
              buffer.width,
              length(buffer.cells) - length(new_cells)
            )

          new_cells ++ additional_lines
        else
          # Truncate if necessary
          Enum.take(new_cells, length(buffer.cells))
        end

      %{buffer | cells: final_cells}
    else
      buffer
    end
  end

  @doc """
  Helper function to handle the line insertion logic.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `cursor_y` - The y-coordinate of the cursor
  * `count` - The number of lines to insert
  * `bottom` - The bottom boundary of the scroll region

  ## Returns

  The updated screen buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = LineOperations.Insertion.do_insert_lines(buffer, 0, 5, 23)
      iex> length(buffer.cells)
      24
  """
  @spec do_insert_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def do_insert_lines(buffer, cursor_y, count, bottom) do
    # Split the content at the cursor position
    {before_cursor, after_cursor} = Enum.split(buffer.cells, cursor_y)

    # Create blank lines
    blank_lines = create_empty_lines(buffer.width, count)

    # Calculate how many lines to keep from after_cursor
    # The bottom parameter is the bottom of the scroll region
    # We need to keep lines from after_cursor that fit within the scroll region
    lines_to_keep = max(0, bottom - cursor_y - count + 1)
    kept_lines = Enum.take(after_cursor, lines_to_keep)

    # Combine the parts: before cursor + blank lines + kept lines
    new_cells = before_cursor ++ blank_lines ++ kept_lines

    # Ensure the buffer maintains its correct size
    final_cells =
      if length(new_cells) < length(buffer.cells) do
        # Add any additional blank lines needed to maintain buffer size
        additional_lines =
          create_empty_lines(
            buffer.width,
            length(buffer.cells) - length(new_cells)
          )

        new_cells ++ additional_lines
      else
        # Truncate if necessary
        Enum.take(new_cells, length(buffer.cells))
      end

    %{buffer | cells: final_cells}
  end

  @doc """
  Inserts lines at a specific position with style.
  """
  @spec do_insert_lines_with_style(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def do_insert_lines_with_style(buffer, cursor_y, count, bottom, style) do
    # Split the content at the cursor position
    {before_cursor, after_cursor} = Enum.split(buffer.cells, cursor_y)

    # Create blank lines with style
    blank_lines = create_empty_lines(buffer.width, count, style)

    # Calculate how many lines to keep from after_cursor
    lines_to_keep = max(0, bottom - cursor_y - count + 1)
    kept_lines = Enum.take(after_cursor, lines_to_keep)

    # Combine the parts
    new_cells = before_cursor ++ blank_lines ++ kept_lines

    # Ensure the buffer maintains its correct size
    final_cells =
      if length(new_cells) < length(buffer.cells) do
        # Add any additional blank lines needed
        additional_lines =
          create_empty_lines(
            buffer.width,
            length(buffer.cells) - length(new_cells)
          )

        new_cells ++ additional_lines
      else
        # Truncate if necessary
        Enum.take(new_cells, length(buffer.cells))
      end

    %{buffer | cells: final_cells}
  end

  @doc """
  Inserts lines at a specific position.
  """
  @spec insert_lines(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def insert_lines(buffer, position, count) do
    if position >= 0 and position < length(buffer.cells) and count > 0 do
      do_insert_lines(buffer, position, count, length(buffer.cells) - 1)
    else
      buffer
    end
  end

  @doc """
  Inserts lines at a specific position with style.
  """
  @spec insert_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) ::
          ScreenBuffer.t()
  def insert_lines(buffer, position, count, style) do
    if position >= 0 and position < length(buffer.cells) and count > 0 do
      do_insert_lines_with_style(
        buffer,
        position,
        count,
        length(buffer.cells) - 1,
        style
      )
    else
      buffer
    end
  end

  @doc """
  Inserts lines at a specific position with region boundaries.
  """
  @spec insert_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          ScreenBuffer.t()
  def insert_lines(buffer, lines, y, top, bottom) do
    if y >= top and y <= bottom and lines > 0 do
      # Split the buffer into three parts:
      # 1. Lines before the scroll region (unchanged)
      # 2. Lines within the scroll region (affected by insertion)
      # 3. Lines after the scroll region (unchanged)

      {before_region, rest} = Enum.split(buffer.cells, top)
      {in_region, after_region} = Enum.split(rest, bottom - top + 1)

      # Split the region at the cursor position
      {before_cursor, after_cursor} = Enum.split(in_region, y - top)

      # Create blank lines
      blank_lines = create_empty_lines(buffer.width, lines)

      # Calculate how many lines to keep from after_cursor
      # We can only keep lines that fit within the scroll region
      lines_to_keep = max(0, bottom - y - lines + 1)
      kept_lines = Enum.take(after_cursor, lines_to_keep)

      # Combine the region parts: before cursor + blank lines + kept lines
      new_region = before_cursor ++ blank_lines ++ kept_lines

      # Ensure the region maintains its correct size
      final_region =
        if length(new_region) < length(in_region) do
          # Add any additional blank lines needed to maintain region size
          additional_lines =
            create_empty_lines(
              buffer.width,
              length(in_region) - length(new_region)
            )

          new_region ++ additional_lines
        else
          # Truncate if necessary
          Enum.take(new_region, length(in_region))
        end

      # Combine all parts: before region + final region + after region
      new_cells = before_region ++ final_region ++ after_region

      %{buffer | cells: new_cells}
    else
      buffer
    end
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
end
