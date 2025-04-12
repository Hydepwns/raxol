defmodule Raxol.Test.Performance.Assertions do
  @moduledoc """
  Provides assertions for performance testing of Raxol components.

  This module includes assertions for:
  - Render time thresholds
  - Memory usage limits
  - Event latency requirements
  - Resource utilization bounds
  """

  import ExUnit.Assertions
  alias Raxol.Test.Performance

  @doc """
  Asserts that a component renders within a specified time limit.

  ## Example

      assert_render_time component, fn ->
        render_iterations(component, 1000)
      end, under: 100 # milliseconds
  """
  def assert_render_time(component, operation, opts \\ []) do
    time = Performance.measure_render_time(component, operation)

    threshold =
      Keyword.get(opts, :under, component.benchmark_config.max_render_time)

    assert time <= threshold,
           "Render time #{time}ms exceeds threshold of #{threshold}ms"
  end

  @doc """
  Asserts that a component's memory usage stays within specified limits.

  ## Example

      assert_memory_usage component, fn ->
        render_with_large_dataset(component)
      end, under: 1024 * 1024 # 1MB
  """
  def assert_memory_usage(component, operation, opts \\ []) do
    usage = Performance.measure_memory_usage(component, operation)

    threshold =
      Keyword.get(opts, :under, component.benchmark_config.max_memory_usage)

    assert usage.total <= threshold,
           "Memory usage #{usage.total} bytes exceeds threshold of #{threshold} bytes"

    # Return detailed memory stats for analysis
    {:ok, usage}
  end

  @doc """
  Asserts that event handling latency stays within acceptable bounds.

  ## Example

      assert_event_latency component, :click, under: 10 # milliseconds
  """
  def assert_event_latency(component, event, opts \\ []) do
    latency = Performance.measure_event_latency(component, event)

    threshold =
      Keyword.get(opts, :under, component.benchmark_config.max_event_latency)

    assert latency <= threshold,
           "Event latency #{latency}ms exceeds threshold of #{threshold}ms"
  end

  @doc """
  Asserts that a component's resource utilization remains stable.

  ## Example

      assert_stable_resource_usage component, duration: 1000
  """
  def assert_stable_resource_usage(component, opts \\ []) do
    duration = Keyword.get(opts, :duration, 1000)
    measurements = Performance.track_resource_utilization(component, duration)

    # Analyze memory stability
    memory_trend = analyze_trend(measurements, & &1.memory[:total])

    assert memory_trend.stable?,
           "Memory usage is not stable: #{inspect(memory_trend)}"

    # Analyze process count stability
    process_trend = analyze_trend(measurements, & &1.process_count)

    assert process_trend.stable?,
           "Process count is not stable: #{inspect(process_trend)}"

    {:ok, %{memory: memory_trend, processes: process_trend}}
  end

  @doc """
  Asserts that a component's performance metrics meet all requirements.

  ## Example

      assert_performance_requirements component, %{
        render_time: 100,
        memory_usage: 1024 * 1024,
        event_latency: 10
      }
  """
  def assert_performance_requirements(component, requirements) do
    results = Performance.run_benchmark_suite(component)

    Enum.each(requirements, fn {metric, threshold} ->
      value = get_in(results, [metric])

      assert value <= threshold,
             "#{metric} #{value} exceeds requirement of #{threshold}"
    end)

    {:ok, results}
  end

  @doc """
  Asserts that a component's performance hasn't regressed from baseline.

  ## Example

      assert_no_performance_regression component, "button_baseline"
  """
  def assert_no_performance_regression(component, baseline_name) do
    current = Performance.run_benchmark_suite(component)
    baseline = load_performance_baseline(baseline_name)

    Enum.each([:render_time, :memory_usage, :event_latency], fn metric ->
      current_value = get_in(current, [metric])
      baseline_value = get_in(baseline, [metric])

      # Allow for some variation (e.g., 10% above baseline)
      threshold = baseline_value * 1.1

      assert current_value <= threshold,
             """
             Performance regression detected for #{metric}:
             Current: #{current_value}
             Baseline: #{baseline_value}
             Threshold: #{threshold}
             """
    end)
  end

  # Private Helpers

  defp analyze_trend(measurements, value_fn) do
    values = Enum.map(measurements, value_fn)
    mean = Enum.sum(values) / length(values)
    stddev = calculate_stddev(values, mean)

    %{
      mean: mean,
      stddev: stddev,
      # Consider stable if stddev is within 10% of mean
      stable?: stddev / mean <= 0.1
    }
  end

  defp calculate_stddev(values, mean) do
    variance =
      Enum.reduce(values, 0, fn value, acc ->
        diff = value - mean
        acc + diff * diff
      end) / length(values)

    :math.sqrt(variance)
  end

  defp load_performance_baseline(_name) do
    # baseline_path = get_baseline_path()

    # Add baseline loading logic
    # For now, return default values
    %{
      render_time: 50,
      memory_usage: 512 * 1024,
      event_latency: 5
    }
  end

  # Placeholder function
  # defp get_baseline_path() do
  #   # TODO: Define logic to get the actual baseline path
  #   "test/performance/baselines/default.json"
  # end
end
