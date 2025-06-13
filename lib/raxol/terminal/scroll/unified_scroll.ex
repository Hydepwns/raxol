defmodule Raxol.Terminal.Scroll.UnifiedScroll do
  @moduledoc """
  Unified scroll management system for the terminal.

  This module consolidates all scroll-related functionality including:
  - Scroll buffer management
  - Scroll operations (up/down)
  - Scroll region handling
  - Memory management
  - Performance optimization
  """

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @type t :: %__MODULE__{
    buffer: list(list(Cell.t())),
    position: non_neg_integer(),
    height: non_neg_integer(),
    max_height: non_neg_integer(),
    scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
    compression_ratio: float(),
    memory_limit: non_neg_integer(),
    memory_usage: non_neg_integer(),
    cache: map()
  }

  defstruct [
    :buffer,
    :position,
    :height,
    :max_height,
    :scroll_region,
    :compression_ratio,
    :memory_limit,
    :memory_usage,
    :cache
  ]

  @doc """
  Creates a new scroll buffer with the given dimensions and configuration.
  """
  def new(max_height, memory_limit \\ 5_000_000) do
    %__MODULE__{
      buffer: [],
      position: 0,
      height: 0,
      max_height: max_height,
      scroll_region: nil,
      compression_ratio: 1.0,
      memory_limit: memory_limit,
      memory_usage: 0,
      cache: %{}
    }
  end

  @doc """
  Adds a line to the scroll buffer.
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

    # Clear cache when buffer changes
    %{
      scroll
      | buffer: new_buffer,
        height: length(new_buffer),
        compression_ratio: new_ratio,
        memory_usage: new_usage,
        cache: %{}
    }
  end

  @doc """
  Gets a view of the scroll buffer at the current position.
  """
  def get_view(%__MODULE__{} = scroll, view_height) do
    cache_key = {:view, scroll.position, view_height}

    case Map.get(scroll.cache, cache_key) do
      nil ->
        view = Enum.slice(scroll.buffer, scroll.position, view_height)
        new_cache = Map.put(scroll.cache, cache_key, view)
        {view, %{scroll | cache: new_cache}}
      cached_view ->
        {cached_view, scroll}
    end
  end

  @doc """
  Scrolls the buffer by the given amount.
  """
  def scroll(%__MODULE__{} = scroll, amount) do
    new_position =
      :erlang.max(0, :erlang.min(scroll.position + amount, scroll.height))

    # Clear cache when position changes
    %{scroll | position: new_position, cache: %{}}
  end

  @doc """
  Scrolls the buffer in the specified direction by the given amount.
  """
  def scroll(%__MODULE__{} = scroll, direction, amount) do
    case direction do
      :up -> scroll(scroll, -amount)
      :down -> scroll(scroll, amount)
      _ -> scroll
    end
  end

  @doc """
  Sets the scroll region.
  """
  def set_scroll_region(%__MODULE__{} = scroll, top, bottom)
      when is_integer(top) and is_integer(bottom) and top < bottom do
    %{scroll | scroll_region: {top, bottom}}
  end

  def set_scroll_region(%__MODULE__{} = scroll, _top, _bottom) do
    scroll
  end

  @doc """
  Clears the scroll region.
  """
  def clear_scroll_region(%__MODULE__{} = scroll) do
    %{scroll | scroll_region: nil}
  end

  @doc """
  Gets the current scroll position.
  """
  def get_position(%__MODULE__{} = scroll) do
    scroll.position
  end

  @doc """
  Gets the total height of the scroll buffer.
  """
  def get_height(%__MODULE__{} = scroll) do
    scroll.height
  end

  @doc """
  Gets the visible region of the scroll buffer.
  """
  def get_visible_region(%__MODULE__{} = scroll) do
    case scroll.scroll_region do
      nil -> {0, scroll.height - 1}
      {top, bottom} -> {top, bottom}
    end
  end

  @doc """
  Clears the scroll buffer.
  """
  def clear(%__MODULE__{} = scroll) do
    %{scroll | buffer: [], position: 0, height: 0, memory_usage: 0, cache: %{}}
  end

  @doc """
  Updates the maximum height of the scroll buffer.
  """
  def set_max_height(%__MODULE__{} = scroll, new_max_height)
      when is_integer(new_max_height) and new_max_height >= 0 do
    new_buffer =
      if length(scroll.buffer) > new_max_height do
        Enum.take(scroll.buffer, new_max_height)
      else
        scroll.buffer
      end

    new_memory_usage = calculate_memory_usage(new_buffer)

    %__MODULE__{
      scroll
      | buffer: new_buffer,
        max_height: new_max_height,
        height: length(new_buffer),
        position: min(scroll.position, length(new_buffer) - 1) |> max(0),
        memory_usage: new_memory_usage,
        cache: %{}
    }
  end

  @doc """
  Resizes the scroll buffer to the new height.
  """
  def resize(%__MODULE__{} = scroll, new_height) do
    %{scroll | height: new_height, cache: %{}}
  end

  @doc """
  Updates the scroll buffer with new commands.
  """
  def update(scroll_buffer, _commands) do
    # Implementation for updating scroll buffer
    scroll_buffer
  end

  @doc """
  Cleans up the scroll buffer.
  """
  def cleanup(_scroll_buffer) do
    # Implementation for cleanup
    :ok
  end

  # Private Functions

  defp calculate_memory_usage(buffer) do
    Enum.reduce(buffer, 0, fn line, acc ->
      line_size = Enum.reduce(line, 0, fn cell, cell_acc ->
        cell_acc + byte_size(cell.content)
      end)
      acc + line_size
    end)
  end

  defp compress_buffer(buffer) do
    # Simple compression: remove empty cells and combine adjacent identical cells
    compressed = Enum.map(buffer, fn line ->
      Enum.chunk_by(line, &(&1.content == ""))
      |> Enum.map(fn chunk ->
        case chunk do
          [cell | _] -> cell
          [] -> Cell.new("")
        end
      end)
    end)

    {compressed, 0.5} # Assume 50% compression ratio
  end
end
