defmodule Mix.Tasks.Benchmark do
  @moduledoc """
  Runs performance benchmarks for Raxol.

  ## Usage

      mix benchmark [options] [suite_names]

  ## Options

    * `--all` - Run all benchmark suites
    * `--suite` - Run specific suite(s) (can be used multiple times)
    * `--compare` - Compare with baseline
    * `--save-baseline` - Save results as new baseline
    * `--profile` - Enable profiling mode
    * `--format` - Output format: console, html, json, markdown (default: console)
    * `--output` - Output directory (default: bench/output)
    * `--time` - Duration to run each benchmark in seconds (default: 5)
    * `--warmup` - Warmup time in seconds (default: 2)
    * `--memory` - Include memory measurements
    * `--only` - Run only benchmarks matching pattern
    * `--except` - Exclude benchmarks matching pattern

  ## Available Suites

    * `terminal` - Terminal emulation benchmarks
    * `rendering` - UI rendering pipeline benchmarks
    * `buffer` - Buffer operations benchmarks
    * `plugin` - Plugin system benchmarks
    * `component` - UI component benchmarks
    * `security` - Security operations benchmarks

  ## Examples

      # Run all benchmarks
      mix benchmark --all

      # Run specific suites
      mix benchmark --suite terminal --suite buffer

      # Run with comparison to baseline
      mix benchmark --all --compare

      # Save new baseline
      mix benchmark --all --save-baseline

      # Run in profile mode
      mix benchmark --suite terminal --profile

      # Generate HTML report
      mix benchmark --all --format html --output bench/reports

      # Run only specific benchmarks
      mix benchmark --suite terminal --only "ANSI.*"

      # Quick benchmark (reduced time)
      mix benchmark --suite terminal --time 1 --warmup 0.5
  """

  use Mix.Task

  alias Raxol.Benchmark.{Reporter, Storage, Analyzer}

  @all_suites ~w(terminal rendering buffer plugin component security)

  @shortdoc "Run performance benchmarks"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = parse_args(args)

    handle_help_option(opts[:help])
    execute_benchmarks(opts)
  end

  defp parse_args(args) do
    OptionParser.parse(args,
      switches: [
        all: :boolean,
        suite: :keep,
        compare: :boolean,
        save_baseline: :boolean,
        profile: :boolean,
        format: :string,
        output: :string,
        time: :float,
        warmup: :float,
        memory: :boolean,
        only: :string,
        except: :string,
        quick: :boolean,
        help: :boolean
      ],
      aliases: [
        a: :all,
        s: :suite,
        c: :compare,
        p: :profile,
        f: :format,
        o: :output,
        t: :time,
        w: :warmup,
        m: :memory,
        h: :help
      ]
    )
  end

  defp execute_benchmarks(opts) do
    Mix.Task.run("app.start")

    benchmark_opts = configure_options(opts)
    suites = determine_suites(opts)

    validate_suites(suites)
    log_execution_info(suites, benchmark_opts)

    results = run_suites(suites, benchmark_opts, opts)
    process_results(results, opts)

    Mix.shell().info("\nBenchmark completed successfully!")
  end

  defp validate_suites(suites) do
    validate_suite_list(Enum.empty?(suites))
  end

  defp log_execution_info(suites, benchmark_opts) do
    Mix.shell().info("Running benchmark suites: #{Enum.join(suites, ", ")}")
    Mix.shell().info("Configuration: #{inspect(benchmark_opts)}")
  end

  defp run_suites(suites, benchmark_opts, opts) do
    execute_suite_mode(opts[:profile], suites, benchmark_opts)
  end

  defp configure_options(opts) do
    base_opts = %{
      time: opts[:time] || 5,
      warmup: opts[:warmup] || 2,
      memory_time: get_memory_time(opts[:memory]),
      parallel: 1
    }

    # Quick mode for faster iteration
    base_opts = apply_quick_mode(opts[:quick], base_opts)

    # Add filters
    base_opts = apply_only_filter(opts[:only], base_opts)
    base_opts = apply_except_filter(opts[:except], base_opts)

    base_opts
  end

  defp determine_suites(opts) do
    case {opts[:all], opts[:suite]} do
      {true, _} ->
        @all_suites

      {_, nil} ->
        []

      {_, _} ->
        # Handle multiple --suite options
        opts
        |> Keyword.get_values(:suite)
        |> Enum.flat_map(&String.split(&1, ","))
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 in @all_suites))
        |> Enum.uniq()
    end
  end

  @dialyzer {:no_return, run_benchmarks: 2}
  defp run_benchmarks(suites, opts) do
    Enum.map(suites, fn suite ->
      Mix.shell().info("\n▶ Running #{suite} benchmarks...")

      suite_module = get_suite_module(suite)
      suite_data = get_suite_data(suite_module, suite)
      results = suite_module.run_suite(suite_data, opts)

      %{
        suite_name: suite,
        results: results,
        duration: results.duration,
        timestamp: DateTime.utc_now()
      }
    end)
  end

  @dialyzer {:no_return, get_suite_data: 2}
  defp get_suite_data(runner_module, suite) do
    case suite do
      "terminal" -> runner_module.terminal_benchmarks()
      "rendering" -> runner_module.rendering_benchmarks()
      "buffer" -> runner_module.buffer_benchmarks()
      "plugin" -> runner_module.plugin_benchmarks()
      "component" -> runner_module.component_benchmarks()
      "security" -> runner_module.security_benchmarks()
      _ -> raise "Unknown suite: #{suite}"
    end
  end

  @dialyzer {:no_return, run_profiling: 2}
  defp run_profiling(suites, opts) do
    Mix.shell().info("\n🔍 Running in profiling mode...")

    Enum.map(suites, fn suite ->
      Mix.shell().info("\n▶ Profiling #{suite} suite...")

      suite_module = get_suite_module(suite)
      suite_data = get_suite_data(suite_module, suite)
      profile_opts = Map.put(opts, :profile_after, true)

      results = suite_module.run_suite(suite_data, profile_opts)

      # Analyze profile data
      profile_report = Analyzer.analyze_profile(suite, results.results)
      print_profile_report(profile_report)

      %{
        suite_name: suite,
        results: results.results,
        profile: profile_report,
        duration: results.duration,
        timestamp: DateTime.utc_now()
      }
    end)
  end

  @dialyzer {:no_return, process_results: 2}
  defp process_results(results, opts) do
    # Compare with baseline if requested
    handle_comparison(opts[:compare], results)

    # Save baseline if requested
    case opts[:save_baseline] do
      true ->
        Mix.shell().info("\n💾 Saving new baseline...")

        Enum.each(results, fn result ->
          Storage.save_baseline(result.suite_name, result.results)
        end)

        Mix.shell().info("✅ Baseline saved")

      _ ->
        :ok
    end

    # Generate reports
    format = opts[:format] || "console"
    output_path = opts[:output] || "bench/output"

    Mix.shell().info("\n📄 Generating #{format} report...")

    Reporter.generate_comprehensive_report(results,
      format: String.to_atom(format),
      output_path: output_path
    )

    # Always save results for historical tracking
    Enum.each(results, fn result ->
      Storage.save_results(result.suite_name, result.results, result.duration)
    end)
  end

  @dialyzer {:no_return, get_suite_module: 1}
  defp get_suite_module(_suite) do
    Raxol.Benchmark.Runner
  end

  @dialyzer {:no_return, compile_filter: 1}
  defp compile_filter(pattern) do
    case Regex.compile(pattern) do
      {:ok, regex} ->
        regex

      {:error, _} ->
        Mix.shell().error("Invalid regex pattern: #{pattern}")
        System.halt(1)
    end
  end

  @dialyzer {:no_return, print_profile_report: 1}
  defp print_profile_report(report) do
    IO.puts("""

    Profile Analysis: #{report.name}
    =====================================
    Total Time: #{format_time(report.total_time)}
    Memory Usage: #{format_memory(report.memory_usage)}

    Hot Spots:
    #{format_hot_spots(report.hot_spots)}

    Optimization Opportunities:
    #{format_optimizations(report.optimization_opportunities)}
    """)
  end

  @dialyzer {:no_return, format_time: 1}
  defp format_time(microseconds) when is_number(microseconds) do
    format_time_unit(microseconds)
  end

  defp format_time(_), do: "N/A"

  defp format_time_unit(us) when us < 1_000, do: "#{us}μs"

  defp format_time_unit(us) when us < 1_000_000,
    do: "#{Float.round(us / 1_000, 2)}ms"

  defp format_time_unit(us), do: "#{Float.round(us / 1_000_000, 2)}s"

  @dialyzer {:no_return, format_memory: 1}
  defp format_memory(bytes) when is_number(bytes) do
    format_memory_unit(bytes)
  end

  defp format_memory(_), do: "N/A"

  defp format_memory_unit(b) when b < 1_024, do: "#{b}B"

  defp format_memory_unit(b) when b < 1_048_576,
    do: "#{Float.round(b / 1_024, 2)}KB"

  defp format_memory_unit(b) when b < 1_073_741_824,
    do: "#{Float.round(b / 1_048_576, 2)}MB"

  defp format_memory_unit(b), do: "#{Float.round(b / 1_073_741_824, 2)}GB"

  defp format_hot_spots([]), do: "  None identified"

  @dialyzer {:no_return, format_hot_spots: 1}
  defp format_hot_spots(spots) do
    Enum.map_join(spots, "\n", fn spot -> "  • #{spot}" end)
  end

  @dialyzer {:no_return, format_optimizations: 1}
  defp format_optimizations([]), do: "  None identified"

  defp format_optimizations(opts) do
    Enum.map_join(opts, "\n", fn opt -> "  • #{opt}" end)
  end

  # Helper functions for if statement elimination

  defp handle_help_option(true) do
    Mix.shell().info(@moduledoc)
    System.halt(0)
  end

  defp handle_help_option(_), do: :ok

  defp validate_suite_list(true) do
    Mix.shell().error(
      "No benchmark suites specified. Use --all or --suite <name>"
    )

    Mix.shell().info("Available suites: #{Enum.join(@all_suites, ", ")}")
    System.halt(1)
  end

  defp validate_suite_list(false), do: :ok

  defp execute_suite_mode(true, suites, benchmark_opts) do
    run_profiling(suites, benchmark_opts)
  end

  defp execute_suite_mode(_profile_mode, suites, benchmark_opts) do
    run_benchmarks(suites, benchmark_opts)
  end

  defp get_memory_time(true), do: 2
  defp get_memory_time(_), do: 0

  defp apply_quick_mode(true, base_opts) do
    %{base_opts | time: 1, warmup: 0.5}
  end

  defp apply_quick_mode(_quick_mode, base_opts), do: base_opts

  defp apply_only_filter(nil, base_opts), do: base_opts

  defp apply_only_filter(only_pattern, base_opts) do
    Map.put(base_opts, :only, compile_filter(only_pattern))
  end

  defp apply_except_filter(nil, base_opts), do: base_opts

  defp apply_except_filter(except_pattern, base_opts) do
    Map.put(base_opts, :except, compile_filter(except_pattern))
  end

  defp handle_comparison(true, results) do
    Mix.shell().info("\n📊 Comparing with baseline...")
    regressions = Analyzer.check_regressions(results)
    report_regressions(Enum.any?(regressions), regressions)
  end

  defp handle_comparison(_compare_mode, _results), do: :ok

  defp report_regressions(true, regressions) do
    Mix.shell().warning("\n⚠️  Performance regressions detected!")
    Analyzer.report_regressions(regressions)
  end

  defp report_regressions(false, _regressions) do
    Mix.shell().info("✅ No regressions detected")
  end
end
