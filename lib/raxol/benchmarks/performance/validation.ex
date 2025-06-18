defmodule Raxol.Benchmarks.Performance.Validation do
  @moduledoc '''
  Validation functions for Raxol performance benchmarks.
  '''

  alias Raxol.System.Platform

  @doc '''
  Validates performance against baseline requirements.

  ## Parameters

  * `results` - Current benchmark results
  * `baseline` - Baseline metrics to compare against

  ## Returns

  Map containing validation results and pass/fail status for each metric
  '''
  def validate_metrics(results, baseline) do
    # Define validators for each metric category
    validators = %{
      render_performance: &validate_render_metrics/2,
      event_latency: &validate_event_metrics/2,
      memory_usage: &validate_memory_metrics/2,
      animation_fps: &validate_animation_metrics/2
    }

    # Run each validator
    validations =
      Enum.map(validators, fn {category, validator_fn} ->
        result_metrics = Map.get(results, category, %{})
        baseline_metrics = Map.get(baseline, category, %{})

        {category, validator_fn.(result_metrics, baseline_metrics)}
      end)
      |> Enum.into(%{})

    # Calculate overall pass/fail status
    all_validations =
      validations
      |> Enum.flat_map(fn {_, category_validations} ->
        Map.values(category_validations)
      end)

    passed_validations =
      Enum.count(all_validations, fn {status, _} -> status == :pass end)

    total_validations = length(all_validations)

    pass_percentage =
      if total_validations > 0,
        do: passed_validations / total_validations * 100,
        else: 0

    overall_status =
      cond do
        pass_percentage >= 95 -> :excellent
        pass_percentage >= 80 -> :good
        pass_percentage >= 60 -> :acceptable
        true -> :failed
      end

    # Add overall results to validations
    Map.put(validations, :overall, %{
      status: overall_status,
      pass_percentage: pass_percentage,
      passed_validations: passed_validations,
      total_validations: total_validations
    })
  end

  @doc '''
  Retrieves baseline performance metrics for the current platform.

  If no platform-specific baseline exists, falls back to default baseline.
  '''
  def get_baseline_metrics do
    platform = Platform.get_current_platform()

    # Try to load platform-specific baseline
    platform_file =
      Path.join("priv/baseline_metrics", "#{platform}_baseline.json")

    baseline =
      if File.exists?(platform_file) do
        platform_file
        |> File.read!()
        |> Jason.decode!(keys: :atoms)
      else
        # Fall back to default baseline
        Path.join("priv/baseline_metrics", "default_baseline.json")
        |> File.read!()
        |> Jason.decode!(keys: :atoms)
      end

    baseline
  end

  # Private helper functions

  defp validate_render_metrics(results, baseline) do
    metrics = [
      {:simple_component_time_μs, &<=/2, "Simple component render time"},
      {:medium_component_time_μs, &<=/2, "Medium component render time"},
      {:complex_component_time_μs, &<=/2, "Complex component render time"},
      {:full_screen_render_time_ms, &<=/2, "Full screen render time"},
      {:components_per_frame, &>=/2, "Components per frame (60 FPS)"},
      {:renders_per_second, &>=/2, "Full screen renders per second"}
    ]

    validate_metric_list(results, baseline, metrics)
  end

  defp validate_event_metrics(results, baseline) do
    metrics = [
      {:keyboard_event_latency_μs, &<=/2, "Keyboard event latency"},
      {:mouse_event_latency_μs, &<=/2, "Mouse event latency"},
      {:window_event_latency_μs, &<=/2, "Window event latency"},
      {:custom_event_latency_μs, &<=/2, "Custom event latency"},
      {:burst_events_latency_μs, &<=/2, "Burst events latency"},
      {:events_per_second, &>=/2, "Events processed per second"}
    ]

    validate_metric_list(results, baseline, metrics)
  end

  defp validate_memory_metrics(results, baseline) do
    metrics = [
      {:simple_component_memory_bytes, &<=/2, "Simple component memory usage"},
      {:medium_component_memory_bytes, &<=/2, "Medium component memory usage"},
      {:complex_component_memory_bytes, &<=/2,
       "Complex component memory usage"},
      {:rendering_memory_growth_kb, &<=/2, "Memory growth during rendering"},
      {:memory_efficiency_score, &>=/2, "Memory efficiency score"}
    ]

    # Add memory leak validation
    leak_validation =
      if results[:memory_leak_detected] do
        {:memory_leak_detected, :fail, "Memory leak detected", true}
      else
        {:memory_leak_detected, :pass, "No memory leak detected", false}
      end

    regular_validations = validate_metric_list(results, baseline, metrics)
    Map.put(regular_validations, :memory_leak_detected, leak_validation)
  end

  defp validate_animation_metrics(results, baseline) do
    metrics = [
      {:maximum_fps, &>=/2, "Maximum achievable FPS"},
      {:frame_time_consistency_ms, &<=/2,
       "Frame time consistency (lower is better)"},
      {:dropped_frames_percent, &<=/2, "Dropped frames percentage"},
      {:cpu_usage_percent, &<=/2, "CPU usage during animation"},
      {:animation_smoothness_score, &>=/2, "Animation smoothness score"}
    ]

    validate_metric_list(results, baseline, metrics)
  end

  defp validate_metric_list(results, baseline, metrics) do
    Enum.map(metrics, fn {metric, comparator, label} ->
      result_value = Map.get(results, metric)
      baseline_value = Map.get(baseline, metric)

      validation_result =
        cond do
          is_nil(result_value) ->
            {:skip, "Metric not measured"}

          is_nil(baseline_value) ->
            {:skip, "No baseline for comparison"}

          comparator.(result_value, baseline_value) ->
            {:pass, "#{label}: #{result_value} (baseline: #{baseline_value})"}

          true ->
            {:fail, "#{label}: #{result_value} (baseline: #{baseline_value})"}
        end

      {metric, validation_result}
    end)
    |> Enum.into(%{})
  end
end
