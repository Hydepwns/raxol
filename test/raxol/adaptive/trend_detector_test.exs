defmodule Raxol.Adaptive.TrendDetectorTest do
  use ExUnit.Case, async: true

  alias Raxol.Adaptive.TrendDetector

  defp make_aggregate(dwell_times, opts \\ []) do
    %{
      window_start: Keyword.get(opts, :window_start, 0),
      pane_dwell_times: dwell_times,
      command_frequency: %{},
      avg_alert_response_ms: 0.0,
      most_used_panes: [],
      least_used_panes: [],
      scroll_frequency: Keyword.get(opts, :scroll_frequency, %{}),
      scroll_velocity: %{},
      takeover_duration_ms: %{},
      layout_override_count: 0,
      command_concentration: Keyword.get(opts, :command_concentration, %{})
    }
  end

  describe "compute/1" do
    test "returns empty map with fewer than 2 aggregates" do
      assert TrendDetector.compute([]) == %{}
      assert TrendDetector.compute([make_aggregate(%{a: 1.0})]) == %{}
    end

    test "detects increasing dwell trend" do
      aggregates = [
        make_aggregate(%{scout: 5.0, analyst: 5.0}),
        make_aggregate(%{scout: 4.0, analyst: 6.0}),
        make_aggregate(%{scout: 3.0, analyst: 7.0}),
        make_aggregate(%{scout: 2.0, analyst: 8.0}),
        make_aggregate(%{scout: 1.0, analyst: 9.0})
      ]

      # Newest first (as BehaviorTracker.get_aggregates returns)
      trends = TrendDetector.compute(Enum.reverse(aggregates))

      assert trends.analyst.dwell_trend > 0
      assert trends.scout.dwell_trend < 0
    end

    test "detects flat trend as near-zero slope" do
      aggregates = [
        make_aggregate(%{a: 5.0}),
        make_aggregate(%{a: 5.0}),
        make_aggregate(%{a: 5.0})
      ]

      trends = TrendDetector.compute(Enum.reverse(aggregates))
      assert abs(trends.a.dwell_trend) < 0.001
    end

    test "handles missing panes across windows" do
      aggregates = [
        make_aggregate(%{a: 5.0}),
        make_aggregate(%{a: 3.0, b: 2.0})
      ]

      trends = TrendDetector.compute(Enum.reverse(aggregates))
      assert Map.has_key?(trends, :a)
      assert Map.has_key?(trends, :b)
    end

    test "computes command concentration trends" do
      # Newest first (as get_aggregates returns)
      aggregates = [
        make_aggregate(%{a: 5.0}, command_concentration: %{a: 10}),
        make_aggregate(%{a: 5.0}, command_concentration: %{a: 5}),
        make_aggregate(%{a: 5.0}, command_concentration: %{a: 1})
      ]

      # compute/1 receives newest-first, reverses internally
      # so time order becomes [1, 5, 10] -> positive slope
      trends = TrendDetector.compute(aggregates)
      assert trends.a.command_trend > 0
    end
  end

  describe "rising?/3" do
    test "returns true when dwell trend exceeds threshold" do
      trends = %{
        scout: %{dwell_trend: 0.05, command_trend: 0.0, scroll_trend: 0.0}
      }

      assert TrendDetector.rising?(trends, :scout)
    end

    test "returns false when trend is flat" do
      trends = %{
        scout: %{dwell_trend: 0.0, command_trend: 0.0, scroll_trend: 0.0}
      }

      refute TrendDetector.rising?(trends, :scout)
    end

    test "returns false for unknown pane" do
      refute TrendDetector.rising?(%{}, :unknown)
    end

    test "respects custom min_slope" do
      trends = %{a: %{dwell_trend: 0.05, command_trend: 0.0, scroll_trend: 0.0}}
      assert TrendDetector.rising?(trends, :a, min_slope: 0.01)
      refute TrendDetector.rising?(trends, :a, min_slope: 0.1)
    end
  end

  describe "linear_slope/1" do
    test "returns 0 for empty or single-element lists" do
      assert TrendDetector.linear_slope([]) == 0.0
      assert TrendDetector.linear_slope([5.0]) == 0.0
    end

    test "computes positive slope for increasing values" do
      assert TrendDetector.linear_slope([1.0, 2.0, 3.0, 4.0, 5.0]) == 1.0
    end

    test "computes negative slope for decreasing values" do
      assert TrendDetector.linear_slope([5.0, 4.0, 3.0, 2.0, 1.0]) == -1.0
    end

    test "returns 0 for constant values" do
      assert TrendDetector.linear_slope([3.0, 3.0, 3.0]) == 0.0
    end
  end
end
