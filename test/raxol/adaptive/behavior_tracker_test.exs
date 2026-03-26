defmodule Raxol.Adaptive.BehaviorTrackerTest do
  use ExUnit.Case, async: true

  alias Raxol.Adaptive.BehaviorTracker

  describe "recording events" do
    test "records events and retrieves them" do
      {:ok, pid} = BehaviorTracker.start_link(name: nil)

      BehaviorTracker.record(pid, :pane_focus, %{pane_id: :scout})
      BehaviorTracker.record(pid, :command_issued, %{command: "status"})

      # Give casts time to process
      Process.sleep(10)

      events = BehaviorTracker.get_recent_events(pid, 10)
      assert length(events) == 2
      assert Enum.any?(events, fn e -> e.type == :pane_focus end)
      assert Enum.any?(events, fn e -> e.type == :command_issued end)
    end

    test "ignores events when disabled" do
      {:ok, pid} = BehaviorTracker.start_link(name: nil)

      BehaviorTracker.disable(pid)
      BehaviorTracker.record(pid, :pane_focus, %{pane_id: :scout})

      Process.sleep(10)

      events = BehaviorTracker.get_recent_events(pid, 10)
      assert events == []
    end

    test "resumes recording after enable" do
      {:ok, pid} = BehaviorTracker.start_link(name: nil)

      BehaviorTracker.disable(pid)
      BehaviorTracker.enable(pid)
      BehaviorTracker.record(pid, :pane_focus, %{pane_id: :scout})

      Process.sleep(10)

      events = BehaviorTracker.get_recent_events(pid, 10)
      assert length(events) == 1
    end
  end

  describe "aggregation" do
    test "computes aggregate and notifies subscribers" do
      # Large window so timer never fires during setup; we trigger manually
      {:ok, pid} =
        BehaviorTracker.start_link(name: nil, window_size_ms: 60_000)

      BehaviorTracker.subscribe(pid)

      BehaviorTracker.record(pid, :pane_dwell, %{
        pane_id: :scout,
        dwell_ms: 5000
      })

      BehaviorTracker.record(pid, :pane_dwell, %{
        pane_id: :analyst,
        dwell_ms: 2000
      })

      BehaviorTracker.record(pid, :command_issued, %{command: "status"})
      BehaviorTracker.record(pid, :command_issued, %{command: "status"})
      BehaviorTracker.record(pid, :command_issued, %{command: "deploy"})

      # Sync barrier: call ensures all prior casts are processed
      _ = BehaviorTracker.get_recent_events(pid, 1)

      # Manually trigger aggregation
      send(pid, :aggregate_window)

      assert_receive {:behavior_aggregate, aggregate}, 500

      assert is_map(aggregate.pane_dwell_times)
      assert aggregate.pane_dwell_times[:scout] == 5.0
      assert aggregate.pane_dwell_times[:analyst] == 2.0
      assert aggregate.command_frequency["status"] == 2
      assert aggregate.command_frequency["deploy"] == 1
    end

    test "computes alert response average" do
      {:ok, pid} =
        BehaviorTracker.start_link(name: nil, window_size_ms: 60_000)

      BehaviorTracker.subscribe(pid)

      BehaviorTracker.record(pid, :alert_response, %{response_ms: 3000})
      BehaviorTracker.record(pid, :alert_response, %{response_ms: 7000})

      _ = BehaviorTracker.get_recent_events(pid, 1)
      send(pid, :aggregate_window)

      assert_receive {:behavior_aggregate, aggregate}, 500

      assert_in_delta aggregate.avg_alert_response_ms, 5000.0, 0.1
    end

    test "get_aggregates returns stored aggregates" do
      {:ok, pid} =
        BehaviorTracker.start_link(name: nil, window_size_ms: 60_000)

      BehaviorTracker.record(pid, :pane_dwell, %{pane_id: :x, dwell_ms: 100})

      # Sync barrier + manual trigger
      _ = BehaviorTracker.get_recent_events(pid, 1)
      send(pid, :aggregate_window)
      # Sync barrier to ensure aggregate is stored
      Process.sleep(10)

      aggregates = BehaviorTracker.get_aggregates(pid, 5)
      assert [_ | _] = aggregates
    end
  end

  describe "subscriber management" do
    test "removes dead subscribers" do
      {:ok, pid} = BehaviorTracker.start_link(name: nil)

      task = Task.async(fn -> BehaviorTracker.subscribe(pid) end)
      Task.await(task)

      # Subscriber process is dead now, should be cleaned up
      Process.sleep(20)

      # Should not crash when aggregating
      BehaviorTracker.record(pid, :pane_focus, %{pane_id: :test})
    end
  end
end
