defmodule Raxol.Terminal.Buffer.Scroll do
  @moduledoc """
  Terminal scroll buffer module.

  This module handles the management of terminal scrollback buffers, including:
  - Virtual scrolling implementation
  - Memory-efficient buffer management
  - Scroll position tracking
  - Buffer compression
  """

  alias Raxol.Terminal.Cell

  @type t :: %__MODULE__{
          buffer: list(list(Cell.t())),
          position: non_neg_integer(),
          height: non_neg_integer(),
          max_height: non_neg_integer(),
          compression_ratio: float(),
          memory_limit: non_neg_integer(),
          memory_usage: non_neg_integer()
        }

  defstruct [
    :buffer,
    :position,
    :height,
    :max_height,
    :compression_ratio,
    :memory_limit,
    :memory_usage
  ]

  @doc """
  Creates a new scroll buffer with the given dimensions.

  ## Examples

      iex> scroll = Scroll.new(1000)
      iex> scroll.max_height
      1000
      iex> scroll.position
      0
  """
  def new(max_height, memory_limit \\ 5_000_000) do
    %__MODULE__{
      buffer: [],
      position: 0,
      height: 0,
      max_height: max_height,
      compression_ratio: 1.0,
      memory_limit: memory_limit,
      memory_usage: 0
    }
  end

  @doc """
  Adds a line to the scroll buffer.

  ## Examples

      iex> scroll = Scroll.new(1000)
      iex> line = [Cell.new("A"), Cell.new("B")]
      iex> scroll = Scroll.add_line(scroll, line)
      iex> scroll.height
      1
  """
  def add_line(%__MODULE__{} = scroll, line) do
    new_buffer = [line | scroll.buffer]

    # Trim buffer if it exceeds max height
    new_buffer =
      if length(new_buffer) > scroll.max_height do
        Enum.take(new_buffer, scroll.max_height)
      else
        new_buffer
      end

    # Update memory usage and compression if needed
    new_usage = calculate_memory_usage(new_buffer)

    {new_buffer, new_ratio} =
      if new_usage > scroll.memory_limit do
        compress_buffer(new_buffer)
      else
        {new_buffer, scroll.compression_ratio}
      end

    %{
      scroll
      | buffer: new_buffer,
        height: length(new_buffer),
        compression_ratio: new_ratio,
        memory_usage: new_usage
    }
  end

  @doc """
  Gets a view of the scroll buffer at the current position.

  ## Examples

      iex> scroll = Scroll.new(1000)
      iex> line = [Cell.new("A"), Cell.new("B")]
      iex> scroll = Scroll.add_line(scroll, line)
      iex> view = Scroll.get_view(scroll, 10)
      iex> length(view)
      1
  """
  def get_view(%__MODULE__{} = scroll, view_height) do
    Enum.slice(scroll.buffer, scroll.position, view_height)
  end

  @doc """
  Scrolls the buffer by the given amount.

  ## Examples

      iex> scroll = Scroll.new(1000)
      iex> line = [Cell.new("A"), Cell.new("B")]
      iex> scroll = Scroll.add_line(scroll, line)
      iex> scroll = Scroll.scroll(scroll, 5)
      iex> scroll.position
      5
  """
  def scroll(%__MODULE__{} = scroll, amount) do
    new_position =
      :erlang.max(0, :erlang.min(scroll.position + amount, scroll.height))

    %{scroll | position: new_position}
  end

  @doc """
  Gets the current scroll position.

  ## Examples

      iex> scroll = Scroll.new(1000)
      iex> Scroll.get_position(scroll)
      0
  """
  def get_position(%__MODULE__{} = scroll) do
    scroll.position
  end

  @doc """
  Gets the total height of the scroll buffer.

  ## Examples

      iex> scroll = Scroll.new(1000)
      iex> line = [Cell.new("A"), Cell.new("B")]
      iex> scroll = Scroll.add_line(scroll, line)
      iex> Scroll.get_height(scroll)
      1
  """
  def get_height(%__MODULE__{} = scroll) do
    scroll.height
  end

  @doc """
  Clears the scroll buffer.

  ## Examples

      iex> scroll = Scroll.new(1000)
      iex> line = [Cell.new("A"), Cell.new("B")]
      iex> scroll = Scroll.add_line(scroll, line)
      iex> scroll = Scroll.clear(scroll)
      iex> scroll.height
      0
  """
  def clear(%__MODULE__{} = scroll) do
    %{scroll | buffer: [], position: 0, height: 0, memory_usage: 0}
  end

  # Private functions

  defp calculate_memory_usage(buffer) do
    # Rough estimation of memory usage based on buffer size and content
    total_cells =
      buffer
      |> Enum.map(&length/1)
      |> Enum.sum()

    # Estimated bytes per cell
    cell_size = 100
    total_cells * cell_size
  end

  defp compress_buffer(buffer) do
    # Simple compression: merge empty cells and reduce attribute storage
    compressed =
      buffer
      |> Enum.map(fn line ->
        line
        |> Enum.chunk_by(&Cell.is_empty?/1)
        |> Enum.map(fn
          [cell] ->
            cell

          cells ->
            # If all cells are empty, just keep one
            if Enum.all?(cells, &Cell.is_empty?/1) do
              List.first(cells)
            else
              # Otherwise, keep all cells but with minimal attributes
              Enum.map(cells, &minimize_cell_attributes/1)
            end
        end)
        |> List.flatten()
      end)

    # Calculate new compression ratio
    original_size = calculate_memory_usage(buffer)
    compressed_size = calculate_memory_usage(compressed)
    ratio = compressed_size / original_size

    {compressed, ratio}
  end

  defp minimize_cell_attributes(cell) do
    # Access :style, not :attributes
    %{cell | style: Map.take(cell.style, [:foreground, :background])}
  end
end
