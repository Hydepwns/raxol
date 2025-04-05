defmodule Raxol.Terminal.Buffer.Manager do
  @moduledoc """
  Terminal buffer manager module.
  
  This module handles the management of terminal buffers, including:
  - Double buffering implementation
  - Damage tracking system
  - Buffer synchronization
  - Memory management
  """

  alias Raxol.Terminal.ScreenBuffer

  @type t :: %__MODULE__{
    active_buffer: ScreenBuffer.t(),
    back_buffer: ScreenBuffer.t(),
    damage_regions: list({non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}),
    memory_limit: non_neg_integer(),
    memory_usage: non_neg_integer()
  }

  defstruct [
    :active_buffer,
    :back_buffer,
    :damage_regions,
    :memory_limit,
    :memory_usage
  ]

  @doc """
  Creates a new buffer manager with the given dimensions.
  
  ## Examples
  
      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager.active_buffer.width
      80
      iex> manager.active_buffer.height
      24
  """
  def new(width, height, scrollback_height \\ 1000, memory_limit \\ 10_000_000) do
    active_buffer = ScreenBuffer.new(width, height, scrollback_height)
    back_buffer = ScreenBuffer.new(width, height, scrollback_height)
    
    %__MODULE__{
      active_buffer: active_buffer,
      back_buffer: back_buffer,
      damage_regions: [],
      memory_limit: memory_limit,
      memory_usage: 0
    }
  end

  @doc """
  Switches the active and back buffers.
  
  ## Examples
  
      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.switch_buffers(manager)
      iex> manager.active_buffer == manager.back_buffer
      false
  """
  def switch_buffers(%__MODULE__{} = manager) do
    %{manager | 
      active_buffer: manager.back_buffer,
      back_buffer: manager.active_buffer,
      damage_regions: []
    }
  end

  @doc """
  Marks a region of the buffer as damaged.
  
  ## Examples
  
      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.mark_damaged(manager, 0, 0, 10, 5)
      iex> length(manager.damage_regions)
      1
  """
  def mark_damaged(%__MODULE__{} = manager, x1, y1, x2, y2) do
    new_region = {x1, y1, x2, y2}
    
    # Merge overlapping regions
    merged_regions = merge_damage_regions([new_region | manager.damage_regions])
    
    %{manager | damage_regions: merged_regions}
  end

  @doc """
  Gets all damaged regions.
  
  ## Examples
  
      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.mark_damaged(manager, 0, 0, 10, 5)
      iex> regions = Buffer.Manager.get_damage_regions(manager)
      iex> length(regions)
      1
  """
  def get_damage_regions(%__MODULE__{} = manager) do
    manager.damage_regions
  end

  @doc """
  Clears all damage regions.
  
  ## Examples
  
      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.mark_damaged(manager, 0, 0, 10, 5)
      iex> manager = Buffer.Manager.clear_damage_regions(manager)
      iex> length(manager.damage_regions)
      0
  """
  def clear_damage_regions(%__MODULE__{} = manager) do
    %{manager | damage_regions: []}
  end

  @doc """
  Updates memory usage tracking.
  
  ## Examples
  
      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.update_memory_usage(manager)
      iex> manager.memory_usage > 0
      true
  """
  def update_memory_usage(%__MODULE__{} = manager) do
    # Calculate memory usage based on buffer sizes
    active_usage = calculate_buffer_memory_usage(manager.active_buffer)
    back_usage = calculate_buffer_memory_usage(manager.back_buffer)
    total_usage = active_usage + back_usage
    
    %{manager | memory_usage: total_usage}
  end

  @doc """
  Checks if memory usage is within limits.
  
  ## Examples
  
      iex> manager = Buffer.Manager.new(80, 24)
      iex> Buffer.Manager.within_memory_limits?(manager)
      true
  """
  def within_memory_limits?(%__MODULE__{} = manager) do
    manager.memory_usage <= manager.memory_limit
  end

  # Private functions

  defp merge_damage_regions(regions) do
    regions
    |> Enum.reduce([], fn region, acc ->
      case find_overlapping_region(acc, region) do
        nil -> [region | acc]
        {overlapping, rest} -> [merge_regions(overlapping, region) | rest]
      end
    end)
    |> Enum.reverse()
  end

  defp find_overlapping_region(regions, {x1, y1, x2, y2}) do
    Enum.split_with(regions, fn {rx1, ry1, rx2, ry2} ->
      x1 <= rx2 && x2 >= rx1 && y1 <= ry2 && y2 >= ry1
    end)
    |> case do
      {[overlapping], rest} -> {overlapping, rest}
      _ -> nil
    end
  end

  defp merge_regions({x1, y1, x2, y2}, {rx1, ry1, rx2, ry2}) do
    {
      min(x1, rx1),
      min(y1, ry1),
      max(x2, rx2),
      max(y2, ry2)
    }
  end

  defp calculate_buffer_memory_usage(buffer) do
    # Rough estimation of memory usage based on buffer size and content
    buffer_size = buffer.width * buffer.height
    cell_size = 100  # Estimated bytes per cell
    buffer_size * cell_size
  end
end 