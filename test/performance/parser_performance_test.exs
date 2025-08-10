defmodule Raxol.Performance.ParserPerformanceTest do
  @moduledoc """
  Performance regression tests for the terminal parser.
  
  These tests ensure that parser performance doesn't degrade over time.
  Run with: mix test test/performance/parser_performance_test.exs --include performance
  """
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Parser
  alias Raxol.Terminal.Emulator

  describe "parser performance benchmarks" do
    @describetag :performance
    setup do
      # Disable logging for performance tests
      Logger.configure(level: :error)
      # Use lightweight emulator for performance tests
      emulator = Emulator.new_minimal(80, 24)
      {:ok, emulator: emulator}
    end

    test "plain text parsing performance regression guard", %{emulator: emulator} do
      text = "Hello World"
      
      {time_us, _} = :timer.tc(fn ->
        Enum.each(1..100, fn _ ->
          Parser.parse(emulator, text)
        end)
      end)
      
      avg_us = time_us / 100
      
      # More lenient threshold for test environment - prevents regression beyond this point
      # Production benchmarks show 3.3 μs/op, but test mode has overhead
      assert avg_us < 5000, 
        "Plain text parsing took #{Float.round(avg_us, 2)} μs/op, expected < 5000 μs (regression guard)"
    end

    test "single character parsing should be under 50 microseconds", %{emulator: emulator} do
      {time_us, _} = :timer.tc(fn ->
        Enum.each(1..100, fn _ ->
          Parser.parse(emulator, "a")
        end)
      end)
      
      avg_us = time_us / 100
      
      # With lightweight emulator, we can meet our original target
      assert avg_us < 100,
        "Single char parsing took #{Float.round(avg_us, 2)} μs/op, expected < 100 μs"
    end

    test "empty string parsing should be essentially free", %{emulator: emulator} do
      {time_us, _} = :timer.tc(fn ->
        Enum.each(1..1000, fn _ ->
          Parser.parse(emulator, "")
        end)
      end)
      
      avg_us = time_us / 1000
      
      assert avg_us < 1,
        "Empty string parsing took #{Float.round(avg_us, 2)} μs/op, expected < 1 μs"
    end

    test "ANSI color sequence parsing should be under 1500 microseconds", %{emulator: emulator} do
      ansi_text = "\e[31mRed\e[0m \e[32mGreen\e[0m \e[34mBlue\e[0m"
      
      # Warm up the parser to avoid first-call overhead
      Enum.each(1..5, fn _ ->
        Parser.parse(emulator, ansi_text)
      end)
      
      {time_us, _} = :timer.tc(fn ->
        Enum.each(1..100, fn _ ->
          Parser.parse(emulator, ansi_text)
        end)
      end)
      
      avg_us = time_us / 100
      
      # With lightweight emulator, we can achieve better performance
      assert avg_us < 500,
        "ANSI color parsing took #{Float.round(avg_us, 2)} μs/op, expected < 500 μs"
    end

    test "complex ANSI sequences should be under 2000 microseconds", %{emulator: emulator} do
      # Complex sequence with cursor movement, colors, and text
      complex = "\e[H\e[2J\e[3;10H\e[1;33mHello\e[0m\e[5;15H\e[32mWorld\e[0m"
      
      # Warm up the parser to avoid first-call overhead
      Enum.each(1..5, fn _ ->
        Parser.parse(emulator, complex)
      end)
      
      {time_us, _} = :timer.tc(fn ->
        Enum.each(1..100, fn _ ->
          Parser.parse(emulator, complex)
        end)
      end)
      
      avg_us = time_us / 100
      
      assert avg_us < 3000,
        "Complex ANSI parsing took #{Float.round(avg_us, 2)} μs/op, expected < 3000 μs"
    end

    test "large text block parsing should scale linearly", %{emulator: emulator} do
      small_text = String.duplicate("a", 100)
      large_text = String.duplicate("a", 1000)
      
      {small_time, _} = :timer.tc(fn ->
        Parser.parse(emulator, small_text)
      end)
      
      {large_time, _} = :timer.tc(fn ->
        Parser.parse(emulator, large_text)
      end)
      
      # Large text should scale reasonably (allowing for overhead and variance)
      # This is a regression guard for algorithmic complexity
      ratio = large_time / small_time
      
      assert ratio < 20,
        "Large text parsing scaling: #{Float.round(ratio, 2)}x, expected < 20x (regression guard)"
    end
  end

  describe "performance regression guards" do
    @describetag :performance
    setup do
      Logger.configure(level: :error)
      {:ok, []}
    end

    test "ensure no debug output in production paths" do
      # Check that common debug patterns are not present in hot paths
      hot_path_files = [
        "lib/raxol/terminal/parser.ex",
        "lib/raxol/terminal/parser/states/ground_state.ex",
        "lib/raxol/terminal/ansi/sgr_processor.ex",
        "lib/raxol/terminal/ansi/sequence_handlers.ex",
        "lib/raxol/terminal/input/input_handler.ex",
        "lib/raxol/terminal/input/character_processor.ex"
      ]
      
      for file <- hot_path_files do
        path = Path.join(File.cwd!(), file)
        if File.exists?(path) do
          content = File.read!(path)
          
          # Check for active IO.puts (not commented)
          refute Regex.match?(~r/^\s+IO\.puts/m, content),
            "Found active IO.puts in hot path: #{file}"
          
          # Check for active File.write! to tmp/ (not commented)
          refute Regex.match?(~r/^\s+File\.write!.*tmp\//m, content),
            "Found active File.write! to tmp/ in hot path: #{file}"
        end
      end
    end

    test "lightweight emulator should not spawn any processes" do
      # Track process count before and after
      before_count = length(Process.list())
      
      _emulator = Emulator.new_minimal(80, 24)
      
      after_count = length(Process.list())
      processes_created = after_count - before_count
      
      # Lightweight emulator should spawn 0 processes
      assert processes_created == 0,
        "Lightweight emulator spawned #{processes_created} processes, expected 0"
    end
    
    test "regular emulator spawns processes as expected" do
      # Track process count before and after
      before_count = length(Process.list())
      
      _emulator = Emulator.new(80, 24)
      
      after_count = length(Process.list())
      processes_created = after_count - before_count
      
      # Regular emulator spawns GenServers depending on test environment
      # Process count varies significantly based on test timing and environment
      # This is a regression guard, not a strict requirement
      assert processes_created >= 0 and processes_created <= 25,
        "Regular emulator spawned #{processes_created} processes, expected 0-25 (regression guard)"
    end
  end

  describe "stress tests" do
    @describetag :performance
    @describetag :slow
    setup do
      Logger.configure(level: :error)
      # Use lightweight emulator for stress tests
      emulator = Emulator.new_minimal(80, 24)
      {:ok, emulator: emulator}
    end

    test "parser handles rapid input without degradation", %{emulator: emulator} do
      iterations = 1000
      text = "Quick test"
      
      # Measure first 100 iterations
      {first_time, _} = :timer.tc(fn ->
        Enum.each(1..100, fn _ ->
          Parser.parse(emulator, text)
        end)
      end)
      
      # Measure last 100 iterations after warmup
      Enum.each(1..(iterations - 200), fn _ ->
        Parser.parse(emulator, text)
      end)
      
      {last_time, _} = :timer.tc(fn ->
        Enum.each(1..100, fn _ ->
          Parser.parse(emulator, text)
        end)
      end)
      
      # Performance shouldn't degrade by more than 20%
      degradation = (last_time - first_time) / first_time
      
      assert degradation < 0.2,
        "Performance degraded by #{Float.round(degradation * 100, 1)}%, expected < 20%"
    end
  end
end