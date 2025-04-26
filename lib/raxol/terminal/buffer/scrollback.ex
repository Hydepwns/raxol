defmodule Raxol.Terminal.Buffer.Scrollback do
  @moduledoc """
  Manages the scrollback buffer logic for Raxol.Terminal.ScreenBuffer.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  @doc """
  Adds lines to the scrollback buffer, respecting the limit.
  Returns the new scrollback list.
  """
  @spec add(ScreenBuffer.t(), list(list(Cell.t()))) :: list(list(Cell.t()))
  def add(%ScreenBuffer{} = buffer, lines_to_add) do
    (lines_to_add ++ buffer.scrollback)
    |> Enum.take(buffer.scrollback_limit)
  end

  @doc """
  Retrieves lines from the scrollback buffer for scrolling down.
  Returns a tuple {lines_from_scrollback, new_scrollback_buffer}.
  Returns {[], buffer.scrollback} if not enough lines are available.
  """
  @spec retrieve_for_scroll_down(ScreenBuffer.t(), non_neg_integer()) ::
          {list(list(Cell.t())), list(list(Cell.t()))}
  def retrieve_for_scroll_down(%ScreenBuffer{} = buffer, lines_needed)
      when lines_needed > 0 do
    if length(buffer.scrollback) >= lines_needed do
      Enum.split(buffer.scrollback, lines_needed)
    else
      {[], buffer.scrollback}
    end
  end

  def retrieve_for_scroll_down(%ScreenBuffer{} = buffer, _lines_needed),
    do: {[], buffer.scrollback}

  @doc """
  Gets the current scroll position (number of lines in scrollback).
  """
  @spec get_position(ScreenBuffer.t()) :: non_neg_integer()
  def get_position(%ScreenBuffer{} = buffer) do
    length(buffer.scrollback)
  end
end
