defmodule Raxol.Core.Performance.MetricsCollector do
  @moduledoc """
  Collects and calculates performance metrics.

  This module tracks:
  - Frame rate (FPS)
  - Frame timing statistics
  - Memory usage
  - Garbage collection statistics

  ## Usage

  ```elixir
  # Create a new collector
  collector = MetricsCollector.new()

  # Record a frame
  collector = MetricsCollector.record_frame(collector, 16)

  # Get current FPS
  fps = MetricsCollector.get_fps(collector)

  # Update memory metrics
  collector = MetricsCollector.update_memory_usage(collector)
  ```
  """

  defstruct [
    :frame_times,
    :memory_usage,
    :gc_stats,
    :last_gc_time,
    :last_memory_usage
  ]

  @doc """
  Creates a new metrics collector.

  ## Returns

  A new metrics collector struct.

  ## Examples

      iex> MetricsCollector.new()
      %MetricsCollector{
        frame_times: [],
        memory_usage: 0,
        gc_stats: %{},
        last_gc_time: 0
      }
  """
  def new do
    %__MODULE__{
      frame_times: [],
      memory_usage: 0,
      gc_stats: %{},
      last_gc_time: 0
    }
  end

  @doc """
  Records a frame's timing.

  ## Parameters

  * `collector` - The metrics collector
  * `frame_time` - Time taken to render the frame in milliseconds

  ## Returns

  Updated metrics collector.

  ## Examples

      iex> collector = MetricsCollector.new()
      iex> collector = MetricsCollector.record_frame(collector, 16)
      iex> length(collector.frame_times)
      1
  """
  def record_frame(collector, frame_time) do
    # Add frame time to history (keep last 60 frames)
    frame_times =
      [frame_time | collector.frame_times]
      |> Enum.take(60)

    %{collector | frame_times: frame_times}
  end

  @doc """
  Gets the current frames per second.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Current FPS as a float.

  ## Examples

      iex> collector = MetricsCollector.new()
      iex> collector = MetricsCollector.record_frame(collector, 16)
      iex> MetricsCollector.get_fps(collector)
      62.5
  """
  def get_fps(collector) do
    case collector.frame_times do
      [] ->
        0.0

      times ->
        avg_frame_time = Enum.sum(times) / length(times)
        if avg_frame_time > 0, do: 1000 / avg_frame_time, else: 0.0
    end
  end

  @doc """
  Gets the average frame time.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Average frame time in milliseconds.

  ## Examples

      iex> collector = MetricsCollector.new()
      iex> collector = MetricsCollector.record_frame(collector, 16)
      iex> MetricsCollector.get_avg_frame_time(collector)
      16.0
  """
  def get_avg_frame_time(collector) do
    case collector.frame_times do
      [] -> 0.0
      times -> Enum.sum(times) / length(times)
    end
  end

  @doc """
  Updates memory usage metrics.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Updated metrics collector with current memory usage and GC stats.

  ## Examples

      iex> collector = MetricsCollector.new()
      iex> collector = MetricsCollector.update_memory_usage(collector)
      iex> collector.memory_usage > 0
      true
  """
  def update_memory_usage(collector) do
    # Get current memory usage
    memory_usage = :erlang.memory(:total)

    # Get GC statistics
    gc_stats = :erlang.statistics(:garbage_collection)

    %{
      collector
      | memory_usage: memory_usage,
        gc_stats: gc_stats,
        last_gc_time: System.system_time(:millisecond),
        last_memory_usage: collector.memory_usage
    }
  end

  @doc """
  Gets the memory usage trend.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Memory usage trend as a percentage change.

  ## Examples

      iex> collector = MetricsCollector.new()
      iex> collector = MetricsCollector.update_memory_usage(collector)
      iex> collector = MetricsCollector.update_memory_usage(collector)
      iex> MetricsCollector.get_memory_trend(collector)
      0.0
  """
  def get_memory_trend(collector) do
    case {collector.last_gc_time, collector.last_memory_usage} do
      {0, _} ->
        0.0

      {last_time, last_memory} when is_integer(last_memory) and last_memory > 0 ->
        current_time = System.system_time(:millisecond)
        time_diff = current_time - last_time

        if time_diff > 0 do
          # Calculate memory growth rate
          memory_growth = collector.memory_usage - last_memory
          # Convert to bytes per second
          memory_growth / time_diff * 1000
        else
          0.0
        end

      _ ->
        0.0
    end
  end

  @doc """
  Gets garbage collection statistics.

  ## Parameters

  * `collector` - The metrics collector

  ## Returns

  Map containing GC statistics:
  * `:number_of_gcs` - Total number of garbage collections
  * `:words_reclaimed` - Total words reclaimed
  * `:heap_size` - Current heap size
  * `:heap_limit` - Maximum heap size

  ## Examples

      iex> collector = MetricsCollector.new()
      iex> collector = MetricsCollector.update_memory_usage(collector)
      iex> gc_stats = MetricsCollector.get_gc_stats(collector)
      iex> Map.has_key?(gc_stats, :number_of_gcs)
      true
  """
  def get_gc_stats(collector) do
    case collector.gc_stats do
      {number_of_gcs, words_reclaimed, heap_size, heap_limit} ->
        %{
          number_of_gcs: number_of_gcs,
          words_reclaimed: words_reclaimed,
          heap_size: heap_size,
          heap_limit: heap_limit
        }

      _ ->
        %{
          number_of_gcs: 0,
          words_reclaimed: 0,
          heap_size: 0,
          heap_limit: 0
        }
    end
  end
end
