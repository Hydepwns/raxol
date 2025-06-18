defmodule Raxol.Metrics.Collector do
  @moduledoc '''
  Collects and stores performance metrics for the Raxol event system.
  Works in conjunction with the Visualizer module to provide insights into system performance.
  '''

  use GenServer

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def record_event_timing(event_type, processing_time) do
    GenServer.cast(__MODULE__, {:record_timing, event_type, processing_time})
  end

  def record_throughput(events_count) do
    GenServer.cast(__MODULE__, {:record_throughput, events_count})
  end

  def record_memory_usage() do
    {:memory, memory} = :erlang.process_info(self(), :memory)
    GenServer.cast(__MODULE__, {:record_memory, memory})
  end

  def get_metrics() do
    GenServer.call(__MODULE__, :get_metrics)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok,
     %{
       timings: %{},
       throughput: [],
       memory_usage: [],
       start_time: System.system_time(:second)
     }}
  end

  @impl true
  def handle_cast({:record_timing, event_type, time}, state) do
    timings =
      Map.update(
        state.timings,
        event_type,
        [time],
        &[time | &1]
      )

    {:noreply, %{state | timings: timings}}
  end

  @impl true
  def handle_cast({:record_throughput, count}, state) do
    current_time = System.system_time(:second)
    throughput = [{current_time - state.start_time, count} | state.throughput]
    {:noreply, %{state | throughput: throughput}}
  end

  @impl true
  def handle_cast({:record_memory, memory}, state) do
    current_time = System.system_time(:second)
    memory_mb = memory / (1024 * 1024)

    memory_usage = [
      {current_time - state.start_time, memory_mb} | state.memory_usage
    ]

    {:noreply, %{state | memory_usage: memory_usage}}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      timings: state.timings,
      throughput: Enum.reverse(state.throughput),
      memory_usage: Enum.reverse(state.memory_usage)
    }

    {:reply, metrics, state}
  end
end
