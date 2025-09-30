defmodule Mix.Tasks.Raxol.Perf.Monitor do
  @moduledoc """
  Automated performance monitoring task for Raxol.

  This task provides comprehensive performance monitoring capabilities:
  - Start/stop continuous monitoring
  - View real-time performance metrics
  - Check for performance regressions
  - Configure alert thresholds
  - Generate performance reports

  ## Usage

      # Start monitoring with default settings
      mix raxol.perf.monitor start

      # Start with custom thresholds
      mix raxol.perf.monitor start --render-threshold 20 --memory-threshold 100

      # View current status
      mix raxol.perf.monitor status

      # Check for regressions
      mix raxol.perf.monitor regression-check

      # Generate performance report
      mix raxol.perf.monitor report --output performance_report.json

      # Stop monitoring
      mix raxol.perf.monitor stop

  ## Options

    * `--render-threshold` - Maximum average render time in ms (default: 16.67)
    * `--memory-threshold` - Maximum memory usage in MB (default: 50)
    * `--parse-threshold` - Maximum parse time in microseconds (default: 500)
    * `--error-threshold` - Maximum error rate percentage (default: 1.0)
    * `--output` - Output file for reports (default: stdout)
    * `--format` - Report format: json, csv, or text (default: text)
  """

  use Mix.Task
  alias Raxol.Core.Runtime.Log
  alias Raxol.Performance.AutomatedMonitor

  @shortdoc "Automated performance monitoring for Raxol"

  @impl Mix.Task
  def run(args) do
    # Ensure the application is started
    Mix.Task.run("app.start")

    {opts, commands, _} = OptionParser.parse(args,
      switches: [
        render_threshold: :float,
        memory_threshold: :float,
        parse_threshold: :float,
        error_threshold: :float,
        output: :string,
        format: :string,
        help: :boolean
      ],
      aliases: [
        h: :help,
        o: :output,
        f: :format
      ]
    )

    if opts[:help] || commands == [] do
      print_help()
    else
      execute_command(commands, opts)
    end
  end

  defp execute_command(["start"], opts) do
    thresholds = build_thresholds_from_opts(opts)

    Log.console("Starting automated performance monitoring...")
    Log.console("Thresholds: #{inspect(thresholds)}")

    case AutomatedMonitor.start_monitoring(thresholds: thresholds) do
      :ok ->
        Log.console("✓ Performance monitoring started successfully")
        Log.console("Monitor will collect metrics every 30 seconds")
        Log.console("Use 'mix raxol.perf.monitor status' to view current metrics")

      {:already_running, current_metrics} ->
        Log.console("⚠ Performance monitoring is already running")
        print_current_metrics(current_metrics)

      {:error, reason} ->
        Log.error("✗ Failed to start performance monitoring: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp execute_command(["stop"], _opts) do
    Log.console("Stopping automated performance monitoring...")

    case AutomatedMonitor.stop_monitoring() do
      :ok ->
        Log.console("✓ Performance monitoring stopped")
      {:error, reason} ->
        Log.error("✗ Failed to stop performance monitoring: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp execute_command(["status"], _opts) do
    case AutomatedMonitor.get_status() do
      %{monitoring_enabled: false} ->
        Log.console("Performance monitoring is not running")
        Log.console("Use 'mix raxol.perf.monitor start' to begin monitoring")

      status ->
        Log.console("=== Performance Monitoring Status ===")
        Log.console("Status: #{if status.monitoring_enabled, do: "ACTIVE", else: "INACTIVE"}")
        Log.console("Active alerts: #{status.alert_count}")
        Log.console("")

        print_current_metrics(status.current_metrics)
        print_threshold_status(status.current_metrics, status.thresholds)

        if length(status.recommendations) > 0 do
          Log.console("")
          Log.console("=== Optimization Recommendations ===")
          Enum.each(status.recommendations, fn rec ->
            Log.console("• #{rec}")
          end)
        end
    end
  end

  defp execute_command(["regression-check"], _opts) do
    Log.console("Checking for performance regressions...")

    case AutomatedMonitor.check_regressions() do
      {:ok, []} ->
        Log.console("✓ No performance regressions detected")

      {:ok, regressions} ->
        Log.console("⚠ Performance regressions detected:")
        Enum.each(regressions, &print_regression/1)

      {:error, :insufficient_data} ->
        Log.console("⚠ Insufficient data for regression analysis")
        Log.console("Run monitoring for at least 5 minutes to collect baseline data")

      {:error, reason} ->
        Log.error("✗ Regression check failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp execute_command(["report"], opts) do
    format = Keyword.get(opts, :format, "text")
    output_file = Keyword.get(opts, :output)

    Log.console("Generating performance report (format: #{format})...")

    case AutomatedMonitor.get_status() do
      %{monitoring_enabled: false} ->
        Log.console("⚠ No monitoring data available - monitoring is not running")
        System.halt(1)

      status ->
        report = generate_performance_report(status, format)

        case output_file do
          nil ->
            Log.console(report)
          file_path ->
            File.write!(file_path, report)
            Log.console("✓ Performance report written to #{file_path}")
        end
    end
  end

  defp execute_command(["alerts"], _opts) do
    case AutomatedMonitor.get_alerts() do
      alerts when map_size(alerts) == 0 ->
        Log.console("✓ No active performance alerts")

      alerts ->
        Log.console("=== Active Performance Alerts ===")
        Enum.each(alerts, fn {alert_key, alert_data} ->
          violation = alert_data.violation
          Log.console("#{alert_key}:")
          Log.console("  Type: #{violation.type}")
          Log.console("  Current: #{violation.value}")
          Log.console("  Threshold: #{violation.threshold}")
          Log.console("  Count: #{alert_data.count}")
          Log.console("")
        end)
    end
  end

  defp execute_command([command], _opts) do
    Log.error("Unknown command: #{command}")
    print_help()
    System.halt(1)
  end

  defp build_thresholds_from_opts(opts) do
    thresholds = %{}

    thresholds = if opts[:render_threshold] do
      Map.put(thresholds, :avg_render_time_ms, opts[:render_threshold])
    else
      thresholds
    end

    thresholds = if opts[:memory_threshold] do
      Map.put(thresholds, :memory_usage_mb, opts[:memory_threshold])
    else
      thresholds
    end

    thresholds = if opts[:parse_threshold] do
      Map.put(thresholds, :parse_time_us, opts[:parse_threshold])
    else
      thresholds
    end

    if opts[:error_threshold] do
      Map.put(thresholds, :error_rate_percent, opts[:error_threshold])
    else
      thresholds
    end
  end

  defp print_current_metrics(%{timestamp: timestamp} = metrics) do
    time_ago = System.system_time(:millisecond) - timestamp
    Log.console("=== Current Performance Metrics ===")
    Log.console("Last updated: #{time_ago}ms ago")
    Log.console("")

    # Render performance
    render = metrics.render_performance
    Log.console("Render Performance:")
    Log.console("  Average: #{Float.round(render.avg_ms, 2)}ms")
    Log.console("  Maximum: #{Float.round(render.max_ms, 2)}ms")
    Log.console("  Frame count: #{render.count}")
    Log.console("")

    # Parse performance
    parse = metrics.parse_performance
    Log.console("Parse Performance:")
    Log.console("  Average: #{Float.round(parse.avg_us, 1)}μs")
    Log.console("  Maximum: #{Float.round(parse.max_us, 1)}μs")
    Log.console("  Operation count: #{parse.count}")
    Log.console("")

    # Memory usage
    memory = metrics.memory_usage
    Log.console("Memory Usage:")
    Log.console("  Total: #{Float.round(memory.total_mb, 1)}MB")
    Log.console("  Processes: #{Float.round(memory.processes_mb, 1)}MB")
    Log.console("  System: #{Float.round(memory.system_mb, 1)}MB")
    Log.console("")

    # Error rates
    errors = metrics.error_rates
    Log.console("Error Statistics:")
    Log.console("  Error rate: #{Float.round(errors.error_rate_percent, 2)}%")
    Log.console("  Total events: #{errors.total_events}")
    Log.console("  Error events: #{errors.error_events}")
  end

  defp print_current_metrics(_), do: Log.console("No metrics available yet")

  defp print_threshold_status(metrics, thresholds) when is_map(metrics) do
    Log.console("=== Threshold Status ===")

    # Check render thresholds
    render_status = if metrics.render_performance.avg_ms > thresholds.avg_render_time_ms do
      "⚠ EXCEEDED"
    else
      "✓ OK"
    end
    Log.console("Render time: #{render_status} (#{Float.round(metrics.render_performance.avg_ms, 2)}ms / #{thresholds.avg_render_time_ms}ms)")

    # Check memory thresholds
    memory_status = if metrics.memory_usage.total_mb > thresholds.memory_usage_mb do
      "⚠ EXCEEDED"
    else
      "✓ OK"
    end
    Log.console("Memory usage: #{memory_status} (#{Float.round(metrics.memory_usage.total_mb, 1)}MB / #{thresholds.memory_usage_mb}MB)")

    # Check parse thresholds
    parse_status = if metrics.parse_performance.avg_us > thresholds.parse_time_us do
      "⚠ EXCEEDED"
    else
      "✓ OK"
    end
    Log.console("Parse time: #{parse_status} (#{Float.round(metrics.parse_performance.avg_us, 1)}μs / #{thresholds.parse_time_us}μs)")

    # Check error thresholds
    error_status = if metrics.error_rates.error_rate_percent > thresholds.error_rate_percent do
      "⚠ EXCEEDED"
    else
      "✓ OK"
    end
    Log.console("Error rate: #{error_status} (#{Float.round(metrics.error_rates.error_rate_percent, 2)}% / #{thresholds.error_rate_percent}%)")
  end

  defp print_threshold_status(_, _), do: Log.console("Threshold status: No data available")

  defp print_regression(regression) do
    Log.console("  #{regression.type} (#{regression.metric}):")
    Log.console("    Baseline: #{regression.baseline}")
    Log.console("    Current: #{regression.current}")
    Log.console("    Regression: #{Float.round(regression.regression_percent, 1)}%")
    Log.console("")
  end

  defp generate_performance_report(status, "json") do
    Jason.encode!(status, pretty: true)
  end

  defp generate_performance_report(status, "csv") do
    headers = "timestamp,render_avg_ms,render_max_ms,parse_avg_us,memory_total_mb,error_rate_percent\n"
    metrics = status.current_metrics

    row = "#{metrics.timestamp}," <>
          "#{metrics.render_performance.avg_ms}," <>
          "#{metrics.render_performance.max_ms}," <>
          "#{metrics.parse_performance.avg_us}," <>
          "#{metrics.memory_usage.total_mb}," <>
          "#{metrics.error_rates.error_rate_percent}\n"

    headers <> row
  end

  defp generate_performance_report(status, "text") do
    """
    === Raxol Performance Report ===
    Generated: #{DateTime.utc_now() |> DateTime.to_string()}
    Monitoring Status: #{if status.monitoring_enabled, do: "Active", else: "Inactive"}
    Active Alerts: #{status.alert_count}

    === Current Metrics ===
    #{format_metrics_for_report(status.current_metrics)}

    === Baseline Comparison ===
    #{format_baseline_comparison(status.baseline_metrics, status.current_metrics)}

    === Threshold Configuration ===
    #{format_thresholds(status.thresholds)}

    === Optimization Recommendations ===
    #{Enum.join(status.recommendations, "\n")}
    """
  end

  defp format_metrics_for_report(metrics) when is_map(metrics) do
    """
    Render Performance:
      Average: #{Float.round(metrics.render_performance.avg_ms, 2)}ms
      Maximum: #{Float.round(metrics.render_performance.max_ms, 2)}ms
      Frame Count: #{metrics.render_performance.count}

    Parse Performance:
      Average: #{Float.round(metrics.parse_performance.avg_us, 1)}μs
      Maximum: #{Float.round(metrics.parse_performance.max_us, 1)}μs
      Operation Count: #{metrics.parse_performance.count}

    Memory Usage:
      Total: #{Float.round(metrics.memory_usage.total_mb, 1)}MB
      Processes: #{Float.round(metrics.memory_usage.processes_mb, 1)}MB
      System: #{Float.round(metrics.memory_usage.system_mb, 1)}MB

    Error Statistics:
      Error Rate: #{Float.round(metrics.error_rates.error_rate_percent, 2)}%
      Total Events: #{metrics.error_rates.total_events}
      Error Events: #{metrics.error_rates.error_events}
    """
  end

  defp format_metrics_for_report(_), do: "No metrics data available"

  defp format_baseline_comparison(baseline, current) when is_map(baseline) and is_map(current) do
    render_change = ((current.render_performance.avg_ms - baseline.render_performance.avg_ms) / baseline.render_performance.avg_ms) * 100
    memory_change = ((current.memory_usage.total_mb - baseline.memory_usage.total_mb) / baseline.memory_usage.total_mb) * 100

    """
    Render Performance Change: #{Float.round(render_change, 1)}%
    Memory Usage Change: #{Float.round(memory_change, 1)}%
    """
  end

  defp format_baseline_comparison(_, _), do: "No baseline data available for comparison"

  defp format_thresholds(thresholds) do
    """
    Average Render Time: #{thresholds.avg_render_time_ms}ms
    Maximum Render Time: #{thresholds.max_render_time_ms}ms
    Memory Usage: #{thresholds.memory_usage_mb}MB
    Parse Time: #{thresholds.parse_time_us}μs
    Error Rate: #{thresholds.error_rate_percent}%
    """
  end

  defp print_help do
    Log.console("""
    Raxol Automated Performance Monitoring

    USAGE:
        mix raxol.perf.monitor <COMMAND> [OPTIONS]

    COMMANDS:
        start              Start automated performance monitoring
        stop               Stop automated performance monitoring
        status             Show current monitoring status and metrics
        regression-check   Check for performance regressions
        report             Generate a performance report
        alerts             Show active performance alerts

    OPTIONS:
        --render-threshold FLOAT    Maximum average render time in ms (default: 16.67)
        --memory-threshold FLOAT    Maximum memory usage in MB (default: 50)
        --parse-threshold FLOAT     Maximum parse time in μs (default: 500)
        --error-threshold FLOAT     Maximum error rate percentage (default: 1.0)
        --output FILE              Output file for reports (default: stdout)
        --format FORMAT            Report format: json, csv, or text (default: text)
        --help, -h                 Show this help message

    EXAMPLES:
        # Start monitoring with default thresholds
        mix raxol.perf.monitor start

        # Start with custom render threshold
        mix raxol.perf.monitor start --render-threshold 20

        # Check current status
        mix raxol.perf.monitor status

        # Generate JSON report to file
        mix raxol.perf.monitor report --format json --output perf_report.json

        # Check for performance regressions
        mix raxol.perf.monitor regression-check
    """)
  end
end