#!/usr/bin/env elixir

# Load Memory Benchmark
# Tests memory usage patterns under load and stress conditions
# NOTE: Run with `mix run bench/memory/load_memory_benchmark.exs`

defmodule LoadMemoryBenchmark do
  @moduledoc """
  Memory benchmarks for load testing scenarios.

  This benchmark suite tests memory usage patterns for:
  - High-concurrency operations
  - Long-running sessions
  - Multi-user scenarios
  - Stress testing conditions
  - Memory stability over time
  """

  alias Raxol.Terminal.{Buffer, ANSI.AnsiParser}
  alias Raxol.Core.Runtime.{PluginManager, EventSystem}

  def run_benchmarks(opts \\ []) do
    config =
      [
        time: 5,
        memory_time: 3,
        warmup: 1,
        formatters: [
          Benchee.Formatters.HTML,
          Benchee.Formatters.Console,
          {Benchee.Formatters.JSON, file: "bench/output/load_memory.json"}
        ]
      ]
      |> Keyword.merge(opts)

    IO.puts("Running Load Memory Benchmarks...")
    IO.puts("Config: #{inspect(config)}")

    Benchee.run(
      %{
        "concurrent_buffers" => fn -> concurrent_buffer_operations() end,
        "high_frequency_updates" => fn -> high_frequency_update_operations() end,
        "multi_session_simulation" => fn -> multi_session_simulation() end,
        "stress_ansi_processing" => fn -> stress_ansi_processing() end,
        "memory_pressure_test" => fn -> memory_pressure_test() end,
        "long_running_simulation" => fn -> long_running_simulation() end,
        "concurrent_plugin_operations" => fn ->
          concurrent_plugin_operations()
        end,
        "memory_leak_detection" => fn -> memory_leak_detection_scenario() end
      },
      config
    )
  end

  # Test concurrent buffer operations
  defp concurrent_buffer_operations do
    # Create multiple buffers concurrently
    tasks =
      Enum.map(1..10, fn i ->
        Task.async(fn ->
          {:ok, buffer} = Buffer.create(100, 30)

          # Perform operations on each buffer
          updated_buffer =
            Enum.reduce(1..20, buffer, fn row, acc_buffer ->
              content =
                "Concurrent buffer #{i} - Row #{row}: #{String.duplicate("data ", 10)}"

              case Buffer.write_at(acc_buffer, 0, rem(row - 1, 30), content) do
                {:ok, new_buffer} -> new_buffer
                _ -> acc_buffer
              end
            end)

          # Render the buffer
          Buffer.render(updated_buffer)
          updated_buffer
        end)
      end)

    # Wait for all tasks to complete
    results = Task.await_many(tasks, 10_000)
    results
  end

  # Test high-frequency update operations
  defp high_frequency_update_operations do
    {:ok, buffer} = Buffer.create(80, 24)

    # Simulate rapid updates (like streaming logs)
    Enum.reduce(1..100, buffer, fn update_num, acc_buffer ->
      row = rem(update_num, 24)

      content =
        "Update #{update_num}: #{:crypto.strong_rand_bytes(40) |> Base.encode64()}"

      case Buffer.write_at(acc_buffer, 0, row, content) do
        {:ok, new_buffer} -> new_buffer
        _ -> acc_buffer
      end
    end)
  end

  # Test multi-session simulation
  defp multi_session_simulation do
    # Simulate multiple terminal sessions
    sessions =
      Enum.map(1..5, fn session_id ->
        Task.async(fn ->
          simulate_session(session_id)
        end)
      end)

    # Wait for all sessions to complete
    results = Task.await_many(sessions, 15_000)
    results
  end

  # Simulate a single terminal session
  defp simulate_session(session_id) do
    {:ok, buffer} = Buffer.create(120, 40)

    # Simulate various terminal operations
    operations = [
      # Text writing
      fn buf ->
        write_text_to_buffer(
          buf,
          "Session #{session_id}: Starting operations..."
        )
      end,
      # ANSI processing
      fn buf -> process_ansi_sequences(buf, session_id) end,
      # Screen updates
      fn buf -> update_screen_content(buf, session_id) end,
      # Buffer clearing and rewriting
      fn buf -> clear_and_rewrite_buffer(buf, session_id) end
    ]

    # Execute operations multiple times
    final_buffer =
      Enum.reduce(1..10, buffer, fn _iteration, acc_buffer ->
        Enum.reduce(operations, acc_buffer, fn operation, buf ->
          operation.(buf)
        end)
      end)

    {session_id, final_buffer}
  end

  # Helper function to write text to buffer
  defp write_text_to_buffer(buffer, text) do
    case Buffer.write_at(buffer, 0, 0, text) do
      {:ok, new_buffer} -> new_buffer
      _ -> buffer
    end
  end

  # Helper function to process ANSI sequences
  defp process_ansi_sequences(buffer, session_id) do
    sequences = [
      "\e[31mRed text for session #{session_id}\e[0m",
      "\e[1;32mBold green for session #{session_id}\e[0m",
      "\e[4;34mUnderlined blue for session #{session_id}\e[0m"
    ]

    _parsed = Enum.map(sequences, &AnsiParser.parse/1)
    buffer
  end

  # Helper function to update screen content
  defp update_screen_content(buffer, session_id) do
    Enum.reduce(1..10, buffer, fn line, acc_buffer ->
      content =
        "Session #{session_id} - Line #{line}: #{String.duplicate("update ", 8)}"

      case Buffer.write_at(acc_buffer, 0, line - 1, content) do
        {:ok, new_buffer} -> new_buffer
        _ -> acc_buffer
      end
    end)
  end

  # Helper function to clear and rewrite buffer
  defp clear_and_rewrite_buffer(buffer, session_id) do
    # Clear buffer (simulate screen clear)
    {:ok, cleared_buffer} = Buffer.clear(buffer)

    # Rewrite with new content
    Enum.reduce(1..5, cleared_buffer, fn line, acc_buffer ->
      content = "Rewritten Session #{session_id} - Line #{line}"

      case Buffer.write_at(acc_buffer, 0, line - 1, content) do
        {:ok, new_buffer} -> new_buffer
        _ -> acc_buffer
      end
    end)
  end

  # Test stress ANSI processing
  defp stress_ansi_processing do
    # Generate complex ANSI sequences
    complex_sequences =
      Enum.map(1..200, fn i ->
        color_code = rem(i, 8) + 30
        style_code = rem(i, 4) + 1

        "\e[#{style_code};#{color_code}mComplex sequence #{i} with lots of styling\e[0m"
      end)

    # Process all sequences
    parsed_results = Enum.map(complex_sequences, &AnsiParser.parse/1)

    # Create multiple buffers and write parsed content
    buffers =
      Enum.map(1..5, fn _i ->
        {:ok, buffer} = Buffer.create(100, 50)
        buffer
      end)

    # Write parsed sequences to buffers
    Enum.zip(buffers, Enum.chunk_every(parsed_results, 40))
    |> Enum.map(fn {buffer, sequences} ->
      Enum.reduce(Enum.with_index(sequences), buffer, fn {_seq, index},
                                                         acc_buffer ->
        row = rem(index, 50)
        content = "Parsed sequence #{index}"

        case Buffer.write_at(acc_buffer, 0, row, content) do
          {:ok, new_buffer} -> new_buffer
          _ -> acc_buffer
        end
      end)
    end)
  end

  # Test memory pressure conditions
  defp memory_pressure_test do
    # Create many large data structures
    large_buffers =
      Enum.map(1..10, fn i ->
        {:ok, buffer} = Buffer.create(200, 100)

        # Fill with data
        filled_buffer =
          Enum.reduce(0..99, buffer, fn row, acc_buffer ->
            content = String.duplicate("Memory pressure test #{i} - ", 10)

            case Buffer.write_at(acc_buffer, 0, row, content) do
              {:ok, new_buffer} -> new_buffer
              _ -> acc_buffer
            end
          end)

        filled_buffer
      end)

    # Create large binary data
    large_binaries =
      Enum.map(1..5, fn _i ->
        # 100KB each
        :crypto.strong_rand_bytes(100_000)
      end)

    # Process data
    processed_buffers =
      Enum.map(large_buffers, fn buffer ->
        # Simulate processing
        _rendered = Buffer.render(buffer)
        buffer
      end)

    {processed_buffers, large_binaries}
  end

  # Test long-running simulation
  defp long_running_simulation do
    {:ok, buffer} = Buffer.create(80, 24)

    # Simulate a long-running process with periodic updates
    Enum.reduce(1..50, buffer, fn iteration, acc_buffer ->
      # Simulate time passing
      Process.sleep(10)

      # Update buffer with current iteration info
      content = "Long-running iteration #{iteration} - #{DateTime.utc_now()}"
      row = rem(iteration, 24)

      case Buffer.write_at(acc_buffer, 0, row, content) do
        {:ok, new_buffer} -> new_buffer
        _ -> acc_buffer
      end
    end)
  end

  # Test concurrent plugin operations
  defp concurrent_plugin_operations do
    {:ok, _manager} = PluginManager.start_link([])

    # Create multiple plugins concurrently
    plugin_tasks =
      Enum.map(1..5, fn i ->
        Task.async(fn ->
          plugin_config = %{
            name: "load_test_plugin_#{i}",
            version: "1.0.0",
            module: String.to_atom("LoadTestPlugin#{i}"),
            config: %{id: i}
          }

          {:ok, plugin} = PluginManager.load_plugin(plugin_config)
          PluginManager.start_plugin(plugin)

          # Simulate plugin operations
          Enum.each(1..20, fn op_num ->
            # Simulate work
            _result = :crypto.hash(:md5, "operation_#{i}_#{op_num}")
          end)

          PluginManager.stop_plugin(plugin)
          PluginManager.unload_plugin(plugin)

          plugin
        end)
      end)

    # Wait for all plugin operations to complete
    results = Task.await_many(plugin_tasks, 10_000)
    results
  end

  # Test memory leak detection scenario
  defp memory_leak_detection_scenario do
    # This scenario is designed to detect potential memory leaks
    initial_memory = :erlang.memory(:total)

    # Perform operations that should clean up after themselves
    Enum.each(1..20, fn iteration ->
      # Create and destroy buffers
      {:ok, buffer} = Buffer.create(50, 20)

      _filled =
        Enum.reduce(1..10, buffer, fn row, acc ->
          case Buffer.write_at(
                 acc,
                 0,
                 rem(row, 20),
                 "Iteration #{iteration} Row #{row}"
               ) do
            {:ok, new_buffer} -> new_buffer
            _ -> acc
          end
        end)

      # Process ANSI sequences
      sequences =
        Enum.map(1..5, fn i ->
          "\e[3#{rem(i, 8)}mIteration #{iteration} Sequence #{i}\e[0m"
        end)

      _parsed = Enum.map(sequences, &AnsiParser.parse/1)

      # Trigger garbage collection periodically
      if rem(iteration, 5) == 0 do
        :erlang.garbage_collect()
      end
    end)

    final_memory = :erlang.memory(:total)
    memory_difference = final_memory - initial_memory

    %{
      initial_memory: initial_memory,
      final_memory: final_memory,
      memory_difference: memory_difference,
      iterations: 20
    }
  end
end

# Parse command line arguments
{opts, _args, _invalid} =
  OptionParser.parse(System.argv(),
    switches: [
      json: :boolean,
      time: :integer,
      memory_time: :integer,
      warmup: :integer
    ]
  )

# Configure benchmark options
benchmark_opts = []

if opts[:json] do
  benchmark_opts =
    Keyword.put(benchmark_opts, :formatters, [
      {Benchee.Formatters.JSON, file: "/dev/stdout"}
    ])
end

if opts[:time] do
  benchmark_opts = Keyword.put(benchmark_opts, :time, opts[:time])
end

if opts[:memory_time] do
  benchmark_opts = Keyword.put(benchmark_opts, :memory_time, opts[:memory_time])
end

if opts[:warmup] do
  benchmark_opts = Keyword.put(benchmark_opts, :warmup, opts[:warmup])
end

# Ensure output directory exists
File.mkdir_p("bench/output")

# Run the benchmarks
try do
  LoadMemoryBenchmark.run_benchmarks(benchmark_opts)
rescue
  error ->
    IO.puts("Error running load memory benchmarks: #{inspect(error)}")
    System.halt(1)
end
