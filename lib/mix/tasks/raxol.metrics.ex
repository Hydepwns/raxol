defmodule Mix.Tasks.Raxol.Metrics do
  @moduledoc """
  View and manage pre-commit performance metrics.

  ## Usage

      mix raxol.metrics [command] [options]
      
  ## Commands

    * `report` - Generate performance report (default)
    * `stats` - Show quick statistics
    * `clear` - Clear metrics history
    * `optimize` - Show optimized check order
    
  ## Options

    * `--limit N` - Number of runs to analyze (default: 30)
    * `--verbose` - Show detailed information
    * `--json` - Output in JSON format
    
  ## Examples

      # View performance report
      mix raxol.metrics
      
      # Show statistics for last 10 runs
      mix raxol.metrics stats --limit 10
      
      # Get optimized check order
      mix raxol.metrics optimize
      
      # Clear all metrics
      mix raxol.metrics clear
  """

  use Mix.Task
  alias Raxol.PreCommit.Metrics

  @shortdoc "View pre-commit performance metrics"

  @impl Mix.Task
  def run(args) do
    {opts, commands, _} =
      OptionParser.parse(args,
        switches: [
          limit: :integer,
          verbose: :boolean,
          json: :boolean
        ]
      )

    command = List.first(commands) || "report"

    handle_command(command, opts)
  end

  defp handle_command("report", opts) do
    limit = Keyword.get(opts, :limit, 30)
    verbose = Keyword.get(opts, :verbose, false)
    json = Keyword.get(opts, :json, false)

    case json do
      true ->
        stats = Metrics.get_statistics(limit)
        IO.puts(Jason.encode!(stats, pretty: true))

      false ->
        report = Metrics.generate_report(limit: limit, verbose: verbose)
        IO.puts(report)
    end
  end

  defp handle_command("stats", opts) do
    limit = Keyword.get(opts, :limit, 10)
    json = Keyword.get(opts, :json, false)

    stats = Metrics.get_statistics(limit)

    case json do
      true ->
        IO.puts(Jason.encode!(stats, pretty: true))

      false ->
        print_stats(stats)
    end
  end

  defp handle_command("clear", _opts) do
    case prompt_confirmation("Clear all metrics history?") do
      true ->
        Metrics.clear_history()
        IO.puts("✅ Metrics history cleared")

      false ->
        IO.puts("Cancelled")
    end
  end

  defp handle_command("optimize", opts) do
    json = Keyword.get(opts, :json, false)

    # Get default check list
    default_checks = [
      :format,
      :compile,
      :credo,
      :tests,
      :docs,
      :dialyzer,
      :security
    ]

    optimized = Metrics.get_optimized_order(default_checks)

    case json do
      true ->
        IO.puts(Jason.encode!(optimized))

      false ->
        print_optimized_order(optimized, default_checks)
    end
  end

  defp handle_command(unknown, _opts) do
    IO.puts("Unknown command: #{unknown}")
    IO.puts("Available commands: report, stats, clear, optimize")
    System.halt(1)
  end

  defp print_stats(stats) when is_map(stats) and map_size(stats) == 1 do
    # Error case
    IO.puts("❌ #{stats.error}")
  end

  defp print_stats(stats) do
    IO.puts("""
    📊 Performance Statistics
    ─────────────────────────
    Runs:     #{stats.runs}
    Average:  #{stats.average_time}ms
    Median:   #{stats.median_time}ms
    Range:    #{stats.min_time}ms - #{stats.max_time}ms
    Trend:    #{format_trend(stats.trend)}

    Top 3 Slowest Checks:
    """)

    stats.by_check
    |> Enum.sort_by(fn {_, check_stats} -> -check_stats.average_time end)
    |> Enum.take(3)
    |> Enum.each(fn {check, check_stats} ->
      IO.puts(
        "  • #{String.capitalize(to_string(check))}: #{check_stats.average_time}ms avg"
      )
    end)
  end

  defp print_optimized_order(optimized, default) do
    IO.puts("""
    🚀 Optimized Check Order
    ─────────────────────────
    Based on historical performance data, checks should
    run in this order for fastest fail-fast behavior:

    Optimized:
    """)

    optimized
    |> Enum.with_index(1)
    |> Enum.each(fn {check, idx} ->
      IO.puts("  #{idx}. #{String.capitalize(to_string(check))}")
    end)

    case optimized == default do
      true ->
        IO.puts("\n✅ Already using optimal order")

      false ->
        IO.puts("""

        To use this order, update your .raxol.exs:

        [
          pre_commit: [
            checks: #{inspect(optimized)}
          ]
        ]
        """)
    end
  end

  defp format_trend(:improving), do: "📈 Improving"
  defp format_trend(:degrading), do: "📉 Degrading"
  defp format_trend(:stable), do: "➡️  Stable"
  defp format_trend(_), do: "Unknown"

  defp prompt_confirmation(question) do
    case IO.gets("#{question} [y/N]: ") do
      :eof ->
        false

      response when is_binary(response) ->
        response
        |> String.trim()
        |> String.downcase()
        |> then(&(&1 in ["y", "yes"]))

      _ ->
        false
    end
  end
end
