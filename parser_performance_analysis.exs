#!/usr/bin/env elixir

# Performance analysis script for Phase 1 optimization
# Focus: Profile current parser performance to identify hot paths

defmodule ParserPerformanceAnalysis do
  @moduledoc """
  Phase 1 Performance Analysis for v1.5.0 optimization goals:
  - Target: Parser <2.5μs/sequence (from current 3.2μs)
  - Memory: <2MB per session (from current <2.8MB)
  - Render: <0.5ms (from current <1ms)
  """

  alias Raxol.Terminal.TerminalParser
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ANSI.Parser, as: ANSIParser

  def run do
    IO.puts("=== Phase 1 Parser Performance Analysis ===")
    IO.puts("Target: Reduce parser time from 3.2μs to <2.5μs per sequence\n")

    # Test both parsers
    run_ansi_parser_benchmark()
    run_terminal_parser_benchmark()

    # Analyze memory usage
    analyze_memory_patterns()

    # Identify optimization opportunities
    identify_optimization_targets()
  end

  defp run_ansi_parser_benchmark do
    IO.puts("=== ANSI Parser Benchmark ===")

    test_cases = [
      {"simple_text", "Hello World"},
      {"color_escape", "\e[31mRed Text\e[0m"},
      {"cursor_move", "\e[10;20H"},
      {"clear_screen", "\e[2J"},
      {"complex_csi", "\e[1;31;47mBold Red on White\e[0m"},
      {"osc_sequence", "\e]0;Window Title\e\\"},
      {"mixed_content", "Text \e[31mColor\e[0m More \e[2J End"}
    ]

    Enum.each(test_cases, fn {name, input} ->
      # Warmup
      Enum.each(1..100, fn _ -> ANSIParser.parse(input) end)

      # Benchmark
      {time, _result} = :timer.tc(fn ->
        Enum.each(1..10000, fn _ ->
          ANSIParser.parse(input)
        end)
      end)

      avg_us = time / 10000
      IO.puts("#{String.pad_trailing(name, 20)} => #{Float.round(avg_us, 3)} μs/op")
    end)
  end

  defp run_terminal_parser_benchmark do
    IO.puts("\n=== Terminal Parser Benchmark ===")

    # Create minimal emulator for testing
    emulator = Emulator.new(80, 24)

    test_cases = [
      {"simple_text", "Hello World"},
      {"color_escape", "\e[31mRed Text\e[0m"},
      {"cursor_move", "\e[10;20H"},
      {"clear_screen", "\e[2J"},
      {"scroll_region", "\e[10;20r"},
      {"mode_change", "\e[?25h"}
    ]

    Enum.each(test_cases, fn {name, input} ->
      # Warmup
      Enum.each(1..100, fn _ -> TerminalParser.parse(emulator, input) end)

      # Benchmark
      {time, _result} = :timer.tc(fn ->
        Enum.each(1..1000, fn _ ->
          TerminalParser.parse(emulator, input)
        end)
      end)

      avg_us = time / 1000
      IO.puts("#{String.pad_trailing(name, 20)} => #{Float.round(avg_us, 3)} μs/op")
    end)
  end

  defp analyze_memory_patterns do
    IO.puts("\n=== Memory Usage Analysis ===")

    emulator = Emulator.new(80, 24)

    # Test memory usage with different input sizes
    input_sizes = [100, 1000, 10000]

    Enum.each(input_sizes, fn size ->
      input = String.duplicate("a\e[31mb\e[0mc", div(size, 7))

      :erlang.garbage_collect()
      memory_before = :erlang.memory(:total)

      _result = TerminalParser.parse(emulator, input)

      :erlang.garbage_collect()
      memory_after = :erlang.memory(:total)

      memory_used = memory_after - memory_before
      memory_per_char = memory_used / byte_size(input)

      IO.puts("Input size #{size}: #{memory_used} bytes (#{Float.round(memory_per_char, 2)} bytes/char)")
    end)
  end

  defp identify_optimization_targets do
    IO.puts("\n=== Optimization Targets Identified ===")

    IO.puts("1. String Processing Hot Paths:")
    profile_string_operations()

    IO.puts("\n2. State Machine Transitions:")
    profile_state_transitions()

    IO.puts("\n3. Memory Allocations:")
    profile_memory_allocations()
  end

  defp profile_string_operations do
    # Test different string processing approaches
    test_string = "Hello \e[31mWorld\e[0m Test"

    techniques = %{
      "binary_match" => fn -> binary_match_approach(test_string) end,
      "regex_split" => fn -> regex_split_approach(test_string) end,
      "char_iterate" => fn -> char_iterate_approach(test_string) end
    }

    Enum.each(techniques, fn {name, func} ->
      {time, _} = :timer.tc(fn ->
        Enum.each(1..10000, fn _ -> func.() end)
      end)

      IO.puts("  #{name}: #{Float.round(time/10000, 3)} μs/op")
    end)
  end

  defp binary_match_approach(input) do
    # Current ANSI parser approach
    ANSIParser.parse(input)
  end

  defp regex_split_approach(input) do
    # Alternative: regex-based splitting
    Regex.split(~r/\e\[[0-9;]*[a-zA-Z]/, input, include_captures: true)
  end

  defp char_iterate_approach(input) do
    # Alternative: character-by-character iteration
    input |> String.graphemes() |> Enum.count()
  end

  defp profile_state_transitions do
    emulator = Emulator.new(80, 24)

    transitions = [
      {"ground->escape", "\e"},
      {"escape->csi", "\e[31m"},
      {"ground->text", "Hello"},
      {"csi_complete", "\e[1;1H"}
    ]

    Enum.each(transitions, fn {name, input} ->
      {time, _} = :timer.tc(fn ->
        Enum.each(1..10000, fn _ ->
          TerminalParser.parse(emulator, input)
        end)
      end)

      IO.puts("  #{name}: #{Float.round(time/10000, 3)} μs/op")
    end)
  end

  defp profile_memory_allocations do
    # Test memory-intensive operations
    large_input = String.duplicate("Test \e[31mColor\e[0m ", 1000)

    :erlang.garbage_collect()
    {memory_before, reductions_before} = {:erlang.memory(:total), :erlang.system_info(:reductions)}

    _result = ANSIParser.parse(large_input)

    :erlang.garbage_collect()
    {memory_after, reductions_after} = {:erlang.memory(:total), :erlang.system_info(:reductions)}

    memory_used = memory_after - memory_before
    reductions_used = reductions_after - reductions_before

    IO.puts("  Large input (10k chars): #{memory_used} bytes, #{reductions_used} reductions")
    IO.puts("  Memory efficiency: #{Float.round(memory_used / byte_size(large_input), 2)} bytes/input_byte")
  end
end

# Run the analysis
ParserPerformanceAnalysis.run()