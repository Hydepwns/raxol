defmodule Raxol.Terminal.Buffer.Scrollback do
  @moduledoc """
  Manages the scrollback buffer lines.

  Stores lines scrolled off the top and provides them when scrolling down.
  Enforces a configurable size limit.
  """

  alias Raxol.Terminal.ScreenBuffer.Line

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
end
