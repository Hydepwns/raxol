defmodule Raxol.Terminal.Buffer.Common do
  @moduledoc '''
  Common buffer operations shared between different buffer-related modules.
  This module provides utility functions for buffer manipulation that are used
  by multiple modules to avoid code duplication.
  '''

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ScreenBuffer

  @doc '''
  Gets the lines within a specific region of the buffer.

  ## Parameters
    * `lines` - Current buffer lines
    * `top` - Top boundary of region
    * `bottom` - Bottom boundary of region

  ## Returns
    * `{:ok, region_lines}` on success
    * `{:error, :invalid_region}` on failure
  '''
  @spec get_region_lines(
          list(list(Cell.t())),
          non_neg_integer(),
          non_neg_integer()
        ) :: {:ok, list(list(Cell.t()))} | {:error, atom()}
  def get_region_lines(lines, top, bottom) do
    if top >= 0 and bottom < length(lines) and top <= bottom do
      {:ok, Enum.slice(lines, top..bottom)}
    else
      {:error, :invalid_region}
    end
  end

  @doc '''
  Replaces content in a specific region of the buffer.

  ## Parameters
    * `lines` - Current buffer lines
    * `new_region` - New content for the region
    * `top` - Top boundary of region
    * `bottom` - Bottom boundary of region

  ## Returns
    Updated buffer lines with the region replaced
  '''
  @spec replace_region(
          list(list(Cell.t())),
          list(list(Cell.t())),
          non_neg_integer(),
          non_neg_integer()
        ) :: list(list(Cell.t()))
  def replace_region(lines, new_region, top, _bottom) do
    List.replace_at(lines, top, new_region)
  end

  @doc '''
  Creates empty lines with optional styling.

  ## Parameters
    * `count` - Number of lines to create
    * `blank_style` - Optional style to apply to blank lines

  ## Returns
    * `{:ok, new_lines}` on success
  '''
  @spec create_empty_lines(non_neg_integer(), TextFormatting.text_style() | nil) ::
          {:ok, list(list(Cell.t()))}
  def create_empty_lines(count, blank_style) do
    lines = for _ <- 1..count, do: create_empty_line(blank_style)
    {:ok, lines}
  end

  @doc '''
  Creates a single empty line with optional styling.

  ## Parameters
    * `blank_style` - Optional style to apply to blank line

  ## Returns
    Empty line with optional styling
  '''
  @spec create_empty_line(TextFormatting.text_style() | nil) :: list(Cell.t())
  def create_empty_line(blank_style) do
    [Cell.new(" ", blank_style)]
  end

  @doc '''
  Appends new lines to existing lines.

  ## Parameters
    * `lines` - Current buffer lines
    * `new_lines` - Lines to append

  ## Returns
    * `{:ok, combined_lines}` on success
  '''
  @spec append_lines(list(list(Cell.t())), list(list(Cell.t()))) ::
          {:ok, list(list(Cell.t()))}
  def append_lines(lines, new_lines) do
    {:ok, lines ++ new_lines}
  end

  @doc '''
  Gets the top boundary of the scroll region.

  ## Parameters
    * `buffer` - The screen buffer
    * `scroll_region` - Optional scroll region override

  ## Returns
    * `{:ok, top}` on success
    * `{:error, reason}` on failure
  '''
  @spec get_scroll_top(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_scroll_top(buffer, scroll_region) do
    case scroll_region do
      {top, _} -> {:ok, top}
      nil -> ScreenBuffer.get_scroll_top(buffer)
    end
  end

  @doc '''
  Gets the bottom boundary of the scroll region.

  ## Parameters
    * `buffer` - The screen buffer
    * `scroll_region` - Optional scroll region override

  ## Returns
    * `{:ok, bottom}` on success
    * `{:error, reason}` on failure
  '''
  @spec get_scroll_bottom(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_scroll_bottom(buffer, scroll_region) do
    case scroll_region do
      {_, bottom} -> {:ok, bottom}
      nil -> ScreenBuffer.get_scroll_bottom(buffer)
    end
  end
end
