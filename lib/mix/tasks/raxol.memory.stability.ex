defmodule Mix.Tasks.Raxol.Memory.Stability do
  @moduledoc """
  Long-running memory stability tests for detecting memory leaks and performance degradation.

  This task runs extended memory tests that simulate real-world usage patterns
  over extended periods to detect memory leaks, performance degradation, and
  stability issues.

  ## Usage

      mix raxol.memory.stability
      mix raxol.memory.stability --duration 3600
      mix raxol.memory.stability --scenario vim_session
      mix raxol.memory.stability --with-profiling

  ## Options

    * `--duration` - Test duration in seconds (default: 1800 = 30 minutes)
    * `--scenario` - Specific scenario to test (vim_session, log_streaming, interactive_shell)
    * `--with-profiling` - Enable detailed memory profiling
    * `--output` - Output directory for results (default: bench/stability)
    * `--interval` - Measurement interval in seconds (default: 30)
    * `--memory-threshold` - Memory growth threshold in MB (default: 10)

  ## Test Scenarios

  ### vim_session
  Simulates a Vim editing session with:
  - File editing operations
  - Syntax highlighting
  - Buffer management
  - Search and replace operations

  ### log_streaming
  Simulates continuous log streaming with:
  - High-frequency text updates
  - ANSI color processing
  - Buffer scrolling
  - Pattern matching

  ### interactive_shell
  Simulates interactive shell usage with:
  - Command execution
  - Output processing
  - History management
  - Tab completion

  ## Exit Codes

  - 0: Stability test passed
  - 1: Memory leak detected
  - 2: Performance degradation detected
  - 3: Test execution failed
  """

  use Mix.Task
  alias Raxol.Terminal.{Buffer, ANSI.AnsiParser, Cursor.Manager}

  @shortdoc "Run long-running memory stability tests"

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          duration: :integer,
          scenario: :string,
          with_profiling: :boolean,
          output: :string,
          interval: :integer,
          memory_threshold: :float,
          help: :boolean
        ],
        aliases: [d: :duration, s: :scenario, o: :output, h: :help]
      )

    if opts[:help] do
      print_help()
      System.halt(0)
    end

    Application.ensure_all_started(:raxol)

    config = build_config(opts)
    Mix.shell().info("Memory Stability Test")
    Mix.shell().info("====================")

    Mix.shell().info(
      "Duration: #{config.duration}s (#{Float.round(config.duration / 60, 1)} minutes)"
    )

    Mix.shell().info("Scenario: #{config.scenario}")
    Mix.shell().info("Measurement interval: #{config.interval}s")
    Mix.shell().info("Memory threshold: #{config.memory_threshold}MB growth")

    try do
      results = run_stability_test(config)
      exit_code = analyze_results(results, config)
      save_results(results, config)
      System.halt(exit_code)
    rescue
      error ->
        Mix.shell().error("Stability test failed: #{inspect(error)}")
        System.halt(3)
    end
  end

  defp build_config(opts) do
    %{
      duration: Keyword.get(opts, :duration, 1800),
      scenario: Keyword.get(opts, :scenario, "vim_session"),
      with_profiling: Keyword.get(opts, :with_profiling, false),
      output: Keyword.get(opts, :output, "bench/stability"),
      interval: Keyword.get(opts, :interval, 30),
      memory_threshold: Keyword.get(opts, :memory_threshold, 10.0)
    }
  end

  defp run_stability_test(config) do
    File.mkdir_p(config.output)

    initial_memory = get_memory_info()
    start_time = System.monotonic_time(:millisecond)

    Mix.shell().info("Starting stability test...")
    Mix.shell().info("Initial memory: #{format_memory(initial_memory.total)}")

    # Start the scenario task
    scenario_task =
      Task.async(fn -> run_scenario(config.scenario, config.duration) end)

    # Start memory monitoring
    monitoring_task = Task.async(fn -> monitor_memory(config, start_time) end)

    # Wait for both tasks to complete
    scenario_result = Task.await(scenario_task, (config.duration + 60) * 1000)

    memory_measurements =
      Task.await(monitoring_task, (config.duration + 60) * 1000)

    final_memory = get_memory_info()
    end_time = System.monotonic_time(:millisecond)

    %{
      config: config,
      start_time: start_time,
      end_time: end_time,
      duration: end_time - start_time,
      initial_memory: initial_memory,
      final_memory: final_memory,
      memory_measurements: memory_measurements,
      scenario_result: scenario_result
    }
  end

  defp run_scenario("vim_session", duration), do: simulate_vim_session(duration)

  defp run_scenario("log_streaming", duration),
    do: simulate_log_streaming(duration)

  defp run_scenario("interactive_shell", duration),
    do: simulate_interactive_shell(duration)

  defp run_scenario(scenario, _duration) do
    Mix.shell().error("Unknown scenario: #{scenario}")
    %{error: "unknown_scenario"}
  end

  defp simulate_vim_session(duration) do
    Mix.shell().info("Simulating Vim session...")
    {:ok, buffer} = Buffer.new(120, 40)

    start_time = System.monotonic_time(:millisecond)
    operations_count = 0

    vim_operations = [
      &vim_write_text/1,
      &vim_navigate/1,
      &vim_search_replace/1,
      &vim_syntax_highlight/1,
      &vim_buffer_management/1
    ]

    Stream.repeatedly(fn -> Enum.random(vim_operations) end)
    |> Stream.scan({buffer, operations_count}, fn operation,
                                                  {current_buffer, count} ->
      if System.monotonic_time(:millisecond) - start_time < duration * 1000 do
        updated_buffer = operation.(current_buffer)

        # Periodic garbage collection
        if rem(count, 100) == 0 do
          :erlang.garbage_collect()
        end

        {updated_buffer, count + 1}
      else
        {current_buffer, count}
      end
    end)
    |> Stream.take_while(fn {_buffer, _count} ->
      System.monotonic_time(:millisecond) - start_time < duration * 1000
    end)
    |> Enum.to_list()
    |> List.last()
    |> case do
      {final_buffer, final_count} ->
        %{buffer: final_buffer, operations: final_count, type: "vim_session"}

      _ ->
        %{operations: 0, type: "vim_session"}
    end
  end

  defp simulate_log_streaming(duration) do
    Mix.shell().info("Simulating log streaming...")
    {:ok, buffer} = Buffer.create(100, 50)

    start_time = System.monotonic_time(:millisecond)
    _lines_processed = 0

    log_levels = ["INFO", "WARN", "ERROR", "DEBUG"]
    # Green, Yellow, Red, Cyan
    color_codes = [32, 33, 31, 36]

    Stream.iterate(0, &(&1 + 1))
    |> Stream.map(fn line_num ->
      if System.monotonic_time(:millisecond) - start_time < duration * 1000 do
        level = Enum.random(log_levels)
        color = Enum.random(color_codes)
        timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

        log_line =
          "\e[#{color}m[#{timestamp}] #{level}: Log entry #{line_num}\e[0m"

        # Process ANSI sequences
        _parsed = AnsiParser.parse(log_line)

        # Write to buffer (simulate scrolling)
        _row = rem(line_num, 50)

        case Buffer.write(buffer, log_line) do
          {:ok, updated_buffer} -> {updated_buffer, line_num + 1}
          _ -> {buffer, line_num + 1}
        end
      else
        {buffer, line_num}
      end
    end)
    |> Stream.take_while(fn {_buffer, _count} ->
      System.monotonic_time(:millisecond) - start_time < duration * 1000
    end)
    |> Enum.to_list()
    |> List.last()
    |> case do
      {final_buffer, final_count} ->
        %{buffer: final_buffer, lines: final_count, type: "log_streaming"}

      _ ->
        %{lines: 0, type: "log_streaming"}
    end
  end

  defp simulate_interactive_shell(duration) do
    Mix.shell().info("Simulating interactive shell...")
    {:ok, buffer} = Buffer.create(80, 24)

    start_time = System.monotonic_time(:millisecond)
    _commands_executed = 0

    shell_commands = [
      "ls -la",
      "ps aux",
      "find . -name '*.ex'",
      "grep -r 'defmodule' lib/",
      "cat README.md",
      "tail -f /var/log/system.log",
      "top -l 1"
    ]

    Stream.iterate(0, &(&1 + 1))
    |> Stream.map(fn cmd_num ->
      if System.monotonic_time(:millisecond) - start_time < duration * 1000 do
        command = Enum.random(shell_commands)

        # Simulate command prompt
        prompt = "$ #{command}"

        # Simulate command output
        output_lines = generate_command_output(command, cmd_num)

        # Write to buffer
        updated_buffer =
          Enum.reduce([prompt | output_lines], buffer, fn line, acc_buffer ->
            # Each command takes ~3 lines
            _row = rem(cmd_num * 3, 24)

            case Buffer.write(acc_buffer, line) do
              {:ok, new_buffer} -> new_buffer
              _ -> acc_buffer
            end
          end)

        # Simulate typing delay
        Process.sleep(100)

        {updated_buffer, cmd_num + 1}
      else
        {buffer, cmd_num}
      end
    end)
    |> Stream.take_while(fn {_buffer, _count} ->
      System.monotonic_time(:millisecond) - start_time < duration * 1000
    end)
    |> Enum.to_list()
    |> List.last()
    |> case do
      {final_buffer, final_count} ->
        %{
          buffer: final_buffer,
          commands: final_count,
          type: "interactive_shell"
        }

      _ ->
        %{commands: 0, type: "interactive_shell"}
    end
  end

  # Vim operation helpers
  defp vim_write_text(buffer) do
    text =
      "def function_#{:rand.uniform(1000)}(param) do\n  # Implementation here\nend"

    case Buffer.write(buffer, text) do
      {:ok, updated_buffer} -> updated_buffer
      _ -> buffer
    end
  end

  defp vim_navigate(buffer) do
    # Simulate cursor movements (doesn't modify buffer)
    {:ok, cursor} = Manager.new()

    _moved_cursor =
      cursor
      |> Manager.move_to(:rand.uniform(120), :rand.uniform(40))
      |> Manager.move_to(:rand.uniform(80), :rand.uniform(40))

    buffer
  end

  defp vim_search_replace(buffer) do
    # Simulate search and replace operation
    _search_term = "function_#{:rand.uniform(100)}"
    _replace_term = "method_#{:rand.uniform(100)}"

    # This would normally search and replace in buffer
    # For simulation, just return the buffer
    buffer
  end

  defp vim_syntax_highlight(buffer) do
    # Simulate syntax highlighting by parsing ANSI sequences
    highlight_sequences = [
      # Blue for keywords
      "\e[34mdef\e[0m",
      # Green for strings
      "\e[32m'string'\e[0m",
      # Yellow for comments
      "\e[33m# comment\e[0m"
    ]

    Enum.each(highlight_sequences, &AnsiParser.parse/1)
    buffer
  end

  defp vim_buffer_management(buffer) do
    # Simulate buffer operations like clear/resize
    case :rand.uniform(3) do
      1 ->
        case Buffer.clear(buffer) do
          {:ok, cleared} -> cleared
          _ -> buffer
        end

      _ ->
        buffer
    end
  end

  defp generate_command_output(command, cmd_num) do
    case command do
      "ls -la" ->
        [
          "total 48",
          "drwxr-xr-x  8 user staff  256 Sep 16 10:30 .",
          "drwxr-xr-x  3 user staff   96 Sep 16 10:29 .."
        ]

      "ps aux" ->
        [
          "USER   PID  %CPU %MEM    VSZ   RSS TTY   STAT START   TIME COMMAND",
          "user  #{1000 + cmd_num}   0.0  0.1  12345  1234 pts/0    S    10:30   0:00 bash"
        ]

      _ ->
        [
          "Command output line 1 for #{command}",
          "Command output line 2 for #{command}"
        ]
    end
  end

  defp monitor_memory(config, start_time) do
    measurements = []
    monitor_memory_loop(config, start_time, measurements)
  end

  defp monitor_memory_loop(config, start_time, measurements) do
    current_time = System.monotonic_time(:millisecond)
    elapsed = (current_time - start_time) / 1000

    if elapsed < config.duration do
      memory_info = get_memory_info()

      measurement = %{
        timestamp: current_time,
        elapsed: elapsed,
        memory: memory_info
      }

      updated_measurements = [measurement | measurements]

      if config.with_profiling do
        Mix.shell().info(
          "Memory at #{Float.round(elapsed, 1)}s: #{format_memory(memory_info.total)}"
        )
      end

      Process.sleep(config.interval * 1000)
      monitor_memory_loop(config, start_time, updated_measurements)
    else
      Enum.reverse(measurements)
    end
  end

  defp get_memory_info do
    %{
      total: :erlang.memory(:total),
      processes: :erlang.memory(:processes),
      system: :erlang.memory(:system),
      atom: :erlang.memory(:atom),
      binary: :erlang.memory(:binary),
      ets: :erlang.memory(:ets)
    }
  end

  defp analyze_results(results, config) do
    Mix.shell().info("\nAnalyzing stability test results...")

    memory_analysis = analyze_memory_trend(results.memory_measurements)
    leak_detection = detect_memory_leak(results, config)
    performance_analysis = analyze_performance(results)

    Mix.shell().info("\nMemory Analysis:")

    Mix.shell().info(
      "  Initial: #{format_memory(results.initial_memory.total)}"
    )

    Mix.shell().info("  Final: #{format_memory(results.final_memory.total)}")
    Mix.shell().info("  Growth: #{format_memory(memory_analysis.total_growth)}")

    Mix.shell().info(
      "  Growth rate: #{Float.round(memory_analysis.growth_rate_mb_per_hour, 2)} MB/hour"
    )

    case {leak_detection.status, performance_analysis.status} do
      {:leak_detected, _} ->
        Mix.shell().info("Result: Memory leak detected!")
        1

      {_, :degradation_detected} ->
        Mix.shell().info("Result: Performance degradation detected!")
        2

      _ ->
        Mix.shell().info("Result: Stability test passed")
        0
    end
  end

  defp analyze_memory_trend(measurements) do
    if length(measurements) < 2 do
      %{total_growth: 0, growth_rate_mb_per_hour: 0.0}
    else
      first = List.first(measurements)
      last = List.last(measurements)

      total_growth = last.memory.total - first.memory.total
      elapsed_hours = (last.elapsed - first.elapsed) / 3600

      growth_rate_mb_per_hour =
        if elapsed_hours > 0 do
          total_growth / 1_000_000 / elapsed_hours
        else
          0.0
        end

      %{
        total_growth: total_growth,
        growth_rate_mb_per_hour: growth_rate_mb_per_hour,
        measurements_count: length(measurements)
      }
    end
  end

  defp detect_memory_leak(results, config) do
    growth_mb =
      (results.final_memory.total - results.initial_memory.total) / 1_000_000

    if growth_mb > config.memory_threshold do
      %{
        status: :leak_detected,
        growth_mb: growth_mb,
        threshold_mb: config.memory_threshold
      }
    else
      %{
        status: :no_leak,
        growth_mb: growth_mb,
        threshold_mb: config.memory_threshold
      }
    end
  end

  defp analyze_performance(results) do
    # Analyze if operations per second degraded over time
    # This is a simplified analysis - could be more sophisticated

    case results.scenario_result do
      %{operations: ops} when ops > 0 ->
        duration_hours = results.duration / (1000 * 3600)
        ops_per_hour = ops / duration_hours

        # If less than 100 operations per hour, consider it degraded
        if ops_per_hour < 100 do
          %{status: :degradation_detected, ops_per_hour: ops_per_hour}
        else
          %{status: :normal, ops_per_hour: ops_per_hour}
        end

      _ ->
        %{status: :unknown}
    end
  end

  defp save_results(results, config) do
    timestamp =
      DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")

    filename = "stability_#{config.scenario}_#{timestamp}.json"
    output_path = Path.join(config.output, filename)

    content = Jason.encode!(results, pretty: true)
    File.write!(output_path, content)

    Mix.shell().info("Results saved to: #{output_path}")
  end

  defp format_memory(bytes) when is_number(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 2)}GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 2)}MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 2)}KB"
      true -> "#{bytes}B"
    end
  end

  defp format_memory(_), do: "N/A"

  defp print_help do
    Mix.shell().info(@moduledoc)
  end
end
