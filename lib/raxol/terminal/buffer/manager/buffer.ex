defmodule Raxol.Terminal.Buffer.Manager.Buffer do
  @moduledoc """
  Handles buffer operations and synchronization for the terminal.
  Provides functionality for buffer manipulation, double buffering, and synchronization.
  """

  alias Raxol.Terminal.Buffer.Manager.State
  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.Buffer.Manager.BufferImpl

  @doc """
  Creates a new buffer with the specified dimensions.

  ## Examples

      iex> Buffer.new(80, 24)
      %Buffer{width: 80, height: 24, cells: %{}}
  """
  def new(width, height) do
    BufferImpl.new(width, height)
  end

  @doc """
  Gets a cell from the active buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> Buffer.get_cell(state, 0, 0)
      %Cell{char: " ", fg: :default, bg: :default}
  """
  def get_cell(%State{} = state, x, y) do
    BufferImpl.get_cell(state.active_buffer, x, y)
  end

  @doc """
  Sets a cell in the active buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> cell = %Cell{char: "A", fg: :red, bg: :blue}
      iex> state = Buffer.set_cell(state, 0, 0, cell)
      iex> Buffer.get_cell(state, 0, 0)
      %Cell{char: "A", fg: :red, bg: :blue}
  """
  def set_cell(%State{} = state, x, y, cell) do
    new_buffer = BufferImpl.set_cell(state.active_buffer, x, y, cell)
    %{state | active_buffer: new_buffer}
  end

  @doc """
  Fills a region in the active buffer with a cell.

  ## Examples

      iex> state = State.new(80, 24)
      iex> cell = %Cell{char: "X", fg: :red, bg: :blue}
      iex> state = Buffer.fill_region(state, 0, 0, 10, 5, cell)
      iex> Buffer.get_cell(state, 5, 2)
      %Cell{char: "X", fg: :red, bg: :blue}
  """
  def fill_region(%State{} = state, x, y, width, height, cell) do
    new_buffer =
      BufferImpl.fill_region(state.active_buffer, x, y, width, height, cell)

    %{state | active_buffer: new_buffer}
  end

  @doc """
  Copies a region from one position to another in the active buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> cell = %Cell{char: "A", fg: :red, bg: :blue}
      iex> state = Buffer.set_cell(state, 0, 0, cell)
      iex> state = Buffer.copy_region(state, 0, 0, 10, 0, 5, 5)
      iex> Buffer.get_cell(state, 10, 0)
      %Cell{char: "A", fg: :red, bg: :blue}
  """
  def copy_region(%State{} = state, src_x, src_y, dst_x, dst_y, width, height) do
    new_buffer =
      BufferImpl.copy_region(
        state.active_buffer,
        src_x,
        src_y,
        dst_x,
        dst_y,
        width,
        height
      )

    %{state | active_buffer: new_buffer}
  end

  @doc """
  Scrolls a region in the active buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Buffer.scroll_region(state, 0, 0, 10, 5, 2)
      iex> Buffer.get_cell(state, 0, 2)
      %Cell{char: " ", fg: :default, bg: :default}
  """
  def scroll_region(%State{} = state, x, y, width, height, lines) do
    new_buffer =
      BufferImpl.scroll_region(state.active_buffer, x, y, width, height, lines)

    %{state | active_buffer: new_buffer}
  end

  @doc """
  Synchronizes the back buffer with the active buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Buffer.sync_buffers(state)
      iex> state.active_buffer == state.back_buffer
      true
  """
  def sync_buffers(%State{} = state) do
    new_back_buffer = BufferImpl.copy(state.active_buffer)
    %{state | back_buffer: new_back_buffer}
  end

  @doc """
  Gets the differences between the active and back buffers.

  ## Examples

      iex> state = State.new(80, 24)
      iex> cell = %Cell{char: "A", fg: :red, bg: :blue}
      iex> state = Buffer.set_cell(state, 0, 0, cell)
      iex> Buffer.get_differences(state)
      [{0, 0, %Cell{char: "A", fg: :red, bg: :blue}}]
  """
  def get_differences(%State{} = state) do
    BufferImpl.get_differences(state.active_buffer, state.back_buffer)
  end

  @doc """
  Clears the active buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Buffer.clear(state)
      iex> Buffer.get_cell(state, 0, 0)
      %Cell{char: " ", fg: :default, bg: :default}
  """
  def clear(%State{} = state) do
    new_buffer = BufferImpl.clear(state.active_buffer)
    %{state | active_buffer: new_buffer}
  end

  @doc """
  Resizes the active buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Buffer.resize(state, 100, 30)
      iex> state.active_buffer.width
      100
      iex> state.active_buffer.height
      30
  """
  def resize(%State{} = state, width, height) do
    new_buffer = BufferImpl.resize(state.active_buffer, width, height)
    %{state | active_buffer: new_buffer}
  end

  @doc """
  Adds content to the active buffer.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Buffer.add(state, "Hello, World!")
      iex> Buffer.get_content(state)
      "Hello, World!"
  """
  def add(%State{} = state, content) do
    new_buffer = BufferImpl.add(state.active_buffer, content)
    %{state | active_buffer: new_buffer}
  end
end
