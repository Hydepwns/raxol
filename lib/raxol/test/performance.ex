defmodule Raxol.Test.Performance do
  @moduledoc '''
  Provides utilities for performance testing of Raxol components.

  This module includes:
  - Render time benchmarking
  - Memory usage profiling
  - Event handling latency testing
  - Resource utilization tracking
  '''

  alias Raxol.Test.Visual

  defmacro __using__(_opts) do
    quote do
      import Raxol.Test.Performance
      import Raxol.Test.Performance.Assertions

      setup do
        context = setup_benchmark_environment()
        {:ok, context}
      end
    end
  end

  @doc '''
  Sets up a component for performance testing with benchmark configuration.
  '''
  def setup_benchmark_component(module, props \\ %{}) do
    component = Visual.setup_visual_component(module, props)
    Map.put(component, :benchmark_config, default_benchmark_config())
  end

  @doc '''
  Measures the time taken to render a component multiple times.
  '''
  def measure_render_time(component, iterations \\ 1000) do
    {time, _} =
      :timer.tc(fn ->
        Enum.each(1..iterations, fn _ ->
          Visual.capture_render(component)
        end)
      end)

    # Convert to milliseconds
    time / 1_000
  end

  @doc '''
  Measures memory usage during component operations.
  '''
  def measure_memory_usage(component, operation)
      when is_function(operation, 1) do
    initial = :erlang.memory()
    operation.(component)
    final = :erlang.memory()

    %{
      total: final[:total] - initial[:total],
      processes: final[:processes] - initial[:processes],
      atom: final[:atom] - initial[:atom],
      binary: final[:binary] - initial[:binary],
      code: final[:code] - initial[:code]
    }
  end

  @doc '''
  Measures event handling latency.
  '''
  def measure_event_latency(component, event) do
    {time, _} =
      :timer.tc(fn ->
        simulate_event(component, event)
      end)

    # Convert to milliseconds
    time / 1_000
  end

  @doc '''
  Runs a benchmark suite for a component.
  '''
  def run_benchmark_suite(component) do
    %{
      render_time: measure_render_time(component),
      memory_usage: measure_memory_usage(component, &Visual.capture_render/1),
      event_latency: measure_event_latency(component, :benchmark_event)
    }
  end

  @doc '''
  Tracks resource utilization over time.
  '''
  def track_resource_utilization(_component, duration_ms) do
    # Track memory usage
    initial_memory = :erlang.memory()
    Process.sleep(duration_ms)
    final_memory = :erlang.memory()

    %{
      memory_delta: final_memory[:total] - initial_memory[:total],
      duration_ms: duration_ms
    }
  end

  # Private Helpers

  defp default_benchmark_config do
    %{
      iterations: 1000,
      warmup: 100,
      # ms
      max_render_time: 100,
      # 1MB
      max_memory_usage: 1024 * 1024,
      # ms
      max_event_latency: 10
    }
  end

  defp simulate_event(component, _event) do
    # Simulate event handling
    Process.sleep(10)
    component
  end
end
