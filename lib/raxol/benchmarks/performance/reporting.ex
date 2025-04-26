defmodule Raxol.Benchmarks.Performance.Reporting do
  @moduledoc """
  Reporting functions (saving, printing) for Raxol performance benchmarks.
  """

  @doc """
  Saves benchmark results to a file.

  ## Parameters

  * `results` - Benchmark results map
  * `file_path` - Path to save results (default: auto-generated)
  """
  def save_benchmark_results(results, file_path \\ nil) do
    # Ensure the results directory exists
    File.mkdir_p!("_build/benchmark_results")

    # Generate a filename if not provided
    file_path =
      file_path ||
        "_build/benchmark_results/raxol_performance_#{System.os_time(:second)}.json"

    # Convert results to JSON
    json_data = Jason.encode!(results, pretty: true)

    # Write to file
    File.write!(file_path, json_data)

    IO.puts("\nResults saved to: #{file_path}")
    {:ok, file_path}
  end

  defp print_summary(results, detailed) do
    IO.puts("\n=== Performance Benchmark Summary ===\n")
    IO.puts("Platform: #{results.platform.name} #{results.platform.version}")
    IO.puts("Architecture: #{results.platform.architecture}")
    IO.puts("Terminal: #{results.platform.terminal}")
    IO.puts("Execution time: #{results.execution_time}ms\n")

    IO.puts("Rendering Performance:")

    IO.puts(
      "- Simple component: #{Float.round(results.render_performance.simple_component_time_μs, 2)}μs"
    )

    IO.puts(
      "- Full screen render: #{Float.round(results.render_performance.full_screen_render_time_ms, 2)}ms"
    )

    IO.puts(
      "- Components per frame (60 FPS): #{results.render_performance.components_per_frame}"
    )

    IO.puts("\nEvent Handling:")

    IO.puts(
      "- Keyboard event latency: #{Float.round(results.event_latency.keyboard_event_latency_μs, 2)}μs"
    )

    IO.puts("- Events per second: #{results.event_latency.events_per_second}")

    IO.puts("\nMemory Usage:")

    IO.puts(
      "- Memory efficiency score: #{results.memory_usage.memory_efficiency_score}/100"
    )

    IO.puts(
      "- Memory leak detected: #{results.memory_usage.memory_leak_detected}"
    )

    IO.puts("\nAnimation Performance:")
    IO.puts("- Maximum FPS: #{results.animation_fps.maximum_fps}")

    IO.puts(
      "- Animation smoothness score: #{results.animation_fps.animation_smoothness_score}/100"
    )

    IO.puts(
      "- Dropped frames: #{results.animation_fps.dropped_frames_percent}%"
    )

    if Map.has_key?(results, :metrics_validation) do
      validation = results.metrics_validation

      IO.puts("\n=== Validation Results ===\n")
      IO.puts("Overall status: #{validation.overall.status}")

      IO.puts(
        "Pass rate: #{Float.round(validation.overall.pass_percentage, 1)}% (#{validation.overall.passed_validations}/#{validation.overall.total_validations})"
      )

      if detailed do
        print_detailed_validation(validation)
      end
    end

    IO.puts("\nBenchmark complete.")
  end

  defp print_detailed_validation(validation) do
    categories = [
      :render_performance,
      :event_latency,
      :memory_usage,
      :animation_fps
    ]

    Enum.each(categories, fn category ->
      category_results = Map.get(validation, category, %{})

      category_name =
        category
        |> to_string()
        |> String.replace("_", " ")
        |> String.capitalize()

      IO.puts("\n#{category_name}:")

      if map_size(category_results) > 0 do
        Enum.each(category_results, fn {_metric, {status, message}} ->
          status_icon =
            case status do
              :pass -> "✓"
              :fail -> "✗"
              :skip -> "?"
            end

          IO.puts("  #{status_icon} #{message}")
        end)
      else
        IO.puts("  No validation results available")
      end
    end)
  end
end
