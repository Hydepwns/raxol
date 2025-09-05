defmodule Raxol.Terminal.Buffer.Scrollback do
  @moduledoc """
  Handles scrollback buffer operations for the screen buffer.
  This module manages the history of lines that have scrolled off the screen,
  including adding, retrieving, and clearing scrollback content.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  @doc """
  Adds a line to the scrollback buffer.
  """
  @spec add_line(ScreenBuffer.t(), list(Cell.t())) :: ScreenBuffer.t()
  def add_line(buffer, line) when is_list(line) do
    scrollback = [line | buffer.scrollback]
    scrollback = trim_scrollback(scrollback, buffer.scrollback_limit)
    %{buffer | scrollback: scrollback}
  end

  def add_line(buffer, _), do: buffer

  @doc """
  Adds multiple lines to the scrollback buffer.
  """
  @spec add_lines(ScreenBuffer.t(), list(list(Cell.t()))) :: ScreenBuffer.t()
  def add_lines(buffer, lines) when is_list(lines) do
    scrollback = lines ++ buffer.scrollback
    scrollback = trim_scrollback(scrollback, buffer.scrollback_limit)
    %{buffer | scrollback: scrollback}
  end

  def add_lines(buffer, _), do: buffer

  @doc """
  Gets a specific line from the scrollback buffer.
  """
  @spec get_line(ScreenBuffer.t(), non_neg_integer()) :: list(Cell.t()) | nil
  def get_line(buffer, index) when index >= 0 do
    buffer.scrollback
    |> Enum.reverse()
    |> Enum.at(index)
  end

  def get_line(_, _), do: nil

  @doc """
  Gets lines from the scrollback buffer.
  """
  @spec get_lines(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          list(list(Cell.t()))
  def get_lines(buffer, start, count) when start >= 0 and count > 0 do
    buffer.scrollback
    |> Enum.reverse()
    |> Enum.slice(start, count)
  end

  def get_lines(_, _, _), do: []

  @doc """
  Gets the total number of lines in the scrollback buffer.
  """
  @spec size(ScreenBuffer.t()) :: non_neg_integer()
  def size(buffer) do
    length(buffer.scrollback)
  end

  @doc """
  Clears the scrollback buffer.
  """
  @spec clear(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear(buffer) do
    %{buffer | scrollback: []}
  end

  @doc """
  Sets the scrollback limit.
  """
  @spec set_limit(ScreenBuffer.t(), non_neg_integer()) :: ScreenBuffer.t()
  def set_limit(buffer, limit) when limit >= 0 do
    scrollback = trim_scrollback(buffer.scrollback, limit)
    %{buffer | scrollback: scrollback, scrollback_limit: limit}
  end

  def set_limit(buffer, _), do: buffer

  @doc """
  Gets the current scrollback limit.
  """
  @spec get_limit(ScreenBuffer.t()) :: non_neg_integer()
  def get_limit(buffer) do
    buffer.scrollback_limit
  end

  @doc """
  Checks if the scrollback buffer is full.
  """
  @spec full?(ScreenBuffer.t()) :: boolean()
  def full?(buffer) do
    length(buffer.scrollback) >= buffer.scrollback_limit
  end

  @doc """
  Gets the oldest line in the scrollback buffer.
  """
  @spec get_oldest_line(ScreenBuffer.t()) :: list(Cell.t()) | nil
  def get_oldest_line(buffer) do
    List.last(buffer.scrollback)
  end

  @doc """
  Gets the newest line in the scrollback buffer.
  """
  @spec get_newest_line(ScreenBuffer.t()) :: list(Cell.t()) | nil
  def get_newest_line(buffer) do
    List.first(buffer.scrollback)
  end

  # Private helper functions

  defp trim_scrollback(scrollback, limit) do
    if length(scrollback) > limit do
      scrollback
      |> Enum.take(limit)
    else
      scrollback
    end
  end

  defstruct lines: [], limit: 1000

  @type t :: %__MODULE__{
          lines: list(),
          limit: integer()
        }

  @doc """
  Returns a new scrollback buffer with default settings.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Gets the memory usage of the scrollback buffer.
  """
  @spec get_memory_usage(t()) :: non_neg_integer()
  def get_memory_usage(%__MODULE__{} = scrollback) do
    # Estimate memory usage based on number of lines and average line length
    total_cells =
      Enum.reduce(scrollback.lines, 0, fn line, acc ->
        acc + length(line)
      end)

    # Rough estimate: each cell is about 64 bytes (including overhead)
    total_cells * 64
  end

  @doc """
  Cleans up the scrollback buffer.
  """
  @spec cleanup(t()) :: t()
  def cleanup(%__MODULE__{} = scrollback) do
    %{scrollback | lines: []}
  end
end
