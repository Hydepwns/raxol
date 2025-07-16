defmodule Raxol.Core.Performance.Monitor do
  @moduledoc """
  Performance monitoring system for Raxol applications.

  This module provides tools for:
  - Frame rate monitoring
  - Memory usage tracking
  - UI jank detection
  - Performance metrics collection
  - Performance visualization

  ## Usage

  ```elixir
  # Start monitoring
  {:ok, monitor} = Monitor.start_link()

  # Record frame timing
  Monitor.record_frame(monitor, 16)  # 16ms frame time

  # Check for jank
  if Monitor.detect_jank?(monitor) do
    Raxol.Core.Runtime.Log.warning_with_context("UI jank detected", %{})
  end

  # Get performance metrics
  metrics = Monitor.get_metrics(monitor)
  ```
  """

  use GenServer

  @default_jank_threshold 16
  @default_memory_check_interval 5000

  # Client API

  @doc """
  Starts a new performance monitor.

  ## Options

  * `:jank_threshold` - Time in milliseconds above which a frame is considered janky (default: 16)
  * `:sample_size` - Number of frames to keep in the rolling window (default: 60)
  * `:memory_check_interval` - How often to check memory usage in milliseconds (default: 5000)

  ## Examples

      iex> {:ok, monitor} = Monitor.start_link()
      {:ok, #PID<0.123.0>}

      iex> {:ok, monitor} = Monitor.start_link(jank_threshold: 20)
      {:ok, #PID<0.124.0>}
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Records a frame's timing.

  ## Parameters

  * `monitor` - The monitor process
  * `frame_time` - Time taken to render the frame in milliseconds

  ## Examples

      iex> Monitor.record_frame(monitor, 16)
      :ok
  """
  def record_frame(monitor, frame_time) do
    GenServer.cast(monitor, {:record_frame, frame_time})
  end

  @doc """
  Checks if jank was detected in the last frame.

  ## Parameters

  * `monitor` - The monitor process

  ## Returns

  * `true` if jank was detected
  * `false` otherwise

  ## Examples

      iex> Monitor.detect_jank?(monitor)
      false
  """
  def detect_jank?(monitor) do
    GenServer.call(monitor, :detect_jank?)
  end

  @doc """
  Gets current performance metrics.

  ## Parameters

  * `monitor` - The monitor process

  ## Returns

  Map containing performance metrics:
  * `:fps` - Current frames per second
  * `:avg_frame_time` - Average frame time in milliseconds
  * `:jank_count` - Number of janky frames in the sample window
  * `:memory_usage` - Current memory usage in bytes
  * `:gc_stats` - Garbage collection statistics

  ## Examples

      iex> Monitor.get_metrics(monitor)
      %{
        fps: 60,
        avg_frame_time: 16.5,
        jank_count: 2,
        memory_usage: 1234567,
        gc_stats: %{...}
      }
  """
  def get_metrics(monitor) do
    GenServer.call(monitor, :get_metrics)
  end

  def reset_metrics(monitor) do
    GenServer.cast(monitor, :reset_metrics)
  end

  # Server Callbacks

  @impl GenServer
  def init(opts) do
    jank_threshold = Keyword.get(opts, :jank_threshold, @default_jank_threshold)

    memory_check_interval =
      Keyword.get(opts, :memory_check_interval, @default_memory_check_interval)

    parent_pid = Keyword.get(opts, :parent_pid)

    state = %{
      frame_times: [],
      jank_count: 0,
      jank_threshold: jank_threshold,
      memory_check_interval: memory_check_interval,
      last_memory_check: System.monotonic_time(),
      parent_pid: parent_pid
    }

    schedule_memory_check(memory_check_interval)
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:record_frame, frame_time}, state) do
    new_frame_times = [frame_time | state.frame_times] |> Enum.take(60)

    new_jank_count =
      if detect_jank?(frame_time, state.jank_threshold),
        do: state.jank_count + 1,
        else: state.jank_count

    {:noreply,
     %{state | frame_times: new_frame_times, jank_count: new_jank_count}}
  end

  @impl GenServer
  def handle_cast(:reset_metrics, state) do
    {:noreply, %{state | frame_times: [], jank_count: 0}}
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    fps = calculate_fps(state.frame_times)
    avg_frame_time = calculate_avg_frame_time(state.frame_times)
    memory_usage = get_memory_usage()
    gc_stats = :erlang.statistics(:garbage_collection)

    metrics = %{
      fps: fps,
      avg_frame_time: avg_frame_time,
      jank_count: state.jank_count,
      memory_usage: memory_usage,
      gc_stats: gc_stats
    }

    {:reply, metrics, state}
  end

  @impl GenServer
  def handle_call(:detect_jank?, _from, state) do
    jank_detected =
      case state.frame_times do
        [latest | _] -> detect_jank?(latest, state.jank_threshold)
        [] -> false
      end

    {:reply, jank_detected, state}
  end

  @impl GenServer
  def handle_info(:check_memory, state) do
    memory_usage = get_memory_usage()
    # Send memory check message to parent process if specified
    if state.parent_pid do
      send(state.parent_pid, {:memory_check, memory_usage})
    end

    send(self(), {:memory_check, memory_usage})
    schedule_memory_check(state.memory_check_interval)
    {:noreply, %{state | last_memory_check: System.monotonic_time()}}
  end

  @impl GenServer
  def handle_info({:memory_check, _memory_usage}, state) do
    # Handle the memory check message (currently just ignore it)
    {:noreply, state}
  end

  # Private Helpers

  defp detect_jank?(frame_time, threshold) do
    adjusted_threshold = get_jank_threshold(threshold)
    frame_time > adjusted_threshold
  end

  defp get_jank_threshold(base_threshold) do
    if Raxol.Core.Preferences.get_preference(:reduced_motion, false) do
      # Higher threshold for reduced motion (less sensitive to jank)
      base_threshold * 2
    else
      base_threshold
    end
  end

  defp calculate_fps(frame_times) do
    case frame_times do
      [] -> 0.0
      times -> 1000 / (Enum.sum(times) / length(times))
    end
  end

  defp calculate_avg_frame_time(frame_times) do
    case frame_times do
      [] -> 0.0
      times -> Enum.sum(times) / length(times)
    end
  end

  defp get_memory_usage do
    :erlang.memory(:total)
  end

  defp schedule_memory_check(interval) do
    Process.send_after(self(), :check_memory, interval)
  end
end
