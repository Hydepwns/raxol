defmodule Raxol.Terminal.Buffer.Manager.Scrollback do
  @moduledoc """
  Handles scrollback buffer management for the terminal.
  Provides functionality for managing scrollback history and operations.
  """

  alias Raxol.Terminal.Buffer.Manager.State
  alias Raxol.Terminal.Buffer.Scrollback, as: BufferScrollback

  @doc """
  Adds a line to the scrollback buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Scrollback.add_line(state, "Hello, World!")
      iex> Scrollback.get_line(state, 0)
      "Hello, World!"
  """
  def add_line(%State{} = state, line) do
    new_scrollback = BufferScrollback.add_lines(state.scrollback, [line])
    %{state | scrollback: new_scrollback}
  end

  @doc """
  Gets a line from the scrollback buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Scrollback.add_line(state, "Hello, World!")
      iex> Scrollback.get_line(state, 0)
      "Hello, World!"
  """
  def get_line(%State{} = state, index) do
    BufferScrollback.get_line(state.scrollback, index)
  end

  @doc """
  Gets the number of lines in the scrollback buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Scrollback.add_line(state, "Hello, World!")
      iex> Scrollback.get_line_count(state)
      1
  """
  def get_line_count(%State{} = state) do
    BufferScrollback.size(state.scrollback)
  end

  @doc """
  Clears the scrollback buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Scrollback.add_line(state, "Hello, World!")
      iex> state = Scrollback.clear(state)
      iex> Scrollback.get_line_count(state)
      0
  """
  def clear(%State{} = state) do
    new_scrollback = BufferScrollback.clear(state.scrollback)
    %{state | scrollback: new_scrollback}
  end

  @doc """
  Gets the scrollback height limit.

  ## Examples

      iex> state = State.new(80, 24)
      iex> Scrollback.get_height(state)
      1000
  """
  def get_height(%State{} = state) do
    BufferScrollback.get_limit(state.scrollback)
  end

  @doc """
  Sets a new scrollback height limit.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Scrollback.set_height(state, 2000)
      iex> Scrollback.get_height(state)
      2000
  """
  def set_height(%State{} = state, new_height)
      when is_integer(new_height) and new_height > 0 do
    new_scrollback = BufferScrollback.set_limit(state.scrollback, new_height)
    %{state | scrollback: new_scrollback}
  end

  @doc """
  Gets a range of lines from the scrollback buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Scrollback.add_line(state, "Line 1")
      iex> state = Scrollback.add_line(state, "Line 2")
      iex> Scrollback.get_lines(state, 0, 2)
      ["Line 1", "Line 2"]
  """
  def get_lines(%State{} = state, start, count) do
    BufferScrollback.get_lines(state.scrollback, start, count)
  end

  @doc """
  Checks if the scrollback buffer is full.

  ## Examples

      iex> state = State.new(80, 24)
      iex> Scrollback.full?(state)
      false
  """
  def full?(%State{} = state) do
    BufferScrollback.is_full?(state.scrollback)
  end

  @doc """
  Gets the oldest line in the scrollback buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Scrollback.add_line(state, "Oldest line")
      iex> Scrollback.get_oldest_line(state)
      "Oldest line"
  """
  def get_oldest_line(%State{} = state) do
    BufferScrollback.get_oldest_line(state.scrollback)
  end

  @doc """
  Gets the newest line in the scrollback buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Scrollback.add_line(state, "Newest line")
      iex> Scrollback.get_newest_line(state)
      "Newest line"
  """
  def get_newest_line(%State{} = state) do
    BufferScrollback.get_newest_line(state.scrollback)
  end
end
