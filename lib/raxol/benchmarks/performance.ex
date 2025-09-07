defmodule Raxol.Benchmarks.Performance do
  @moduledoc """
  Performance benchmarking and validation tools for Raxol.

  This module provides utilities for measuring and validating performance metrics
  including rendering speed, memory usage, and event handling latency.
  """

  alias Raxol.System.Platform
  alias Raxol.Benchmarks.Performance.Rendering
  alias Raxol.Benchmarks.Performance.EventHandling
  alias Raxol.Benchmarks.Performance.MemoryUsage
  alias Raxol.Benchmarks.Performance.Animation
  alias Raxol.Benchmarks.Performance.Validation
  alias Raxol.Benchmarks.Performance.Reporting

  @doc """
  Runs all performance benchmarks and returns the results.

  ## Options

  * `:save_results` - Save results to file (default: `true`)
  * `:compare_with_baseline` - Compare with baseline metrics (default: `true`)
  * `:detailed` - Include detailed metrics (default: `false`)

  ## Returns

  Map containing benchmark results with the following structure:

  ```
  %{
    render_performance: %{...},
    event_latency: %{...},
    memory_usage: %{...},
    animation_fps: %{...},
    metrics_validation: %{...}
  }
  ```
  """
  def run_all(opts \\ []) do
    execute_benchmark_suite(normalize_opts(opts))
  end

  defp execute_benchmark_suite(opts) do
    start_time = System.monotonic_time(:millisecond)
    IO.puts("\n=== Raxol Performance Benchmark Suite ===\n")

    results = run_benchmarks(start_time)
    validated_results = validate_results(results, opts)

    maybe_save_results(validated_results, opts)
    Reporting.print_summary(validated_results, opts[:detailed])

    validated_results
  end

  defp maybe_save_results(results, opts) do
    opts[:save_results] && Reporting.save_benchmark_results(results)
  end

  defp normalize_opts(opts) do
    default_opts = [
      save_results: true,
      compare_with_baseline: true,
      detailed: false
    ]

    Keyword.merge(default_opts, normalize_to_keyword(opts))
  end

  defp normalize_to_keyword(opts) when is_list(opts) and opts == [] do
    []
  end

  defp normalize_to_keyword(opts) when is_list(opts) and is_tuple(hd(opts)) do
    opts
  end

  defp normalize_to_keyword(opts) when is_map(opts) do
    Map.to_list(opts)
  end

  defp normalize_to_keyword(_) do
    []
  end

  defp run_benchmarks(start_time) do
    %{
      timestamp: DateTime.utc_now(),
      platform: Platform.get_platform_info(),
      runtime_info: get_runtime_info(),
      render_performance: Rendering.benchmark_rendering(),
      event_latency: EventHandling.benchmark_event_handling(),
      memory_usage: MemoryUsage.benchmark_memory_usage(),
      animation_fps: Animation.benchmark_animation_performance(),
      execution_time: System.monotonic_time(:millisecond) - start_time
    }
  end

  defp validate_results(results, opts) do
    case opts[:compare_with_baseline] do
      true ->
        baseline = Validation.get_baseline_metrics()
        validation = Validation.validate_metrics(results, baseline)
        Map.put(results, :metrics_validation, validation)

      _ ->
        results
    end
  end

  defp get_runtime_info do
    %{
      elixir_version: System.version(),
      otp_version: :erlang.system_info(:otp_release) |> List.to_string(),
      system_architecture:
        :erlang.system_info(:system_architecture) |> List.to_string(),
      logical_processors: :erlang.system_info(:logical_processors_available),
      process_count: :erlang.system_info(:process_count),
      atom_count: :erlang.system_info(:atom_count)
    }
  end
end
