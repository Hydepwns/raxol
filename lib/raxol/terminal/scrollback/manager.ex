defmodule Raxol.Terminal.Scrollback.Manager do
  @moduledoc """
  Manages terminal scrollback buffer operations.
  """

  defstruct scrollback_buffer: [],
            # Default limit of 1000 lines
            scrollback_limit: 1000,
            current_position: 0

  @type scrollback_line :: String.t()
  @type scrollback_buffer :: [scrollback_line()]

  @type t :: %__MODULE__{
          scrollback_buffer: scrollback_buffer(),
          scrollback_limit: pos_integer(),
          current_position: non_neg_integer()
        }

  @doc """
  Creates a new scrollback manager instance.
  """
  def new(opts \\ []) do
    %__MODULE__{
      scrollback_limit: Keyword.get(opts, :scrollback_limit, 1000)
    }
  end

  @doc """
  Gets the current scrollback buffer.
  """
  def get_scrollback_buffer(%__MODULE__{} = state) do
    state.scrollback_buffer
  end

  @doc """
  Adds a line to the scrollback buffer.
  """
  def add_to_scrollback(%__MODULE__{} = state, line) when is_binary(line) do
    new_buffer = [line | state.scrollback_buffer]

    # Trim buffer if it exceeds the limit
    trimmed_buffer =
      if length(new_buffer) > state.scrollback_limit do
        Enum.take(new_buffer, state.scrollback_limit)
      else
        new_buffer
      end

    %{state | scrollback_buffer: trimmed_buffer}
  end

  @doc """
  Clears the scrollback buffer.
  """
  def clear_scrollback(%__MODULE__{} = state) do
    %{state | scrollback_buffer: [], current_position: 0}
  end

  @doc """
  Gets the scrollback limit.
  """
  def get_scrollback_limit(%__MODULE__{} = state) do
    state.scrollback_limit
  end

  @doc """
  Sets the scrollback limit.
  """
  def set_scrollback_limit(%__MODULE__{} = state, limit)
      when is_integer(limit) and limit > 0 do
    new_state = %{state | scrollback_limit: limit}

    # Trim buffer if it exceeds the new limit
    if length(new_state.scrollback_buffer) > limit do
      %{
        new_state
        | scrollback_buffer: Enum.take(new_state.scrollback_buffer, limit)
      }
    else
      new_state
    end
  end

  @doc """
  Gets a range of lines from the scrollback buffer.
  """
  def get_scrollback_range(%__MODULE__{} = state, start_line, end_line)
      when is_integer(start_line) and is_integer(end_line) and
             start_line >= 0 and end_line >= start_line do
    case Enum.slice(state.scrollback_buffer, start_line..end_line) do
      [] -> {:error, :invalid_range}
      lines -> {:ok, lines}
    end
  end

  @doc """
  Gets the current size of the scrollback buffer.
  """
  def get_scrollback_size(%__MODULE__{} = state) do
    length(state.scrollback_buffer)
  end

  @doc """
  Checks if the scrollback buffer is empty.
  """
  def scrollback_empty?(%__MODULE__{} = state) do
    state.scrollback_buffer == []
  end

  @doc """
  Gets the current scrollback position.
  """
  def get_current_position(%__MODULE__{} = state) do
    state.current_position
  end

  @doc """
  Sets the current scrollback position.
  """
  def set_current_position(%__MODULE__{} = state, position)
      when is_integer(position) and position >= 0 do
    max_position = length(state.scrollback_buffer) - 1
    new_position = min(position, max_position)
    %{state | current_position: new_position}
  end

  @doc """
  Scrolls up in the scrollback buffer.
  """
  def scroll_up(%__MODULE__{} = state, lines \\ 1)
      when is_integer(lines) and lines > 0 do
    new_position =
      min(state.current_position + lines, length(state.scrollback_buffer) - 1)

    %{state | current_position: new_position}
  end

  @doc """
  Scrolls down in the scrollback buffer.
  """
  def scroll_down(%__MODULE__{} = state, lines \\ 1)
      when is_integer(lines) and lines > 0 do
    new_position = max(state.current_position - lines, 0)
    %{state | current_position: new_position}
  end

  @doc """
  Gets the current line from the scrollback buffer.
  """
  def get_current_line(%__MODULE__{} = state) do
    case Enum.at(state.scrollback_buffer, state.current_position) do
      nil -> {:error, :invalid_position}
      line -> {:ok, line}
    end
  end
end
