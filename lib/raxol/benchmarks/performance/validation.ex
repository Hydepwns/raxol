defmodule Raxol.Benchmarks.Performance.Validation do
  @moduledoc """
  Validation functions for Raxol performance benchmarks.
  """

  alias Raxol.System.Platform

  @doc """
  Validates performance against baseline requirements.

  ## Parameters

  * `results` - Current benchmark results
  * `baseline` - Baseline metrics to compare against

  ## Returns

  Map containing validation results and pass/fail status for each metric
  """
  def validate_metrics(results, baseline) do
    validations = run_all_validators(results, baseline)
    overall_status = calculate_overall_status(validations)

    Map.put(validations, :overall, overall_status)
  end

  defp run_all_validators(results, baseline) do
    validators = %{
      render_performance: &validate_render_metrics/2,
      event_latency: &validate_event_metrics/2,
      memory_usage: &validate_memory_metrics/2,
      animation_fps: &validate_animation_metrics/2
    }

    Enum.map(validators, fn {category, validator_fn} ->
      result_metrics = Map.get(results, category, %{})
      baseline_metrics = Map.get(baseline, category, %{})
      {category, validator_fn.(result_metrics, baseline_metrics)}
    end)
    |> Enum.into(%{})
  end

  defp calculate_overall_status(validations) do
    all_validations = extract_all_validations(validations)
    {passed, total} = count_passed_validations(all_validations)
    pass_percentage = calculate_pass_percentage(passed, total)

    %{
      status: determine_status(pass_percentage),
      pass_percentage: pass_percentage,
      passed_validations: passed,
      total_validations: total
    }
  end

  defp extract_all_validations(validations) do
    validations
    |> Enum.flat_map(fn {_, category_validations} ->
      Map.values(category_validations)
    end)
  end

  defp count_passed_validations(all_validations) do
    passed =
      Enum.count(all_validations, fn
        %{status: status} when status in [:pass, :skip] -> true
        {_metric, %{status: status}} when status in [:pass, :skip] -> true
        _ -> false
      end)

    {passed, length(all_validations)}
  end

  defp calculate_pass_percentage(passed, total) do
    if total > 0, do: passed / total * 100, else: 0
  end

  defp determine_status(pass_percentage) when pass_percentage >= 95,
    do: :excellent

  defp determine_status(pass_percentage) when pass_percentage >= 80, do: :good

  defp determine_status(pass_percentage) when pass_percentage >= 60,
    do: :acceptable

  defp determine_status(_pass_percentage), do: :failed

  @doc """
  Retrieves baseline performance metrics for the current platform.

  If no platform-specific baseline exists, falls back to default baseline.
  """
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
        %{status: :fail, message: "Memory leak detected", detected: true}
      else
        %{status: :pass, message: "No memory leak detected", detected: false}
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
        validate_metric_value(result_value, baseline_value, comparator, label)

      {metric, validation_result}
    end)
    |> Enum.into(%{})
  end

  # Helper functions for pattern matching refactoring

  defp validate_metric_value(nil, _baseline_value, _comparator, _label),
    do: %{status: :skip, message: "Metric not measured"}

  defp validate_metric_value(_result_value, nil, _comparator, _label),
    do: %{status: :skip, message: "No baseline for comparison"}

  defp validate_metric_value(result_value, baseline_value, comparator, label) do
    if comparator.(result_value, baseline_value) do
      %{
        status: :pass,
        message: "#{label}: #{result_value} (baseline: #{baseline_value})"
      }
    else
      %{
        status: :fail,
        message: "#{label}: #{result_value} (baseline: #{baseline_value})"
      }
    end
  end
end
