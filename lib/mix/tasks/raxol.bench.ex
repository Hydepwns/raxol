defmodule Mix.Tasks.Raxol.Bench do
  @moduledoc """
  Enhanced benchmarking task for Raxol terminal emulator.

  Provides comprehensive performance benchmarking with multiple
  output formats, regression detection, and dashboard generation.

  ## Usage

      mix raxol.bench                    # Run all benchmarks
      mix raxol.bench parser             # Run parser benchmarks only
      mix raxol.bench terminal           # Run terminal component benchmarks
      mix raxol.bench rendering          # Run rendering benchmarks only
      mix raxol.bench memory             # Run memory benchmarks only
      mix raxol.bench dashboard          # Generate dashboard from latest results

  ## Options

    * `--quick`       - Quick benchmark run with reduced time
    * `--compare`     - Compare with previous benchmark results
    * `--dashboard`   - Generate full performance dashboard with charts
    * `--regression`  - Check for performance regressions (5% threshold)
    * `--help`        - Show detailed help

  ## Examples

      # Quick performance check
      mix raxol.bench --quick

      # Full benchmarks with regression detection
      mix raxol.bench --regression

      # Parser benchmarks with dashboard generation
      mix raxol.bench parser --dashboard

      # Compare current run with previous results
      mix raxol.bench --compare

  ## Output

  Results are saved to `bench/output/enhanced/` with:
    - HTML reports for interactive viewing
    - JSON data for programmatic analysis
    - Performance dashboard with charts
    - Regression analysis reports
    - Baseline metrics for future comparison
  """

  use Mix.Task

  @shortdoc "Run enhanced performance benchmarks"

  @compile {:no_warn_undefined, Raxol.Bench.Dashboard}
  @compile {:no_warn_undefined, Raxol.Bench.TestData}

  alias Raxol.Bench.{Dashboard, TestData}

  @switches [
    quick: :boolean,
    compare: :boolean,
    dashboard: :boolean,
    regression: :boolean,
    help: :boolean
  ]

  def run(args) do
    {opts, args, _} = OptionParser.parse(args, switches: @switches)

    case {opts[:help], args} do
      {true, _} ->
        print_help()

      {false, benchmark_args} ->
        Mix.Task.run("app.start")
        execute_benchmark(benchmark_args, opts)
    end
  end

  defp execute_benchmark(args, opts) do
    case args do
      [] ->
        run_all_benchmarks(opts)

      ["parser"] ->
        run_parser_only(opts)

      ["terminal"] ->
        run_terminal_only(opts)

      ["rendering"] ->
        run_rendering_only(opts)

      ["memory"] ->
        run_memory_only(opts)

      ["dashboard"] ->
        run_dashboard_only(opts)

      [benchmark] ->
        Mix.shell().error("Unknown benchmark: #{benchmark}")
        print_help()
    end
  end

  defp run_all_benchmarks(opts) do
    Mix.shell().info("Running Raxol Performance Benchmarks...")

    if opts[:quick] do
      run_quick_benchmarks()
    else
      run_comprehensive_benchmarks(opts)
    end
  end

  defp run_quick_benchmarks do
    Mix.shell().info("Quick benchmark mode (reduced time)")

    benchmark_config = [
      time: 1,
      memory_time: 0.5,
      warmup: 0.2,
      formatters: [Benchee.Formatters.Console]
    ]

    _ = run_parser_benchmarks(benchmark_config, quick: true)
    _ = run_terminal_benchmarks(benchmark_config, quick: true)
  end

  defp run_comprehensive_benchmarks(opts) do
    Mix.shell().info("Running comprehensive benchmarks...")

    File.mkdir_p!("bench/output/enhanced")
    File.mkdir_p!("bench/output/enhanced/json")
    File.mkdir_p!("bench/output/enhanced/html")

    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    results =
      %{}
      |> Map.put(:parser, run_parser_benchmarks(standard_config(timestamp)))
      |> Map.put(:terminal, run_terminal_benchmarks(standard_config(timestamp)))
      |> Map.put(
        :rendering,
        run_rendering_benchmarks(standard_config(timestamp))
      )
      |> Map.put(:memory, run_memory_benchmarks(standard_config(timestamp)))
      |> Map.put(
        :concurrent,
        run_concurrent_benchmarks(standard_config(timestamp))
      )

    if opts[:regression], do: Dashboard.check_for_regressions(results)

    if opts[:dashboard],
      do: Dashboard.generate_enhanced_dashboard(results, timestamp)

    if opts[:compare], do: Dashboard.run_comparison_analysis(results, timestamp)

    Dashboard.print_results_summary(results, timestamp)
  end

  defp run_parser_only(opts) do
    Mix.shell().info("Running Parser Benchmarks Only...")
    config = if opts[:quick], do: quick_config(), else: standard_config()
    run_parser_benchmarks(config)
  end

  defp run_terminal_only(opts) do
    Mix.shell().info("Running Terminal Component Benchmarks Only...")
    config = if opts[:quick], do: quick_config(), else: standard_config()
    run_terminal_benchmarks(config)
  end

  defp run_rendering_only(opts) do
    Mix.shell().info("Running Rendering Benchmarks Only...")
    config = if opts[:quick], do: quick_config(), else: standard_config()
    run_rendering_benchmarks(config)
  end

  defp run_memory_only(opts) do
    Mix.shell().info("Running Memory Benchmarks Only...")
    config = if opts[:quick], do: quick_config(), else: standard_config()
    run_memory_benchmarks(config)
  end

  defp run_dashboard_only(_opts) do
    Mix.shell().info("Generating Performance Dashboard...")
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    results = Dashboard.load_latest_results() || %{}
    Dashboard.generate_enhanced_dashboard(results, timestamp)

    Mix.shell().info(
      "Dashboard generated at bench/output/enhanced/dashboard.html"
    )
  end

  defp run_parser_benchmarks(config, opts \\ []) do
    alias Raxol.Terminal.ANSI.StateMachine
    alias Raxol.Terminal.ANSI.Utils.AnsiParser
    alias Raxol.Terminal.Emulator

    _emulator = Emulator.new(80, 24)

    scenarios =
      if opts[:quick] do
        %{
          "plain_text" => "Hello, World!",
          "ansi_basic" => "\e[31mRed Text\e[0m",
          "ansi_complex" => "\e[1;4;31mBold Red Underlined\e[0m"
        }
      else
        TestData.full_parser_scenarios()
      end

    jobs =
      Enum.into(scenarios, %{}, fn {name, content} ->
        {name,
         fn ->
           state_machine = StateMachine.new()
           AnsiParser.parse(state_machine, content)
         end}
      end)

    Benchee.run(jobs, config)
  end

  defp run_terminal_benchmarks(config, opts \\ []) do
    jobs =
      if opts[:quick],
        do: TestData.terminal_quick_jobs(),
        else: TestData.terminal_comprehensive_jobs()

    Benchee.run(jobs, config)
  end

  defp run_rendering_benchmarks(config) do
    alias Raxol.UI.Rendering.RenderBatcher

    {_small_buffer, medium_buffer, large_buffer} =
      TestData.create_test_buffers()

    jobs = %{
      "render_with_damage_tracking" => fn ->
        RenderBatcher.batch_render(medium_buffer,
          changed_regions: [{0, 0, 10, 10}]
        )
      end,
      "render_full_redraw" => fn ->
        RenderBatcher.batch_render(large_buffer, full_redraw: true)
      end
    }

    Benchee.run(jobs, config)
  end

  defp run_memory_benchmarks(config) do
    alias Raxol.Terminal.ANSI.StateMachine
    alias Raxol.Terminal.ANSI.Utils.AnsiParser
    alias Raxol.Terminal.Cursor
    alias Raxol.Terminal.Emulator
    alias Raxol.Terminal.ScreenBufferAdapter, as: ScreenBuffer

    jobs = %{
      "memory_emulator_80x24" => fn -> Emulator.new(80, 24) end,
      "memory_emulator_200x50" => fn -> Emulator.new(200, 50) end,
      "memory_parser_session" => fn ->
        emulator = Emulator.new(80, 24)
        state_machine = StateMachine.new()
        content = TestData.generate_test_content()
        _ = AnsiParser.parse(state_machine, content)
        {emulator, state_machine}
      end,
      "memory_buffer_operations" => fn ->
        buffer = ScreenBuffer.new(100, 30)
        _cursor = Cursor.new()

        buffer =
          Enum.reduce(1..50, buffer, fn i, acc ->
            ScreenBuffer.write_string(acc, 0, rem(i, 30), "Test line #{i}")
          end)

        buffer
      end,
      "memory_large_buffer_allocation" => fn -> ScreenBuffer.new(500, 500) end,
      "memory_plugin_system" => fn ->
        alias Raxol.Plugins.Manager
        {:ok, manager} = Manager.new()
        Manager.list_plugins(manager)
      end
    }

    Benchee.run(jobs, config)
  end

  defp run_concurrent_benchmarks(config) do
    jobs = %{
      "concurrent_emulator_creation" => &bench_emulator_creation/0,
      "concurrent_buffer_writes" => &bench_buffer_writes/0,
      "concurrent_event_dispatch" => &bench_event_dispatch/0,
      "concurrent_plugin_operations" => &bench_plugin_operations/0
    }

    Benchee.run(jobs, config)
  end

  defp bench_emulator_creation do
    alias Raxol.Terminal.Emulator

    1..10
    |> Enum.map(fn _ -> Task.async(fn -> Emulator.new(80, 24) end) end)
    |> Task.await_many()
  end

  defp bench_buffer_writes do
    alias Raxol.Terminal.ScreenBufferAdapter, as: ScreenBuffer
    buffer = ScreenBuffer.new(80, 24)

    1..10
    |> Enum.map(fn i ->
      Task.async(fn -> ScreenBuffer.write_char(buffer, i, i, "X") end)
    end)
    |> Task.await_many()
  end

  defp bench_event_dispatch do
    alias Raxol.Core.Events.EventManager

    case EventManager.start_link(name: EventManager) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    1..20
    |> Enum.map(fn i ->
      Task.async(fn -> EventManager.dispatch(:test_event, %{id: i}) end)
    end)
    |> Task.await_many()
  end

  defp bench_plugin_operations do
    alias Raxol.Plugins.Manager

    {:ok, manager} = Manager.new()

    1..5
    |> Enum.map(fn _ ->
      Task.async(fn ->
        _plugins = Manager.list_plugins(manager)
        Manager.get_plugin_state(manager, "test_plugin")
      end)
    end)
    |> Task.await_many()
  end

  defp standard_config(timestamp \\ nil) do
    ts = timestamp || DateTime.utc_now() |> DateTime.to_iso8601()

    [
      time: 5,
      memory_time: 2,
      warmup: 1,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.JSON,
         file: "bench/output/enhanced/json/benchmark_#{ts}.json"},
        {Benchee.Formatters.HTML,
         file: "bench/output/enhanced/html/benchmark_#{ts}.html"}
      ],
      save: [path: "bench/output/enhanced/benchee_#{ts}.benchee"],
      load: "bench/output/enhanced/*.benchee"
    ]
  end

  defp quick_config do
    [
      time: 1,
      memory_time: 0.5,
      warmup: 0.2,
      formatters: [Benchee.Formatters.Console]
    ]
  end

  defp print_help do
    Mix.shell().info("""

    Raxol Enhanced Benchmarking Tool

    Usage:
      mix raxol.bench                    # Run all benchmarks
      mix raxol.bench parser             # Run parser benchmarks only
      mix raxol.bench terminal           # Run terminal component benchmarks
      mix raxol.bench rendering          # Run rendering benchmarks
      mix raxol.bench memory             # Run memory benchmarks
      mix raxol.bench dashboard          # Generate dashboard from latest results

    Options:
      --quick                            # Quick benchmark run (reduced time)
      --compare                          # Compare with previous results
      --dashboard                        # Generate full performance dashboard
      --regression                       # Check for performance regressions (5% threshold)
      --help                             # Show this help

    Examples:
      mix raxol.bench --quick            # Quick performance check
      mix raxol.bench parser --dashboard # Parser benchmarks + dashboard
      mix raxol.bench --regression       # Full benchmarks with regression detection

    Output:
      Results are saved to bench/output/enhanced/ with:
      * HTML reports for interactive viewing
      * JSON data for programmatic analysis
      * Performance dashboard with charts
      * Regression analysis reports
      * Baseline metrics for comparison
    """)
  end
end
