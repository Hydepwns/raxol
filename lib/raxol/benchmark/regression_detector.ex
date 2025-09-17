defmodule Raxol.Benchmark.RegressionDetector do
  @moduledoc """
  Detects performance regressions by comparing current results with baselines.
  Uses statistical methods to determine significant performance changes.
  """

  alias Raxol.Benchmark.StatisticalAnalyzer

  # 5% regression threshold
  @default_threshold 0.05
  # 95% confidence for statistical tests
  @confidence_level 0.95

  @doc """
  Detect regressions by comparing current results with baseline.
  """
  def detect(current_results, baseline_results, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    method = Keyword.get(opts, :method, :statistical)

    comparison = compare_results(current_results, baseline_results, method)

    %{
      summary: generate_summary(comparison),
      regressions: find_regressions(comparison, threshold),
      improvements: find_improvements(comparison, threshold),
      stable: find_stable(comparison, threshold),
      detailed_analysis: comparison,
      recommendations: generate_recommendations(comparison, threshold)
    }
  end

  @doc """
  Perform continuous regression monitoring.
  """
  def monitor(results_history, opts \\ []) do
    window_size = Keyword.get(opts, :window_size, 10)

    results_history
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.take(window_size)
    |> Enum.map_join(fn [newer, older] ->
      detect(newer, older, opts)
    end)
    |> analyze_trends()
  end

  @doc """
  Check if a specific metric has regressed.
  """
  def has_regressed?(current, baseline, metric, threshold \\ @default_threshold) do
    case {get_metric_value(current, metric), get_metric_value(baseline, metric)} do
      {nil, _} ->
        {:error, :current_metric_missing}

      {_, nil} ->
        {:error, :baseline_metric_missing}

      {current_val, baseline_val} ->
        percent_change = (current_val - baseline_val) / baseline_val
        regressed = percent_change > threshold

        {regressed, percent_change}
    end
  end

  @doc """
  Generate a regression report.
  """
  def generate_report(detection_results, opts \\ []) do
    format = Keyword.get(opts, :format, :text)

    case format do
      :text -> generate_text_report(detection_results)
      :json -> generate_json_report(detection_results)
      :html -> generate_html_report(detection_results)
      :markdown -> generate_markdown_report(detection_results)
    end
  end

  @doc """
  Calculate regression severity.
  """
  def calculate_severity(percent_change) do
    abs_change = abs(percent_change)

    cond do
      abs_change < 0.05 -> :negligible
      abs_change < 0.10 -> :minor
      abs_change < 0.25 -> :moderate
      abs_change < 0.50 -> :major
      true -> :critical
    end
  end

  @doc """
  Perform trend analysis on historical data.
  """
  def analyze_trend(time_series_data) do
    values = Enum.map(time_series_data, fn {_time, value} -> value end)
    times = Enum.map(time_series_data, fn {time, _value} -> time end)

    # Calculate linear regression
    {slope, intercept} = linear_regression(times, values)

    # Calculate moving averages
    ma_3 = moving_average(values, 3)
    ma_5 = moving_average(values, 5)
    ma_10 = moving_average(values, 10)

    %{
      trend_direction: trend_direction(slope),
      slope: slope,
      intercept: intercept,
      predicted_next: slope * (length(times) + 1) + intercept,
      moving_averages: %{
        ma_3: ma_3,
        ma_5: ma_5,
        ma_10: ma_10
      },
      volatility: calculate_volatility(values),
      momentum: calculate_momentum(values)
    }
  end

  # Private functions

  defp compare_results(current, baseline, :statistical) do
    current
    |> Enum.map(fn {scenario, current_data} ->
      baseline_data = Map.get(baseline, scenario)

      if baseline_data do
        comparison = statistical_comparison(current_data, baseline_data)
        {scenario, comparison}
      else
        {scenario, %{status: :new_scenario}}
      end
    end)
    |> Enum.into(%{})
  end

  defp compare_results(current, baseline, :threshold) do
    current
    |> Enum.map(fn {scenario, current_data} ->
      baseline_data = Map.get(baseline, scenario)

      if baseline_data do
        comparison = threshold_comparison(current_data, baseline_data)
        {scenario, comparison}
      else
        {scenario, %{status: :new_scenario}}
      end
    end)
    |> Enum.into(%{})
  end

  defp statistical_comparison(current_data, baseline_data) do
    current_times = extract_times(current_data)
    baseline_times = extract_times(baseline_data)

    # Perform statistical tests
    t_test_result = StatisticalAnalyzer.t_test(current_times, baseline_times)

    mann_whitney =
      StatisticalAnalyzer.mann_whitney_u_test(current_times, baseline_times)

    # Calculate basic metrics
    current_mean = Enum.sum(current_times) / length(current_times)
    baseline_mean = Enum.sum(baseline_times) / length(baseline_times)
    percent_change = (current_mean - baseline_mean) / baseline_mean * 100

    # Determine if change is significant
    significant = t_test_result.p_value < 1 - @confidence_level

    %{
      current_mean: current_mean,
      baseline_mean: baseline_mean,
      percent_change: percent_change,
      absolute_change: current_mean - baseline_mean,
      t_test: t_test_result,
      mann_whitney: mann_whitney,
      is_significant: significant,
      confidence_level: @confidence_level,
      status: determine_status(percent_change, significant),
      severity: calculate_severity(percent_change / 100)
    }
  end

  defp threshold_comparison(current_data, baseline_data) do
    current_mean = extract_mean(current_data)
    baseline_mean = extract_mean(baseline_data)

    percent_change = (current_mean - baseline_mean) / baseline_mean * 100

    %{
      current_mean: current_mean,
      baseline_mean: baseline_mean,
      percent_change: percent_change,
      absolute_change: current_mean - baseline_mean,
      status: determine_status_simple(percent_change),
      severity: calculate_severity(percent_change / 100)
    }
  end

  defp determine_status(percent_change, significant) do
    cond do
      not significant -> :no_significant_change
      percent_change > 5 -> :regression
      percent_change < -5 -> :improvement
      true -> :minor_change
    end
  end

  defp determine_status_simple(percent_change) do
    cond do
      percent_change > 5 -> :regression
      percent_change < -5 -> :improvement
      true -> :stable
    end
  end

  defp find_regressions(comparison, threshold) do
    threshold_percent = threshold * 100

    comparison
    |> Enum.filter(fn {_scenario, result} ->
      Map.get(result, :status) == :regression or
        (Map.get(result, :percent_change, 0) > threshold_percent and
           Map.get(result, :is_significant, true))
    end)
    |> Enum.map(fn {scenario, result} ->
      %{
        scenario: scenario,
        percent_change: result.percent_change,
        severity: result.severity,
        current_mean: result.current_mean,
        baseline_mean: result.baseline_mean,
        significant: Map.get(result, :is_significant, true)
      }
    end)
    |> Enum.sort_by(& &1.percent_change, :desc)
  end

  defp find_improvements(comparison, threshold) do
    threshold_percent = threshold * 100

    comparison
    |> Enum.filter(fn {_scenario, result} ->
      Map.get(result, :status) == :improvement or
        (Map.get(result, :percent_change, 0) < -threshold_percent and
           Map.get(result, :is_significant, true))
    end)
    |> Enum.map(fn {scenario, result} ->
      %{
        scenario: scenario,
        percent_change: abs(result.percent_change),
        severity: result.severity,
        current_mean: result.current_mean,
        baseline_mean: result.baseline_mean,
        significant: Map.get(result, :is_significant, true)
      }
    end)
    |> Enum.sort_by(& &1.percent_change, :desc)
  end

  defp find_stable(comparison, threshold) do
    threshold_percent = threshold * 100

    comparison
    |> Enum.filter(fn {_scenario, result} ->
      status = Map.get(result, :status)
      percent_change = Map.get(result, :percent_change, 0)

      status in [:stable, :no_significant_change, :minor_change] or
        abs(percent_change) <= threshold_percent
    end)
    |> Enum.map(fn {scenario, result} ->
      %{
        scenario: scenario,
        percent_change: Map.get(result, :percent_change, 0),
        current_mean: Map.get(result, :current_mean),
        baseline_mean: Map.get(result, :baseline_mean)
      }
    end)
  end

  defp generate_summary(comparison) do
    total = map_size(comparison)

    {regressions, improvements, stable, new} =
      Enum.reduce(comparison, {0, 0, 0, 0}, fn {_scenario, result},
                                               {r, i, s, n} ->
        case Map.get(result, :status) do
          :regression -> {r + 1, i, s, n}
          :improvement -> {r, i + 1, s, n}
          :new_scenario -> {r, i, s, n + 1}
          _ -> {r, i, s + 1, n}
        end
      end)

    %{
      total_scenarios: total,
      regressions: regressions,
      improvements: improvements,
      stable: stable,
      new_scenarios: new,
      regression_rate: if(total > 0, do: regressions / total * 100, else: 0),
      improvement_rate: if(total > 0, do: improvements / total * 100, else: 0),
      stability_rate: if(total > 0, do: stable / total * 100, else: 0)
    }
  end

  defp generate_recommendations(comparison, threshold) do
    recommendations = []

    # Check for critical regressions
    critical_regressions =
      comparison
      |> Enum.filter(fn {_scenario, result} ->
        Map.get(result, :severity) == :critical
      end)

    recommendations =
      if length(critical_regressions) > 0 do
        [
          "CRITICAL: #{length(critical_regressions)} scenarios show critical performance regression (>50%)"
          | recommendations
        ]
      else
        recommendations
      end

    # Check for widespread regressions
    regression_rate =
      Enum.count(comparison, fn {_s, r} ->
        Map.get(r, :status) == :regression
      end) /
        map_size(comparison)

    recommendations =
      if regression_rate > 0.3 do
        [
          "WARNING: Over 30% of scenarios show performance regression"
          | recommendations
        ]
      else
        recommendations
      end

    # Check for high volatility
    high_volatility =
      comparison
      |> Enum.filter(fn {_scenario, result} ->
        case Map.get(result, :t_test) do
          %{standard_error: se} when se > 100 -> true
          _ -> false
        end
      end)

    recommendations =
      if length(high_volatility) > 0 do
        [
          "INFO: #{length(high_volatility)} scenarios show high variance - consider increasing sample size"
          | recommendations
        ]
      else
        recommendations
      end

    # Add positive feedback
    improvements =
      Enum.count(comparison, fn {_s, r} ->
        Map.get(r, :status) == :improvement
      end)

    recommendations =
      if improvements > 0 do
        [
          "POSITIVE: #{improvements} scenarios show performance improvements"
          | recommendations
        ]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Performance is stable within #{threshold * 100}% threshold"]
    else
      recommendations
    end
  end

  defp extract_times(%{run_time_data: %{samples: samples}}), do: samples
  defp extract_times(%{samples: samples}), do: samples
  defp extract_times(%{times: times}), do: times
  defp extract_times(_), do: []

  defp extract_mean(%{run_time_data: %{statistics: %{average: avg}}}), do: avg
  defp extract_mean(%{statistics: %{average: avg}}), do: avg
  defp extract_mean(%{average: avg}), do: avg
  defp extract_mean(%{mean: mean}), do: mean
  defp extract_mean(_), do: nil

  defp get_metric_value(data, metric) do
    case metric do
      :mean -> extract_mean(data)
      :p50 -> get_in(data, [:statistics, :median])
      :p95 -> get_in(data, [:statistics, :percentiles, :p95])
      :p99 -> get_in(data, [:statistics, :percentiles, :p99])
      _ -> nil
    end
  end

  defp analyze_trends(detection_results) do
    regression_counts =
      detection_results
      |> Enum.map(&length(&1.regressions))

    improvement_counts =
      detection_results
      |> Enum.map(&length(&1.improvements))

    %{
      regression_trend: calculate_trend_direction(regression_counts),
      improvement_trend: calculate_trend_direction(improvement_counts),
      stability_score: calculate_stability_score(detection_results),
      volatility: calculate_list_volatility(regression_counts)
    }
  end

  defp calculate_trend_direction(values) do
    case values do
      [] ->
        :unknown

      [_] ->
        :stable

      _ ->
        first_half = Enum.take(values, div(length(values), 2))
        second_half = Enum.drop(values, div(length(values), 2))

        first_avg = Enum.sum(first_half) / length(first_half)
        second_avg = Enum.sum(second_half) / length(second_half)

        cond do
          second_avg > first_avg * 1.1 -> :increasing
          second_avg < first_avg * 0.9 -> :decreasing
          true -> :stable
        end
    end
  end

  defp calculate_stability_score(detection_results) do
    total_scenarios =
      detection_results
      |> Enum.map(& &1.summary.total_scenarios)
      |> Enum.sum()

    stable_scenarios =
      detection_results
      |> Enum.map(& &1.summary.stable)
      |> Enum.sum()

    if total_scenarios > 0 do
      stable_scenarios / total_scenarios * 100
    else
      0
    end
  end

  defp calculate_list_volatility([]), do: 0
  defp calculate_list_volatility([_]), do: 0

  defp calculate_list_volatility(values) do
    mean = Enum.sum(values) / length(values)

    variance =
      Enum.reduce(values, 0, fn x, acc ->
        acc + :math.pow(x - mean, 2)
      end) / length(values)

    :math.sqrt(variance) / mean
  end

  defp linear_regression(xs, ys) do
    n = length(xs)
    x_mean = Enum.sum(xs) / n
    y_mean = Enum.sum(ys) / n

    numerator =
      Enum.zip(xs, ys)
      |> Enum.reduce(0, fn {x, y}, acc ->
        acc + (x - x_mean) * (y - y_mean)
      end)

    denominator =
      Enum.reduce(xs, 0, fn x, acc ->
        acc + :math.pow(x - x_mean, 2)
      end)

    slope = if denominator != 0, do: numerator / denominator, else: 0
    intercept = y_mean - slope * x_mean

    {slope, intercept}
  end

  defp moving_average(values, window) when length(values) < window, do: []

  defp moving_average(values, window) do
    values
    |> Enum.chunk_every(window, 1, :discard)
    |> Enum.map(&(Enum.sum(&1) / window))
  end

  defp calculate_volatility(values) do
    StatisticalAnalyzer.calculate_percentiles(Enum.sort(values))
    |> Map.get(:p95)
    |> Kernel./(
      Map.get(
        StatisticalAnalyzer.calculate_percentiles(Enum.sort(values)),
        :p50
      )
    )
  end

  defp calculate_momentum(values) when length(values) < 2, do: 0

  defp calculate_momentum(values) do
    recent = Enum.take(values, -5)
    older = Enum.take(values, 5)

    recent_avg = Enum.sum(recent) / length(recent)
    older_avg = Enum.sum(older) / length(older)

    (recent_avg - older_avg) / older_avg * 100
  end

  defp trend_direction(slope) do
    cond do
      slope > 0.01 -> :increasing
      slope < -0.01 -> :decreasing
      true -> :stable
    end
  end

  # Report generation functions

  defp generate_text_report(results) do
    """
    Performance Regression Report
    ============================

    Summary
    -------
    Total Scenarios: #{results.summary.total_scenarios}
    Regressions: #{results.summary.regressions} (#{Float.round(results.summary.regression_rate, 1)}%)
    Improvements: #{results.summary.improvements} (#{Float.round(results.summary.improvement_rate, 1)}%)
    Stable: #{results.summary.stable} (#{Float.round(results.summary.stability_rate, 1)}%)

    Regressions
    -----------
    #{format_regression_list(results.regressions)}

    Improvements
    ------------
    #{format_improvement_list(results.improvements)}

    Recommendations
    ---------------
    #{Enum.join(results.recommendations, "\n")}
    """
  end

  defp generate_json_report(results) do
    Jason.encode!(results, pretty: true)
  end

  defp generate_html_report(results) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Performance Regression Report</title>
        <style>
            body { font-family: sans-serif; margin: 20px; }
            .regression { background: #fee; }
            .improvement { background: #efe; }
            .stable { background: #eef; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background: #f5f5f5; }
        </style>
    </head>
    <body>
        <h1>Performance Regression Report</h1>
        #{generate_html_content(results)}
    </body>
    </html>
    """
  end

  defp generate_markdown_report(results) do
    """
    # Performance Regression Report

    ## Summary

    | Metric | Value |
    |--------|-------|
    | Total Scenarios | #{results.summary.total_scenarios} |
    | Regressions | #{results.summary.regressions} (#{Float.round(results.summary.regression_rate, 1)}%) |
    | Improvements | #{results.summary.improvements} (#{Float.round(results.summary.improvement_rate, 1)}%) |
    | Stable | #{results.summary.stable} (#{Float.round(results.summary.stability_rate, 1)}%) |

    ## Regressions

    #{format_markdown_table(results.regressions)}

    ## Improvements

    #{format_markdown_table(results.improvements)}

    ## Recommendations

    #{Enum.map_join(results.recommendations, "\n", &"- #{&1}")}
    """
  end

  defp format_regression_list([]), do: "No regressions detected"

  defp format_regression_list(regressions) do
    regressions
    |> Enum.map_join("\n", fn r ->
      "  • #{r.scenario}: +#{Float.round(r.percent_change, 1)}% (#{r.severity})"
    end)
  end

  defp format_improvement_list([]), do: "No improvements detected"

  defp format_improvement_list(improvements) do
    improvements
    |> Enum.map_join(
      fn i ->
        "  • #{i.scenario}: -#{Float.round(i.percent_change, 1)}%"
      end,
      "\n"
    )
  end

  defp generate_html_content(_results) do
    # Simplified HTML generation
    "<p>See detailed results in JSON format</p>"
  end

  defp format_markdown_table([]), do: "*No items*"

  defp format_markdown_table(items) do
    """
    | Scenario | Change | Severity |
    |----------|--------|----------|
    """ <>
      (items
       |> Enum.map_join(
         fn item ->
           "| #{item.scenario} | #{Float.round(item.percent_change, 1)}% | #{item.severity} |"
         end,
         "\n"
       ))
  end
end
