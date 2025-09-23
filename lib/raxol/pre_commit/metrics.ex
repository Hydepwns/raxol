defmodule Raxol.PreCommit.Metrics do
  @moduledoc """
  Performance metrics tracking for pre-commit checks.

  Tracks and analyzes performance data over time to:
  - Identify slow checks
  - Detect performance regressions
  - Generate trend reports
  - Optimize check execution order
  """

  @metrics_file ".raxol_cache/metrics.json"
  # Keep last 100 runs
  @history_limit 100

  @doc """
  Record metrics for a pre-commit run.
  """
  def record_run(results, total_elapsed, config \\ %{}) do
    ensure_cache_dir()

    metrics = build_metrics(results, total_elapsed, config)
    save_metrics(metrics)

    # Analyze for performance issues
    analyze_performance(metrics)
  end

  @doc """
  Get performance statistics for recent runs.
  """
  def get_statistics(limit \\ 10) do
    case load_history() do
      {:ok, history} ->
        recent = Enum.take(history, limit)
        calculate_statistics(recent)

      _ ->
        %{error: "No metrics history available"}
    end
  end

  @doc """
  Generate a performance report.
  """
  def generate_report(opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)
    verbose = Keyword.get(opts, :verbose, false)

    case load_history() do
      {:ok, history} ->
        recent = Enum.take(history, limit)
        format_report(recent, verbose)

      _ ->
        "No metrics history available"
    end
  end

  @doc """
  Clear metrics history.
  """
  def clear_history do
    _ = File.rm(@metrics_file)
    :ok
  end

  @doc """
  Get check execution order optimized by average time.
  """
  def get_optimized_order(checks) do
    case load_history() do
      {:ok, history} ->
        avg_times = calculate_average_times(history)

        # Sort checks by average time (fastest first for fail-fast)
        Enum.sort_by(checks, fn check ->
          Map.get(avg_times, check, 999_999)
        end)

      _ ->
        # Default order if no history
        checks
    end
  end

  # Private functions

  defp ensure_cache_dir do
    Path.dirname(@metrics_file) |> File.mkdir_p!()
  end

  defp build_metrics(results, total_elapsed, config) do
    %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      git_sha: get_current_sha(),
      git_branch: get_current_branch(),
      total_time: total_elapsed,
      parallel: Map.get(config, :parallel, true),
      checks: build_check_metrics(results),
      system: build_system_metrics(),
      cache_stats: build_cache_stats(config)
    }
  end

  defp build_check_metrics(results) do
    Map.new(results, fn {name, result} ->
      {name,
       %{
         status: result.status,
         elapsed: Map.get(result, :elapsed, 0),
         cached: Map.get(result, :cached, false),
         error_count: count_errors(result)
       }}
    end)
  end

  defp build_system_metrics do
    %{
      cpu_count: System.schedulers_online(),
      elixir_version: System.version(),
      otp_version: :erlang.system_info(:otp_release) |> to_string(),
      os: :os.type() |> elem(0) |> to_string()
    }
  end

  defp build_cache_stats(config) do
    case Map.get(config, :no_cache, false) do
      true ->
        %{enabled: false}

      false ->
        # Calculate cache hit rate from results
        %{
          enabled: true,
          hit_rate: calculate_cache_hit_rate()
        }
    end
  end

  defp calculate_cache_hit_rate do
    # This would check actual cache hits from Cache module
    # For now, return placeholder
    case Raxol.PreCommit.Cache.get_stats() do
      {:ok, stats} ->
        case stats.total do
          0 -> 0.0
          total -> Float.round(stats.hits / total * 100, 1)
        end
    end
  catch
    _ -> 0.0
  end

  defp count_errors(result) do
    case result do
      %{status: :error} -> 1
      %{failures: failures} when is_list(failures) -> length(failures)
      _ -> 0
    end
  end

  defp save_metrics(metrics) do
    history =
      case load_history() do
        {:ok, existing} -> existing
        _ -> []
      end

    # Add new metrics and limit history
    updated = [metrics | history] |> Enum.take(@history_limit)

    # Save to file
    json = Jason.encode!(updated, pretty: true)
    File.write!(@metrics_file, json)
  end

  defp load_history do
    case File.read(@metrics_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          _ -> {:error, :invalid_json}
        end

      _ ->
        {:error, :not_found}
    end
  end

  defp analyze_performance(current_metrics) do
    case load_history() do
      {:ok, [_current | history]} when length(history) >= 5 ->
        # Compare with recent average
        recent_avg = calculate_recent_average(Enum.take(history, 5))
        current_time = current_metrics["total_time"]

        case current_time > recent_avg * 1.5 do
          true ->
            {:warning,
             "Performance degradation detected: #{current_time}ms vs #{round(recent_avg)}ms average"}

          false ->
            {:ok, :normal}
        end

      _ ->
        {:ok, :insufficient_data}
    end
  end

  defp calculate_recent_average(history) do
    times = Enum.map(history, & &1["total_time"])

    case times do
      [] -> 0
      times -> Enum.sum(times) / length(times)
    end
  end

  defp calculate_statistics(history) do
    total_times = Enum.map(history, & &1["total_time"])

    %{
      runs: length(history),
      average_time: calculate_average(total_times),
      median_time: calculate_median(total_times),
      min_time: Enum.min(total_times, fn -> 0 end),
      max_time: Enum.max(total_times, fn -> 0 end),
      trend: calculate_trend(total_times),
      by_check: calculate_check_statistics(history)
    }
  end

  defp calculate_check_statistics(history) do
    # Aggregate statistics per check
    history
    |> Enum.flat_map(fn run ->
      case run["checks"] do
        nil -> []
        checks -> Enum.map(checks, fn {name, data} -> {name, data} end)
      end
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {check, runs} ->
      times = Enum.map(runs, &(&1["elapsed"] || 0))
      failures = Enum.count(runs, &(&1["status"] == "error"))

      {check,
       %{
         average_time: calculate_average(times),
         failure_rate: Float.round(failures / length(runs) * 100, 1),
         run_count: length(runs)
       }}
    end)
  end

  defp calculate_average([]), do: 0
  defp calculate_average(nums), do: round(Enum.sum(nums) / length(nums))

  defp calculate_median([]), do: 0

  defp calculate_median(nums) do
    sorted = Enum.sort(nums)
    mid = div(length(sorted), 2)

    case rem(length(sorted), 2) do
      0 ->
        (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2

      1 ->
        Enum.at(sorted, mid)
    end
    |> round()
  end

  defp calculate_trend(times) when length(times) < 2, do: :stable

  defp calculate_trend(times) do
    recent = Enum.take(times, 3) |> calculate_average()
    older = Enum.slice(times, 3, 3) |> calculate_average()

    cond do
      older == 0 -> :stable
      recent > older * 1.2 -> :degrading
      recent < older * 0.8 -> :improving
      true -> :stable
    end
  end

  defp calculate_average_times(history) do
    history
    |> Enum.flat_map(fn run ->
      case run["checks"] do
        nil ->
          []

        checks ->
          Enum.map(checks, fn {name, data} ->
            {String.to_atom(name), data["elapsed"] || 0}
          end)
      end
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {check, times} ->
      {check, calculate_average(times)}
    end)
  end

  defp format_report(history, verbose) do
    stats = calculate_statistics(history)

    header = """
    ═══ Pre-commit Performance Report ═══

    📊 Summary (last #{length(history)} runs)
    ────────────────────────────────────
      Average time: #{stats.average_time}ms
      Median time:  #{stats.median_time}ms
      Min/Max:      #{stats.min_time}ms / #{stats.max_time}ms
      Trend:        #{format_trend(stats.trend)}
    """

    check_details = format_check_details(stats.by_check, verbose)

    recent_runs = format_recent_runs(Enum.take(history, 5))

    recommendations = generate_recommendations(stats, history)

    Enum.join([header, check_details, recent_runs, recommendations], "\n")
  end

  defp format_trend(:improving), do: "📈 Improving"
  defp format_trend(:degrading), do: "📉 Degrading"
  defp format_trend(:stable), do: "➡️  Stable"

  defp format_check_details(by_check, verbose) do
    rows =
      by_check
      |> Enum.sort_by(fn {_, stats} -> -stats.average_time end)
      |> Enum.map(fn {check, stats} ->
        name =
          check |> to_string() |> String.capitalize() |> String.pad_trailing(10)

        base =
          "  #{name} │ #{String.pad_leading(to_string(stats.average_time), 6)}ms"

        case verbose do
          true ->
            "#{base} │ #{Float.to_string(stats.failure_rate)}% failures │ #{stats.run_count} runs"

          false ->
            base
        end
      end)

    """

    📋 Check Performance
    ────────────────────────────────────
    #{Enum.join(rows, "\n")}
    """
  end

  defp format_recent_runs(runs) do
    rows =
      runs
      |> Enum.with_index(1)
      |> Enum.map(fn {run, idx} ->
        time = run["total_time"]
        timestamp = parse_timestamp(run["timestamp"])
        status = determine_run_status(run)

        "  #{idx}. #{timestamp} - #{time}ms #{status}"
      end)

    """

    🕐 Recent Runs
    ────────────────────────────────────
    #{Enum.join(rows, "\n")}
    """
  end

  defp generate_recommendations(stats, _history) do
    recommendations = []

    # Check for slow checks
    slow_checks =
      stats.by_check
      |> Enum.filter(fn {_, check_stats} -> check_stats.average_time > 3000 end)
      |> Enum.map(&elem(&1, 0))

    recommendations =
      case slow_checks do
        [] ->
          recommendations

        checks ->
          [
            "• Consider optimizing slow checks: #{Enum.join(checks, ", ")}"
            | recommendations
          ]
      end

    # Check for high failure rates
    failing_checks =
      stats.by_check
      |> Enum.filter(fn {_, check_stats} -> check_stats.failure_rate > 20 end)
      |> Enum.map(&elem(&1, 0))

    recommendations =
      case failing_checks do
        [] ->
          recommendations

        checks ->
          [
            "• Investigate frequent failures in: #{Enum.join(checks, ", ")}"
            | recommendations
          ]
      end

    # Check for performance trend
    recommendations =
      case stats.trend do
        :degrading ->
          [
            "• Performance is degrading - investigate recent changes"
            | recommendations
          ]

        _ ->
          recommendations
      end

    case recommendations do
      [] ->
        "\n💡 Recommendations\n────────────────────────────────────\n  ✅ Performance is healthy\n"

      recs ->
        "\n💡 Recommendations\n────────────────────────────────────\n#{Enum.join(recs, "\n")}\n"
    end
  end

  defp parse_timestamp(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _} ->
        Calendar.strftime(dt, "%m/%d %H:%M")

      _ ->
        "Unknown"
    end
  end

  defp determine_run_status(run) do
    checks = run["checks"] || %{}

    failed = Enum.count(checks, fn {_, data} -> data["status"] == "error" end)

    case failed do
      0 -> "✅"
      n -> "❌ (#{n} failed)"
    end
  end

  defp get_current_sha do
    case System.cmd("git", ["rev-parse", "--short", "HEAD"],
           stderr_to_stdout: true
         ) do
      {sha, 0} -> String.trim(sha)
      _ -> "unknown"
    end
  end

  defp get_current_branch do
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true) do
      {branch, 0} -> String.trim(branch)
      _ -> "unknown"
    end
  end
end
