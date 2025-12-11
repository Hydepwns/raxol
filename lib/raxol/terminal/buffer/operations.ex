defmodule Raxol.Terminal.Buffer.Operations do
  @moduledoc """
  Compatibility adapter for consolidated buffer operations.
  Forwards calls to Raxol.Terminal.ScreenBuffer.Operations.
  """

  alias Raxol.Terminal.ScreenBuffer.Core
  alias Raxol.Terminal.ScreenBuffer.Operations, as: ConsolidatedOps

  @doc """
  Writes a character at the specified position.
  """
  @spec write_char(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map() | nil
        ) :: map()
  def write_char(buffer, x, y, char, style \\ nil) do
    ConsolidatedOps.write_char(buffer, x, y, char, style)
  end

  @doc """
  Writes text starting at the specified position.
  """
  @spec write_text(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map() | nil
        ) :: map()
  def write_text(buffer, x, y, text, style \\ nil) do
    ConsolidatedOps.write_text(buffer, x, y, text, style)
  end

  @doc """
  Inserts a character at the cursor position.
  """
  @spec insert_char(map(), String.t(), map() | nil) :: map()
  def insert_char(buffer, char, style \\ nil) do
    ConsolidatedOps.insert_char(buffer, char, style)
  end

  @doc """
  Deletes a character at the cursor position.
  """
  @spec delete_char(map()) :: map()
  def delete_char(buffer) do
    ConsolidatedOps.delete_char(buffer)
  end

  @doc """
  Clears a line.
  """
  @spec clear_line(map(), non_neg_integer()) :: map()
  def clear_line(buffer, y) do
    ConsolidatedOps.clear_line(buffer, y)
  end

  @doc """
  Clears to end of line.
  """
  @spec clear_to_end_of_line(map()) :: map()
  def clear_to_end_of_line(buffer) do
    ConsolidatedOps.clear_to_end_of_line(buffer)
  end

  @doc """
  Clears to beginning of line.
  """
  @spec clear_to_beginning_of_line(map()) :: map()
  def clear_to_beginning_of_line(buffer) do
    ConsolidatedOps.clear_to_beginning_of_line(buffer)
  end

  @doc """
  Clears to end of screen.
  """
  @spec clear_to_end_of_screen(map()) :: map()
  def clear_to_end_of_screen(buffer) do
    ConsolidatedOps.clear_to_end_of_screen(buffer)
  end

  @doc """
  Clears to beginning of screen.
  """
  @spec clear_to_beginning_of_screen(map()) :: map()
  def clear_to_beginning_of_screen(buffer) do
    ConsolidatedOps.clear_to_beginning_of_screen(buffer)
  end

  @doc """
  Clears a rectangular region.
  """
  @spec clear_region(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: map()
  def clear_region(buffer, x, y, width, height) do
    ConsolidatedOps.clear_region(buffer, x, y, width, height)
  end

  @doc """
  Inserts a blank line.
  """
  @spec insert_line(map(), non_neg_integer()) :: map()
  def insert_line(buffer, y) do
    ConsolidatedOps.insert_line(buffer, y)
  end

  @doc """
  Deletes a line.
  """
  @spec delete_line(map(), non_neg_integer()) :: map()
  def delete_line(buffer, y) do
    ConsolidatedOps.delete_line(buffer, y)
  end

  @doc """
  Fills a region with a character.
  """
  @spec fill_region(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map() | nil
        ) :: map()
  def fill_region(buffer, x, y, width, height, char, style \\ nil) do
    ConsolidatedOps.fill_region(buffer, x, y, width, height, char, style)
  end

  @doc """
  Copies a region to another location.
  """
  @spec copy_region(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: map()
  def copy_region(buffer, src_x, src_y, width, height, dest_x, dest_y) do
    ConsolidatedOps.copy_region(
      buffer,
      src_x,
      src_y,
      width,
      height,
      dest_x,
      dest_y
    )
  end

  # Additional compatibility functions for specific test cases

  @doc """
  Inserts multiple lines (compatibility function).
  """
  def insert_lines(buffer, y, count, _style \\ nil) when is_integer(count) do
    Enum.reduce(1..count, buffer, fn _, acc ->
      ConsolidatedOps.insert_line(acc, y)
    end)
  end

  def insert_lines(buffer, lines, y, _top, _bottom) when is_list(lines) do
    # For list of lines, insert each line
    lines
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {line_content, index}, acc ->
      line_y = y + index
      ConsolidatedOps.write_text(acc, 0, line_y, line_content)
    end)
  end

  @doc """
  Deletes multiple lines (compatibility function).
  """
  def delete_lines(buffer, y, count, _style \\ nil) when is_integer(count) do
    Enum.reduce(1..count, buffer, fn _, acc ->
      ConsolidatedOps.delete_line(acc, y)
    end)
  end

  def delete_lines(buffer, lines, y, _top, _bottom) when is_integer(lines) do
    Enum.reduce(1..lines, buffer, fn _, acc ->
      ConsolidatedOps.delete_line(acc, y)
    end)
  end
end
