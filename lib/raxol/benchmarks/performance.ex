defmodule Raxol.Benchmarks.Performance do
  @moduledoc '''
  Performance benchmarking and validation tools for Raxol.

  This module provides utilities for measuring and validating performance metrics
  including rendering speed, memory usage, and event handling latency.
  '''

  alias Raxol.System.Platform
  alias Raxol.Benchmarks.Performance.Rendering
  alias Raxol.Benchmarks.Performance.EventHandling
  alias Raxol.Benchmarks.Performance.MemoryUsage
  alias Raxol.Benchmarks.Performance.Animation
  alias Raxol.Benchmarks.Performance.Validation
  alias Raxol.Benchmarks.Performance.Reporting

  @doc '''
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
  '''
  def run_all(opts \\ []) do
    ensure_keyword = fn
      kw when is_list(kw) and (kw == [] or is_tuple(hd(kw))) -> kw
      m when is_map(m) -> Map.to_list(m)
      _ -> []
    end

    opts =
      Keyword.merge(
        ensure_keyword.(
          save_results: true,
          compare_with_baseline: true,
          detailed: false
        ),
        ensure_keyword.(opts)
      )

    start_time = System.monotonic_time(:millisecond)
    IO.puts("\n=== Raxol Performance Benchmark Suite ===\n")

    # Run individual benchmarks
    render_results = Rendering.benchmark_rendering()
    event_results = EventHandling.benchmark_event_handling()
    memory_results = MemoryUsage.benchmark_memory_usage()
    animation_results = Animation.benchmark_animation_performance()

    # Compile all results
    results = %{
      timestamp: DateTime.utc_now(),
      platform: Platform.get_platform_info(),
      runtime_info: get_runtime_info(),
      render_performance: render_results,
      event_latency: event_results,
      memory_usage: memory_results,
      animation_fps: animation_results,
      execution_time: System.monotonic_time(:millisecond) - start_time
    }

    # Validate against baseline metrics
    validated_results =
      if opts[:compare_with_baseline] do
        baseline = Validation.get_baseline_metrics()
        validation = Validation.validate_metrics(results, baseline)
        Map.put(results, :metrics_validation, validation)
      else
        results
      end

    # Save results if requested
    if opts[:save_results] do
      _ = Reporting.save_benchmark_results(validated_results)
    end

    # Print summary
    Reporting.print_summary(validated_results, opts[:detailed])

    validated_results
  end

  # Private helper functions

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
