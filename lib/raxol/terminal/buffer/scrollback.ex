defmodule Raxol.Terminal.Buffer.Scrollback do
  @moduledoc """
  Manages the scrollback buffer lines.

  Stores lines scrolled off the top and provides them when scrolling down.
  Enforces a configurable size limit.
  """

  @type t :: %__MODULE__{
          lines: list(Line.t()),
          limit: non_neg_integer()
        }

  defstruct lines: [], limit: 1000

  @doc """
  Creates a new scrollback buffer with a given limit.
  """
  @spec new(non_neg_integer()) :: t()
  def new(limit \\ 1000) when is_integer(limit) and limit >= 0 do
    %__MODULE__{limit: limit, lines: []}
  end

  @doc """
  Sets the scrollback limit for an existing buffer. Trims lines if new limit is smaller.
  """
  @spec set_limit(t(), non_neg_integer()) :: t()
  def set_limit(%__MODULE__{} = scrollback, new_limit)
      when is_integer(new_limit) and new_limit >= 0 do
    trimmed_lines = Enum.take(scrollback.lines, new_limit)
    %__MODULE__{scrollback | lines: trimmed_lines, limit: new_limit}
  end

  @doc """
  Gets the current scrollback limit.
  """
  @spec get_limit(t()) :: non_neg_integer()
  def get_limit(%__MODULE__{limit: limit}), do: limit

  @doc """
  Adds new lines to the top of the scrollback buffer.

  Lines are prepended. The buffer is trimmed to the limit if necessary.
  """
  @spec add_lines(t(), list(Line.t())) :: t()
  def add_lines(%__MODULE__{limit: limit} = scrollback, new_lines)
      when is_list(new_lines) do
    # Prepend new lines (they scrolled off the *top* of the screen)
    combined = new_lines ++ scrollback.lines
    trimmed_lines = Enum.take(combined, limit)
    %__MODULE__{scrollback | lines: trimmed_lines}
  end

  @doc """
  Takes a number of lines from the top of the scrollback buffer.

  Used when scrolling down to restore lines.
  Returns a tuple: `{restored_lines, updated_scrollback_state}`.
  Fewer lines than requested may be returned if the buffer is smaller.
  """
  @spec take_lines(t(), non_neg_integer()) :: {list(Line.t()), t()}
  def take_lines(%__MODULE__{} = scrollback, count)
      when is_integer(count) and count >= 0 do
    {lines_to_restore, remaining_lines} = Enum.split(scrollback.lines, count)
    updated_scrollback = %__MODULE__{scrollback | lines: remaining_lines}
    {lines_to_restore, updated_scrollback}
  end

  @doc """
  Clears all lines from the scrollback buffer.
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = scrollback) do
    %__MODULE__{scrollback | lines: []}
  end

  @doc """
  Gets the current number of lines stored in the scrollback buffer.
  """
  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{lines: lines}), do: length(lines)

  @doc """
  Gets a specific line from the scrollback buffer by index (0-based from newest).
  Returns nil if index is out of bounds.
  """
  @spec get_line(t(), non_neg_integer()) :: Line.t() | nil
  def get_line(%__MODULE__{lines: lines}, index)
      when is_integer(index) and index >= 0 do
    Enum.at(lines, index)
  end

  @doc """
  Gets a range of lines from the scrollback buffer (0-based from newest).
  """
  @spec get_lines(t(), non_neg_integer(), non_neg_integer()) :: list(Line.t())
  def get_lines(%__MODULE__{lines: lines}, start_index, count)
      when is_integer(start_index) and start_index >= 0 and
             is_integer(count) and count >= 0 do
    Enum.slice(lines, start_index, count)
  end

  @doc """
  Checks if the scrollback buffer is full (i.e., number of lines equals the limit).
  """
  @spec is_full?(t()) :: boolean()
  def is_full?(%__MODULE__{lines: lines, limit: limit}) do
    length(lines) >= limit
  end

  @doc """
  Gets the oldest line in the scrollback buffer (the one at the limit).
  Returns nil if the buffer is empty.
  """
  @spec get_oldest_line(t()) :: Line.t() | nil
  def get_oldest_line(%__MODULE__{lines: lines}) do
    List.last(lines)
  end

  @doc """
  Gets the newest line in the scrollback buffer (the one most recently added).
  Returns nil if the buffer is empty.
  """
  @spec get_newest_line(t()) :: Line.t() | nil
  def get_newest_line(%__MODULE__{lines: lines}) do
    List.first(lines)
  end
end
