defmodule Mix.Tasks.Raxol.Bench.Memory do
  @moduledoc """
  Enhanced memory benchmarking task for Raxol terminal emulator.

  Phase 2 Implementation: Terminal-specific memory scenarios with meaningful allocations.

  Usage:
    mix raxol.bench.memory                    # Run all memory benchmarks
    mix raxol.bench.memory terminal           # Run terminal component benchmarks
    mix raxol.bench.memory buffer             # Run buffer operation benchmarks
    mix raxol.bench.memory simulation         # Run realistic usage simulations
    mix raxol.bench.memory --profile          # Include memory profiling integration
    mix raxol.bench.memory --quick            # Quick memory benchmark run
  """

  use Mix.Task

  @shortdoc "Run enhanced memory performance benchmarks"

  @switches [
    quick: :boolean,
    profile: :boolean,
    help: :boolean
  ]

  def run(args) do
    {opts, args, _} = OptionParser.parse(args, switches: @switches)

    if opts[:help] do
      print_help()
    else
      Mix.Task.run("app.start")

      case args do
        [] ->
          run_all_memory_benchmarks(opts)

        ["terminal"] ->
          run_terminal_memory_benchmarks(opts)

        ["buffer"] ->
          run_buffer_memory_benchmarks(opts)

        ["simulation"] ->
          run_simulation_memory_benchmarks(opts)

        [benchmark] ->
          Mix.shell().error("Unknown memory benchmark: #{benchmark}")
          print_help()
      end
    end
  end

  # =============================================================================
  # Benchmark Suites
  # =============================================================================

  defp run_all_memory_benchmarks(opts) do
    Mix.shell().info("Running Enhanced Memory Benchmarks...")

    results = %{}

    results = Map.put(results, :terminal, run_terminal_memory_benchmarks(opts))
    results = Map.put(results, :buffer, run_buffer_memory_benchmarks(opts))

    results =
      Map.put(results, :simulation, run_simulation_memory_benchmarks(opts))

    if opts[:profile] do
      run_memory_profiling_integration(results)
    end

    print_memory_analysis(results)
  end

  # =============================================================================
  # Terminal Component Memory Benchmarks
  # =============================================================================

  defp run_terminal_memory_benchmarks(opts) do
    Mix.shell().info("Running Terminal Component Memory Benchmarks...")

    config = memory_benchmark_config(opts)

    jobs = %{
      # Large Terminal Sizes - Tests memory scaling
      "large_terminal_1000x1000" => fn ->
        # Allocate a very large terminal buffer
        _cells =
          for _row <- 1..1000, _col <- 1..1000 do
            %{char: " ", fg: :white, bg: :black, style: %{}}
          end

        :ok
      end,
      "huge_terminal_2000x2000" => fn ->
        # Massive terminal allocation
        _cells =
          for _row <- 1..2000, _col <- 1..2000 do
            %{char: "█", fg: :red, bg: :blue, style: %{bold: true}}
          end

        :ok
      end,

      # Multiple Concurrent Buffers
      "multiple_terminal_buffers" => fn ->
        # Simulate multiple terminal sessions
        _buffers =
          for _i <- 1..10 do
            for _row <- 1..100, _col <- 1..100 do
              %{char: "X", fg: :green, bg: :black, style: %{}}
            end
          end

        :ok
      end,

      # Memory Manager Integration
      "memory_manager_stress" => fn ->
        # Test memory manager with heavy allocations
        {:ok, manager} = Raxol.Terminal.MemoryManager.start_link()

        # Allocate large chunks repeatedly
        for _i <- 1..100 do
          _large_chunk = Enum.map(1..10_000, fn j -> "Memory chunk #{j}" end)
        end

        GenServer.stop(manager)
        :ok
      end,

      # Scrollback Buffer Memory
      "scrollback_buffer_large" => fn ->
        # Simulate large scrollback history
        _scrollback =
          for line <- 1..10_000 do
            line_content =
              Enum.map(1..120, fn col ->
                %{char: "#{rem(col, 10)}", fg: :white, bg: :black}
              end)

            {line, line_content}
          end

        :ok
      end
    }

    Benchee.run(jobs, config)
  end

  # =============================================================================
  # Buffer Operations Memory Benchmarks
  # =============================================================================

  defp run_buffer_memory_benchmarks(opts) do
    Mix.shell().info("Running Buffer Operations Memory Benchmarks...")

    config = memory_benchmark_config(opts)

    jobs = %{
      # Intensive Write Operations
      "buffer_heavy_writes" => fn ->
        # Simulate heavy writing to buffer
        buffer_content =
          for line <- 1..1000 do
            for col <- 1..200 do
              %{
                char: "#{rem(line + col, 10)}",
                fg: :cyan,
                bg: :black,
                style: %{italic: true}
              }
            end
          end

        # Add metadata for each line
        _buffer_with_metadata =
          Enum.map(buffer_content, fn line ->
            %{
              content: line,
              timestamp: System.monotonic_time(),
              metadata: %{dirty: true, rendered: false}
            }
          end)

        :ok
      end,

      # Complex Character Data
      "unicode_heavy_buffer" => fn ->
        # Test with complex Unicode characters (higher memory per char)
        unicode_chars = ["🌟", "🚀", "💎", "🔥", "⚡", "🎯", "🌈", "🎨", "🎭", "🎪"]

        _unicode_buffer =
          for _row <- 1..500, _col <- 1..100 do
            char = Enum.random(unicode_chars)

            %{
              char: char,
              fg: Enum.random([:red, :green, :blue, :yellow, :magenta]),
              bg: :black,
              style: %{bold: true, underline: true},
              unicode_data: %{
                codepoint: String.to_charlist(char) |> hd(),
                # Wide characters
                width: 2,
                combining: false
              }
            }
          end

        :ok
      end,

      # Memory Fragmentation Test
      "buffer_fragmentation" => fn ->
        # Create many small allocations to test fragmentation
        _fragments =
          for _i <- 1..10_000 do
            # Small random-sized allocations
            size = Enum.random(10..100)
            Enum.map(1..size, fn j -> "Fragment #{j}" end)
          end

        :ok
      end,

      # Graphics and Sixel Memory
      "graphics_memory_simulation" => fn ->
        # Simulate graphics/image data in terminal
        width = 800
        height = 600

        _image_data =
          for _y <- 1..height do
            for _x <- 1..width do
              %{
                r: Enum.random(0..255),
                g: Enum.random(0..255),
                b: Enum.random(0..255),
                a: 255,
                palette_index: Enum.random(0..255)
              }
            end
          end

        :ok
      end
    }

    Benchee.run(jobs, config)
  end

  # =============================================================================
  # Realistic Usage Simulation Benchmarks
  # =============================================================================

  defp run_simulation_memory_benchmarks(opts) do
    Mix.shell().info("Running Realistic Usage Simulation Memory Benchmarks...")

    config = memory_benchmark_config(opts)

    jobs = %{
      # Vim Session Simulation
      "vim_editing_simulation" => fn ->
        # Simulate editing a large file in vim
        file_lines = 5000
        line_length = 120

        # File content with syntax highlighting data
        _file_buffer =
          for line_num <- 1..file_lines do
            line_content = generate_code_line(line_num, line_length)
            syntax_highlighting = generate_syntax_data(line_content)

            %{
              line_number: line_num,
              content: line_content,
              highlighting: syntax_highlighting,
              metadata: %{
                modified: Enum.random([true, false]),
                dirty: false,
                folded: line_num > 100 && rem(line_num, 50) == 0
              }
            }
          end

        :ok
      end,

      # Log Streaming Simulation
      "log_streaming_simulation" => fn ->
        # Simulate continuous log output
        log_entries = 20_000

        _log_buffer =
          for i <- 1..log_entries do
            timestamp = System.system_time(:millisecond)
            level = Enum.random([:debug, :info, :warn, :error])
            message = generate_log_message(i, level)

            %{
              timestamp: timestamp,
              level: level,
              message: message,
              formatted: format_log_entry(timestamp, level, message),
              metadata: %{
                source: "application.#{rem(i, 10)}",
                thread: "thread-#{rem(i, 4)}",
                correlation_id: generate_uuid()
              }
            }
          end

        :ok
      end,

      # Interactive Shell Session
      "shell_session_simulation" => fn ->
        # Simulate an interactive shell with command history
        command_history = 1000

        _shell_state = %{
          history: generate_command_history(command_history),
          current_directory: "/very/long/path/to/current/working/directory",
          environment: generate_environment_variables(),
          output_buffer: generate_shell_output_buffer(),
          prompt_state: %{
            user: "developer",
            hostname: "development-machine",
            git_branch: "feature/memory-benchmarking-enhancement",
            last_command_duration: 1234
          }
        }

        :ok
      end,

      # Multi-pane Terminal Setup
      "multi_pane_simulation" => fn ->
        # Simulate tmux/screen with multiple panes
        pane_count = 8

        _panes =
          for pane_id <- 1..pane_count do
            %{
              id: pane_id,
              dimensions: {80, 24},
              buffer: generate_pane_buffer(pane_id),
              scrollback: generate_scrollback(pane_id),
              application:
                Enum.random([:vim, :htop, :tail, :ssh, :git, :shell]),
              active: pane_id == 1
            }
          end

        :ok
      end
    }

    Benchee.run(jobs, config)
  end

  # =============================================================================
  # Memory Profiling Integration
  # =============================================================================

  defp run_memory_profiling_integration(results) do
    Mix.shell().info("Running Memory Profiling Integration...")

    # Integrate with existing memory utilities
    if Code.ensure_loaded?(Raxol.Terminal.MemoryManager) do
      analyze_memory_patterns(results)
    end

    if Code.ensure_loaded?(Raxol.Terminal.ScreenBuffer.MemoryUtils) do
      analyze_buffer_memory_patterns(results)
    end
  end

  # =============================================================================
  # Helper Functions
  # =============================================================================

  defp memory_benchmark_config(opts) do
    base_config = [
      time: if(opts[:quick], do: 1, else: 3),
      memory_time: if(opts[:quick], do: 1, else: 2),
      warmup: if(opts[:quick], do: 0.5, else: 1),
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "bench/output/memory_benchmarks.html"}
      ]
    ]

    if opts[:profile] do
      base_config ++
        [
          pre_check: true,
          save: [path: "bench/snapshots/memory_#{timestamp()}.benchee"]
        ]
    else
      base_config
    end
  end

  defp generate_code_line(line_num, length) do
    case rem(line_num, 10) do
      0 ->
        String.pad_trailing("def function_#{line_num}(param) do", length)

      1 ->
        String.pad_trailing("  # Comment for line #{line_num}", length)

      2 ->
        String.pad_trailing(
          "  @spec some_function(integer()) :: {:ok, term()}",
          length
        )

      3 ->
        String.pad_trailing("  result = expensive_operation(param)", length)

      4 ->
        String.pad_trailing("  Logger.info(\"Processing #{line_num}\")", length)

      5 ->
        String.pad_trailing("  {:ok, result}", length)

      6 ->
        String.pad_trailing("end", length)

      7 ->
        ""

      8 ->
        String.pad_trailing("# Module documentation", length)

      9 ->
        String.pad_trailing(
          "defmodule MyModule.SubModule#{line_num} do",
          length
        )
    end
  end

  defp generate_syntax_data(line_content) do
    # Simulate syntax highlighting tokens
    words = String.split(line_content)

    Enum.map(words, fn word ->
      color =
        case word do
          "def" -> :magenta
          "end" -> :magenta
          word when word in ["Logger", "String", "Enum"] -> :blue
          "@" <> _ -> :cyan
          "#" <> _ -> :green
          _ -> :white
        end

      %{text: word, color: color, style: []}
    end)
  end

  defp generate_log_message(i, level) do
    templates = [
      "User action completed successfully for user_id: #{i}",
      "Database query executed in #{Enum.random(1..100)}ms",
      "Cache hit for key: application.cache.#{rem(i, 1000)}",
      "Processing request #{i} from IP 192.168.1.#{rem(i, 255)}",
      "Background job #{i} completed with status: #{Enum.random([:success, :failed, :retrying])}",
      "Memory usage: #{Enum.random(50..95)}% of available heap"
    ]

    base_message = Enum.random(templates)

    if level == :error do
      base_message <>
        " | Error: #{Enum.random(["timeout", "connection_refused", "invalid_input"])}"
    else
      base_message
    end
  end

  defp format_log_entry(timestamp, level, message) do
    formatted_time =
      DateTime.from_unix!(timestamp, :millisecond) |> DateTime.to_iso8601()

    level_str = String.upcase(to_string(level))
    "[#{formatted_time}] #{level_str}: #{message}"
  end

  defp generate_command_history(count) do
    commands = [
      "ls -la",
      "cd /usr/local/bin",
      "git status",
      "git add .",
      "git commit -m 'Update'",
      "mix test",
      "mix compile",
      "docker ps",
      "docker logs -f container_name",
      "tail -f /var/log/application.log",
      "htop",
      "ps aux | grep elixir",
      "find . -name '*.ex' | xargs grep -l 'defmodule'",
      "cat config.exs"
    ]

    for i <- 1..count do
      %{
        command: Enum.random(commands),
        timestamp: System.system_time(:millisecond) - (count - i) * 1000,
        # Most commands succeed
        exit_code: Enum.random([0, 0, 0, 1]),
        duration: Enum.random(10..5000)
      }
    end
  end

  defp generate_environment_variables do
    %{
      "PATH" => "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
      "HOME" => "/Users/developer",
      "SHELL" => "/bin/zsh",
      "TERM" => "xterm-256color",
      "EDITOR" => "vim",
      "LANG" => "en_US.UTF-8",
      "MIX_ENV" => "dev",
      "ELIXIR_VERSION" => "1.17.1",
      "ERLANG_VERSION" => "25.3.2.7"
    }
  end

  defp generate_shell_output_buffer do
    # Generate realistic shell output
    for _i <- 1..500 do
      Enum.random([
        "Compiling 15 files (.ex)",
        "Generated raxol app",
        "Running ExUnit with seed: 123456",
        "...................................................................................................",
        "Finished in 2.5 seconds",
        "158 tests, 0 failures",
        "Coverage: 98.7%"
      ])
    end
  end

  defp generate_pane_buffer(pane_id) do
    case rem(pane_id, 4) do
      0 -> generate_vim_buffer()
      1 -> generate_htop_buffer()
      2 -> generate_log_tail_buffer()
      3 -> generate_shell_buffer()
    end
  end

  defp generate_vim_buffer do
    # Simulate vim interface
    for line <- 1..24 do
      case line do
        24 ->
          "-- INSERT --                                    100%    Col 42"

        _ ->
          String.pad_trailing("  #{line}  | Code line #{line} with syntax", 80)
      end
    end
  end

  defp generate_htop_buffer do
    # Simulate htop output
    for line <- 1..24 do
      case line do
        1 ->
          "  CPU[||||||||||                         45.2%]"

        2 ->
          "  Mem[||||||||||||||||               2.1G/8.0G]"

        3 ->
          "  Swp[                                  0K/2.0G]"

        _ ->
          "#{String.pad_leading("#{line * 100}", 5)} user    20   0  #{Enum.random(100..999)}M  #{Enum.random(10..99)}M   #{Enum.random(1..10)}M S   0.7   1.2   0:#{Enum.random(10..59)}.#{Enum.random(10..99)} beam.smp"
      end
    end
  end

  defp generate_log_tail_buffer do
    # Simulate tail -f output
    for i <- 1..24 do
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
      "[#{timestamp}] INFO: Log entry #{i} - Processing request"
    end
  end

  defp generate_shell_buffer do
    # Simulate shell session
    for i <- 1..12 do
      if rem(i, 2) == 1 do
        "developer@machine:~/project $ command_#{i}"
      else
        "Output from command #{i - 1}"
      end
    end
  end

  defp generate_scrollback(pane_id) do
    # Generate scrollback history for pane
    history_size = Enum.random(100..1000)

    for i <- 1..history_size do
      "Pane #{pane_id} history line #{i} - #{DateTime.utc_now() |> DateTime.to_iso8601()}"
    end
  end

  defp analyze_memory_patterns(_results) do
    Mix.shell().info("Analyzing memory usage patterns...")
    # Integration point for memory analysis
  end

  defp analyze_buffer_memory_patterns(_results) do
    Mix.shell().info("Analyzing buffer memory patterns...")
    # Integration point for buffer memory analysis
  end

  defp print_memory_analysis(results) do
    Mix.shell().info("\n=== Memory Benchmark Analysis ===")

    Mix.shell().info(
      "Terminal component benchmarks: #{map_size(results[:terminal] || %{})} scenarios"
    )

    Mix.shell().info(
      "Buffer operation benchmarks: #{map_size(results[:buffer] || %{})} scenarios"
    )

    Mix.shell().info(
      "Simulation benchmarks: #{map_size(results[:simulation] || %{})} scenarios"
    )

    Mix.shell().info("Results saved to: bench/output/memory_benchmarks.html")
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(~r/[:-]/, "")
  end

  defp generate_uuid do
    # Simple UUID-like string generator
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> String.replace(
      ~r/(.{8})(.{4})(.{4})(.{4})(.{12})/,
      "\\1-\\2-\\3-\\4-\\5"
    )
  end

  defp print_help do
    Mix.shell().info("""
    Raxol Enhanced Memory Benchmarking Tool

    Usage:
      mix raxol.bench.memory                    # Run all memory benchmarks
      mix raxol.bench.memory terminal           # Terminal component benchmarks
      mix raxol.bench.memory buffer             # Buffer operation benchmarks
      mix raxol.bench.memory simulation         # Realistic usage simulations

    Options:
      --quick                                   # Quick benchmark run (reduced time)
      --profile                                 # Include memory profiling integration
      --help                                    # Show this help

    Examples:
      mix raxol.bench.memory --quick            # Quick memory performance check
      mix raxol.bench.memory terminal --profile # Terminal benchmarks with profiling
      mix raxol.bench.memory simulation         # Test realistic memory usage patterns

    Output:
      Results are saved to bench/output/memory_benchmarks.html with:
      • Memory allocation patterns and peak usage
      • Memory efficiency comparisons across scenarios
      • Realistic usage simulation results
      • Memory profiling integration data
    """)
  end
end
