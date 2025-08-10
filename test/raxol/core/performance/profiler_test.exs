defmodule Raxol.Core.Performance.ProfilerTest do
  use ExUnit.Case, async: false

  import Raxol.Core.Performance.Profiler
  alias Raxol.Core.Performance.Profiler

  setup do
    {:ok, _pid} = Profiler.start_link()
    Profiler.clear()
    :ok
  end

  describe "profile/3" do
    test "profiles code execution and records metrics" do
      result =
        profile :test_operation, metadata: %{test: true} do
          Process.sleep(10)
          "test result"
        end

      assert result == "test result"

      # Verify metrics were recorded
      report = Profiler.report(operations: [:test_operation])
      assert length(report) == 1

      [operation_stats] = report
      assert operation_stats.operation == :test_operation
      assert operation_stats.call_count == 1
      assert operation_stats.avg_duration > 0
    end

    test "respects sampling rate" do
      # With 0% sampling, should not record
      for _ <- 1..10 do
        profile :sampled_op, sample_rate: 0.0 do
          "not recorded"
        end
      end

      report = Profiler.report(operations: [:sampled_op])
      assert Enum.empty?(report)

      # With 100% sampling, should record all
      for _ <- 1..5 do
        profile :fully_sampled, sample_rate: 1.0 do
          "recorded"
        end
      end

      report = Profiler.report(operations: [:fully_sampled])
      [stats] = report
      assert stats.call_count == 5
    end
  end

  describe "benchmark/3" do
    test "runs multiple iterations and provides statistics" do
      results =
        benchmark(:test_bench, iterations: 50, warmup: 5) do
          # Simple computation
          Enum.sum(1..100)
        end

      assert results.operation == :test_bench
      assert results.min > 0
      assert results.max >= results.min
      assert results.mean > 0
      assert results.median > 0
      assert results.p95 >= results.median
      assert results.p99 >= results.p95
    end
  end

  describe "compare/2" do
    test "compares two implementations" do
      comparison =
        compare(:string_building,
          old: fn ->
            # Intentionally inefficient O(n^2) string building
            Enum.reduce(1..1000, "", fn i, acc -> acc <> "#{i}" end)
          end,
          new: fn ->
            # Efficient O(n) using iolist
            1..1000 |> Enum.map(&"#{&1}") |> IO.iodata_to_binary()
          end
        )

      assert comparison.operation == :string_building
      assert is_map(comparison.old)
      assert is_map(comparison.new)
      assert is_map(comparison.improvement)

      # Just verify the structure, not the actual improvement
      # since performance can vary
      assert is_number(comparison.improvement.time_improvement)
      assert is_number(comparison.improvement.p95_improvement)
    end
  end

  describe "profile_memory/2" do
    test "tracks memory allocation" do
      # Force GC to get clean baseline
      :erlang.garbage_collect()

      result =
        profile_memory(:memory_test) do
          # Allocate some memory
          List.duplicate("test", 10_000)
        end

      assert is_list(result)
      assert length(result) == 10_000

      # Check that memory metrics were recorded
      report = Profiler.report(operations: [:memory_test])
      assert length(report) > 0
    end
  end

  describe "reporting" do
    test "generates text report" do
      # Generate some data
      for i <- 1..3 do
        profile :"op_#{i}" do
          Process.sleep(i)
        end
      end

      report = Profiler.report(format: :text)
      assert is_binary(report)
      assert report =~ "Operation"
      assert report =~ "Calls"
      assert report =~ "Avg Time"
    end

    test "generates JSON report" do
      profile :json_test do
        :ok
      end

      json_report = Profiler.report(format: :json)
      assert {:ok, decoded} = Jason.decode(json_report)
      assert is_list(decoded)
    end
  end

  describe "optimization suggestions" do
    test "suggests optimizations for slow operations" do
      # Create a slow operation
      for _ <- 1..5 do
        profile :slow_operation do
          Process.sleep(150)
        end
      end

      suggestions = Profiler.suggest_optimizations()
      assert is_list(suggestions)
      assert Enum.any?(suggestions, &(&1 =~ "slow"))
    end

    test "suggests optimizations for high memory usage" do
      # Create high memory operation
      profile_memory(:high_memory) do
        # Allocate ~2MB
        List.duplicate(String.duplicate("x", 1000), 2000)
      end

      suggestions = Profiler.suggest_optimizations()
      assert is_list(suggestions)
      # Would check for memory-related suggestions
    end
  end

  describe "hot path identification" do
    test "identifies hot paths (integration test)" do
      # This is more of an integration test
      # In real usage, would analyze actual running code

      # Simulate some function calls
      for _ <- 1..100 do
        profile :hot_function do
          Enum.map(1..10, &(&1 * 2))
        end
      end

      for _ <- 1..10 do
        profile :cold_function do
          Process.sleep(1)
        end
      end

      report = Profiler.report(format: :raw)

      # Hot function should have more calls
      hot_stats = Enum.find(report, &(&1.operation == :hot_function))
      cold_stats = Enum.find(report, &(&1.operation == :cold_function))

      assert hot_stats.call_count > cold_stats.call_count
    end
  end
end
