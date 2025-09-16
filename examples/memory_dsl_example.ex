defmodule Raxol.Examples.MemoryDSLExample do
  @moduledoc """
  Example demonstrating the enhanced Memory DSL with assertions.

  This module showcases how to use the Memory DSL for comprehensive
  memory testing with specific assertions and thresholds.

  Usage:
    iex> Raxol.Examples.MemoryDSLExample.run_memory_benchmarks()
  """

  use Raxol.Benchmark.MemoryDSL

  # =============================================================================
  # Memory Benchmark Definition
  # =============================================================================

  memory_benchmark "Terminal Operations Memory Test" do
    # Configure memory benchmark behavior
    memory_config(
      time: 2,
      memory_time: 1,
      warmup: 0.5,
      # 15% regression threshold
      regression_threshold: 0.15
    )

    # Define memory test scenarios
    scenario("small_terminal", fn ->
      create_small_terminal_buffer()
    end)

    scenario("large_terminal", fn ->
      create_large_terminal_buffer()
    end)

    scenario("buffer_operations", fn ->
      perform_buffer_operations()
    end)

    scenario("ansi_processing", fn ->
      process_ansi_sequences()
    end)

    scenario("memory_stress_test", fn ->
      perform_memory_stress_test()
    end)

    # Memory Assertions - Phase 3 Enhanced DSL Features

    # Peak memory usage assertions
    # 5MB
    assert_memory_peak(:small_terminal, less_than: 5_000_000)
    # 150MB
    assert_memory_peak(:large_terminal, less_than: 150_000_000)
    # 50MB
    assert_memory_peak(:buffer_operations, less_than: 50_000_000)
    # 10MB
    assert_memory_peak(:ansi_processing, less_than: 10_000_000)
    # 200MB
    assert_memory_peak(:memory_stress_test, less_than: 200_000_000)

    # Sustained memory usage assertions (75th percentile)
    # 3MB
    assert_memory_sustained(:small_terminal, less_than: 3_000_000)
    # 100MB
    assert_memory_sustained(:large_terminal, less_than: 100_000_000)
    # 30MB
    assert_memory_sustained(:buffer_operations, less_than: 30_000_000)
    # 8MB
    assert_memory_sustained(:ansi_processing, less_than: 8_000_000)

    # Garbage collection pressure assertions
    # Max 5 GC collections
    assert_gc_pressure(:small_terminal, less_than: 5)
    # Max 20 GC collections
    assert_gc_pressure(:large_terminal, less_than: 20)
    # Max 15 GC collections
    assert_gc_pressure(:buffer_operations, less_than: 15)
    # Max 50 GC collections
    assert_gc_pressure(:memory_stress_test, less_than: 50)

    # Memory efficiency assertions (higher is better)
    # 80% efficiency
    assert_memory_efficiency(:small_terminal, greater_than: 0.8)
    # 60% efficiency
    assert_memory_efficiency(:large_terminal, greater_than: 0.6)
    # 70% efficiency
    assert_memory_efficiency(:buffer_operations, greater_than: 0.7)
    # 90% efficiency
    assert_memory_efficiency(:ansi_processing, greater_than: 0.9)

    # Memory regression detection compared to baseline
    # 10% regression tolerance
    assert_no_memory_regression(baseline: "v1.4.0", threshold: 0.1)
  end

  # =============================================================================
  # Scenario Implementations
  # =============================================================================

  defp create_small_terminal_buffer do
    # Create a standard 80x24 terminal buffer
    for row <- 1..24 do
      for col <- 1..80 do
        %{
          char: random_char(),
          fg: random_color(),
          bg: :black,
          style: %{
            bold: :rand.uniform() > 0.8,
            italic: :rand.uniform() > 0.9,
            underline: :rand.uniform() > 0.95
          }
        }
      end
    end
  end

  defp create_large_terminal_buffer do
    # Create a large 1000x1000 terminal buffer
    for row <- 1..1000 do
      for col <- 1..1000 do
        %{
          char: random_char(),
          fg: random_color(),
          bg: random_bg_color(),
          style: %{
            bold: :rand.uniform() > 0.7,
            italic: :rand.uniform() > 0.8,
            underline: :rand.uniform() > 0.9
          }
        }
      end
    end
  end

  defp perform_buffer_operations do
    # Create buffer and perform various operations
    buffer = create_small_terminal_buffer()

    # Simulate buffer modifications
    updated_buffer =
      Enum.map(buffer, fn row ->
        Enum.map(row, fn cell ->
          if :rand.uniform() > 0.5 do
            %{cell | char: "X", fg: :red}
          else
            cell
          end
        end)
      end)

    # Simulate scrolling operations
    scrolled_buffer =
      case updated_buffer do
        [] ->
          []

        [_first | rest] ->
          empty_row =
            for _col <- 1..80 do
              %{char: " ", fg: :white, bg: :black, style: %{}}
            end

          rest ++ [empty_row]
      end

    # Simulate copy operations
    copied_sections =
      for _i <- 1..10 do
        section_start = :rand.uniform(20)
        section_end = section_start + 3
        Enum.slice(scrolled_buffer, section_start..section_end)
      end

    {scrolled_buffer, copied_sections}
  end

  defp process_ansi_sequences do
    # Process various ANSI escape sequences
    sequences = [
      # Clear screen
      "\e[2J",
      # Cursor to home
      "\e[1;1H",
      # Red colored text
      "\e[31mRed text\e[0m",
      # Bold text
      "\e[1mBold text\e[0m",
      # Underlined text
      "\e[4mUnderlined\e[0m",
      # Inverted colors
      "\e[7mInverted\e[0m",
      # Enable alternative buffer
      "\e[?1049h",
      # Disable alternative buffer
      "\e[?1049l",
      # 256-color mode
      "\e[38;5;196mBright red\e[0m",
      # 256-color background
      "\e[48;5;21mBlue bg\e[0m",
      # True color mode
      "\e[38;2;255;128;0mRGB\e[0m"
    ]

    # Process each sequence multiple times
    processed =
      for sequence <- sequences do
        for _iteration <- 1..100 do
          parse_ansi_sequence(sequence)
        end
      end

    # Create result buffer showing processed sequences
    result_buffer =
      for {sequence, index} <- Enum.with_index(sequences) do
        %{
          sequence: sequence,
          processed_count: 100,
          result: Enum.at(processed, index),
          memory_impact: byte_size(sequence) * 100
        }
      end

    result_buffer
  end

  defp perform_memory_stress_test do
    # Create memory pressure scenario
    large_data_chunks =
      for chunk_id <- 1..1000 do
        chunk_data =
          for _byte <- 1..1024 do
            :rand.uniform(255)
          end

        %{
          id: chunk_id,
          data: chunk_data,
          metadata: %{
            created_at: System.system_time(:microsecond),
            size: length(chunk_data),
            checksum: Enum.sum(chunk_data)
          }
        }
      end

    # Perform operations that should trigger garbage collection
    processed_chunks =
      large_data_chunks
      |> Enum.chunk_every(100)
      |> Enum.map(fn chunk_group ->
        # Process each group
        processed =
          Enum.map(chunk_group, fn chunk ->
            # Transform data to trigger allocations
            doubled_data = Enum.map(chunk.data, &(&1 * 2))
            %{chunk | data: doubled_data}
          end)

        # Calculate group statistics
        total_size = Enum.sum_by(processed, fn chunk -> length(chunk.data) end)

        avg_checksum =
          Enum.sum_by(processed, fn chunk -> chunk.metadata.checksum end) /
            length(processed)

        %{
          group_size: total_size,
          avg_checksum: avg_checksum,
          chunks: processed
        }
      end)

    # Return summary to avoid keeping all data in memory
    %{
      total_groups: length(processed_chunks),
      total_memory_processed: Enum.sum_by(processed_chunks, & &1.group_size),
      avg_group_size:
        Enum.sum_by(processed_chunks, & &1.group_size) /
          length(processed_chunks)
    }
  end

  # =============================================================================
  # Helper Functions
  # =============================================================================

  defp random_char do
    chars =
      ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+ "

    Enum.random(chars)
  end

  defp random_color do
    colors = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]
    Enum.random(colors)
  end

  defp random_bg_color do
    if :rand.uniform() > 0.8 do
      random_color()
    else
      :black
    end
  end

  defp parse_ansi_sequence(sequence) do
    # Simple ANSI sequence parser simulation
    cond do
      String.contains?(sequence, "[2J") ->
        {:clear_screen, byte_size(sequence)}

      String.contains?(sequence, "[1;1H") ->
        {:cursor_home, byte_size(sequence)}

      String.contains?(sequence, "m") ->
        {:color_command, extract_color_info(sequence), byte_size(sequence)}

      String.contains?(sequence, "?1049") ->
        if String.contains?(sequence, "h") do
          {:alt_buffer_enable, byte_size(sequence)}
        else
          {:alt_buffer_disable, byte_size(sequence)}
        end

      true ->
        {:unknown_sequence, sequence, byte_size(sequence)}
    end
  end

  defp extract_color_info(sequence) do
    cond do
      String.contains?(sequence, "31m") ->
        {:fg_color, :red}

      String.contains?(sequence, "32m") ->
        {:fg_color, :green}

      String.contains?(sequence, "38;5;") ->
        {:fg_color_256, extract_256_color(sequence)}

      String.contains?(sequence, "38;2;") ->
        {:fg_color_rgb, extract_rgb_color(sequence)}

      String.contains?(sequence, "48;5;") ->
        {:bg_color_256, extract_256_color(sequence)}

      String.contains?(sequence, "48;2;") ->
        {:bg_color_rgb, extract_rgb_color(sequence)}

      String.contains?(sequence, "1m") ->
        {:style, :bold}

      String.contains?(sequence, "4m") ->
        {:style, :underline}

      String.contains?(sequence, "7m") ->
        {:style, :reverse}

      String.contains?(sequence, "0m") ->
        {:reset, :all}

      true ->
        {:unknown_color, sequence}
    end
  end

  defp extract_256_color(sequence) do
    # Extract 256-color value (simplified)
    case Regex.run(~r/38;5;(\d+)/, sequence) do
      [_, color_str] -> String.to_integer(color_str)
      _ -> 0
    end
  end

  defp extract_rgb_color(sequence) do
    # Extract RGB color values (simplified)
    case Regex.run(~r/38;2;(\d+);(\d+);(\d+)/, sequence) do
      [_, r_str, g_str, b_str] ->
        {String.to_integer(r_str), String.to_integer(g_str),
         String.to_integer(b_str)}

      _ ->
        {0, 0, 0}
    end
  end

  # =============================================================================
  # Public API
  # =============================================================================

  @doc """
  Run the memory benchmark example with assertions.

  Returns a detailed report including assertion results and recommendations.
  """
  def run_example do
    IO.puts("Running Memory DSL Example...")
    IO.puts("This demonstrates Phase 3 advanced memory analysis capabilities.")
    IO.puts("")

    case run_memory_benchmarks() do
      {:ok, report} ->
        print_example_report(report)
        {:ok, report}

      {:error, error} ->
        IO.puts("Error running memory benchmarks: #{inspect(error)}")
        {:error, error}
    end
  end

  defp print_example_report(report) do
    IO.puts("=== Memory DSL Example Report ===")
    IO.puts("")

    # Print summary
    summary = report.summary
    IO.puts("Summary:")
    IO.puts("  Total scenarios: #{summary.total_scenarios}")
    IO.puts("  Total assertions: #{summary.total_assertions}")
    IO.puts("  Passing assertions: #{summary.passing_assertions}")
    IO.puts("  Failing assertions: #{summary.failing_assertions}")
    IO.puts("  Success rate: #{Float.round(summary.success_rate * 100, 1)}%")
    IO.puts("")

    # Print assertion results
    IO.puts("Assertion Results:")

    for {{assertion_type, scenario}, result} <- report.assertion_results do
      status =
        case result do
          {:ok, _} -> "PASS"
          {:error, _} -> "FAIL"
        end

      message =
        case result do
          {:ok, msg} -> msg
          {:error, msg} -> msg
        end

      IO.puts("  [#{status}] #{assertion_type} (#{scenario}): #{message}")
    end

    IO.puts("")

    # Print memory analysis
    analysis = report.memory_analysis
    IO.puts("Memory Analysis:")
    IO.puts("  Peak memory: #{format_bytes(analysis.peak_memory)}")
    IO.puts("  Sustained memory: #{format_bytes(analysis.sustained_memory)}")
    IO.puts("  GC collections: #{analysis.gc_collections}")

    IO.puts(
      "  Fragmentation ratio: #{Float.round(analysis.fragmentation_ratio, 3)}"
    )

    IO.puts("  Efficiency score: #{Float.round(analysis.efficiency_score, 3)}")
    IO.puts("  Regression detected: #{analysis.regression_detected}")
    IO.puts("")

    # Print recommendations
    if length(report.recommendations) > 0 do
      IO.puts("Optimization Recommendations:")

      for {recommendation, index} <- Enum.with_index(report.recommendations, 1) do
        IO.puts("  #{index}. #{recommendation}")
      end
    else
      IO.puts("Optimization Recommendations: None - memory usage is optimal!")
    end
  end

  defp format_bytes(bytes) when bytes >= 1_000_000_000 do
    "#{Float.round(bytes / 1_000_000_000, 2)} GB"
  end

  defp format_bytes(bytes) when bytes >= 1_000_000 do
    "#{Float.round(bytes / 1_000_000, 2)} MB"
  end

  defp format_bytes(bytes) when bytes >= 1_000 do
    "#{Float.round(bytes / 1_000, 2)} KB"
  end

  defp format_bytes(bytes) do
    "#{bytes} B"
  end
end
