defmodule Raxol.Core.Utils.TimerManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Utils.TimerManager

  # ── Pure functions ──────────────────────────────────────────────────

  describe "intervals/0" do
    test "returns a map of named interval constants" do
      intervals = TimerManager.intervals()
      assert is_map(intervals)
      assert map_size(intervals) == 10
    end

    test "immediate is 0" do
      assert TimerManager.intervals().immediate == 0
    end

    test "second is 1000" do
      assert TimerManager.intervals().second == 1_000
    end

    test "minute is 60_000" do
      assert TimerManager.intervals().minute == 60_000
    end

    test "hour is 3_600_000" do
      assert TimerManager.intervals().hour == 3_600_000
    end

    test "day is 86_400_000" do
      assert TimerManager.intervals().day == 86_400_000
    end

    test "week is 604_800_000" do
      assert TimerManager.intervals().week == 604_800_000
    end

    test "all values are non-negative integers" do
      for {_name, ms} <- TimerManager.intervals() do
        assert is_integer(ms)
        assert ms >= 0
      end
    end
  end

  describe "exponential_backoff/3" do
    test "attempt 0 returns base_ms" do
      assert TimerManager.exponential_backoff(0, 1_000, 30_000) == 1_000
    end

    test "attempt 1 doubles base_ms" do
      assert TimerManager.exponential_backoff(1, 1_000, 30_000) == 2_000
    end

    test "attempt 2 quadruples base_ms" do
      assert TimerManager.exponential_backoff(2, 1_000, 30_000) == 4_000
    end

    test "attempt 3 octuples base_ms" do
      assert TimerManager.exponential_backoff(3, 1_000, 30_000) == 8_000
    end

    test "caps at max_ms" do
      assert TimerManager.exponential_backoff(10, 1_000, 30_000) == 30_000
    end

    test "returns max_ms when calculated delay exceeds it" do
      # 1000 * 2^5 = 32_000, capped to 30_000
      assert TimerManager.exponential_backoff(5, 1_000, 30_000) == 30_000
    end

    test "works with small base values" do
      assert TimerManager.exponential_backoff(0, 100, 5_000) == 100
      assert TimerManager.exponential_backoff(3, 100, 5_000) == 800
    end

    test "max_ms equal to base returns base for all attempts" do
      assert TimerManager.exponential_backoff(0, 500, 500) == 500
      assert TimerManager.exponential_backoff(5, 500, 500) == 500
    end

    test "returns integer" do
      result = TimerManager.exponential_backoff(3, 1_000, 60_000)
      assert is_integer(result)
    end
  end

  describe "add_jitter/2" do
    test "returns a value near the original interval" do
      interval = 5_000
      result = TimerManager.add_jitter(interval, 0.1)
      # +/- 10% means range is 4500..5500
      assert result >= 4_500
      assert result <= 5_500
    end

    test "returns an integer" do
      assert is_integer(TimerManager.add_jitter(1_000, 0.1))
    end

    test "jitter_factor 0 returns the original interval" do
      assert TimerManager.add_jitter(5_000, 0.0) == 5_000
    end

    test "jitter_factor 1.0 keeps result >= 1" do
      # Full jitter: range is interval +/- interval, so 0..2*interval
      # But clamped to min 1
      result = TimerManager.add_jitter(100, 1.0)
      assert result >= 1
    end

    test "never returns less than 1" do
      # Even with maximum jitter on a small interval
      for _ <- 1..100 do
        result = TimerManager.add_jitter(1, 1.0)
        assert result >= 1
      end
    end

    test "default jitter_factor is 0.1" do
      result = TimerManager.add_jitter(10_000)
      # 10% of 10_000 = 1_000, so range is 9_000..11_000
      assert result >= 9_000
      assert result <= 11_000
    end

    test "statistical spread over many calls" do
      results = for _ <- 1..200, do: TimerManager.add_jitter(10_000, 0.1)
      min_val = Enum.min(results)
      max_val = Enum.max(results)
      # With 200 samples at 10% jitter, we should see some spread
      assert max_val > min_val
    end
  end

  # ── Timer lifecycle ─────────────────────────────────────────────────

  describe "start_interval/2" do
    test "returns {:ok, ref} and sends periodic messages" do
      {:ok, ref} = TimerManager.start_interval(:tick, 10)

      assert_receive :tick, 200
      assert_receive :tick, 200

      :timer.cancel(ref)
    end

    test "sends tuple messages" do
      {:ok, ref} = TimerManager.start_interval({:check, :db}, 10)

      assert_receive {:check, :db}, 200

      :timer.cancel(ref)
    end

    test "rejects non-positive interval" do
      assert_raise FunctionClauseError, fn ->
        TimerManager.start_interval(:tick, 0)
      end

      assert_raise FunctionClauseError, fn ->
        TimerManager.start_interval(:tick, -1)
      end
    end

    test "rejects non-integer interval" do
      assert_raise FunctionClauseError, fn ->
        TimerManager.start_interval(:tick, 1.5)
      end
    end
  end

  describe "send_after/2" do
    test "returns a reference and delivers the message once" do
      ref = TimerManager.send_after(:ping, 10)
      assert is_reference(ref)

      assert_receive :ping, 200
      refute_receive :ping, 50
    end

    test "sends tuple messages" do
      _ref = TimerManager.send_after({:retry, 1}, 10)

      assert_receive {:retry, 1}, 200
    end

    test "delay of 0 delivers immediately" do
      _ref = TimerManager.send_after(:now, 0)

      assert_receive :now, 200
    end

    test "rejects negative delay" do
      assert_raise FunctionClauseError, fn ->
        TimerManager.send_after(:msg, -1)
      end
    end

    test "rejects non-integer delay" do
      assert_raise FunctionClauseError, fn ->
        TimerManager.send_after(:msg, 1.5)
      end
    end
  end

  # ── Cancellation ────────────────────────────────────────────────────

  describe "cancel_timer/1" do
    test "nil returns {:ok, false}" do
      assert TimerManager.cancel_timer(nil) == {:ok, false}
    end

    test "cancels a Process.send_after reference" do
      ref = TimerManager.send_after(:should_not_arrive, 500)
      assert {:ok, true} = TimerManager.cancel_timer(ref)

      refute_receive :should_not_arrive, 100
    end

    test "cancels an interval timer via {:ok, ref} tuple" do
      {:ok, _ref} = timer = TimerManager.start_interval(:interval_msg, 500)
      assert {:ok, true} = TimerManager.cancel_timer(timer)

      refute_receive :interval_msg, 100
    end

    test "returns {:ok, false} for already-cancelled Process timer" do
      ref = TimerManager.send_after(:msg, 500)
      Process.cancel_timer(ref)

      assert {:ok, false} = TimerManager.cancel_timer(ref)
    end
  end

  describe "safe_cancel/1" do
    test "nil returns :ok" do
      assert TimerManager.safe_cancel(nil) == :ok
    end

    test "cancels a Process.send_after reference" do
      ref = TimerManager.send_after(:should_not_arrive, 500)
      assert :ok = TimerManager.safe_cancel(ref)

      refute_receive :should_not_arrive, 100
    end

    test "cancels an interval timer via {:ok, ref} tuple" do
      {:ok, _ref} = timer = TimerManager.start_interval(:interval_msg, 500)
      assert :ok = TimerManager.safe_cancel(timer)

      refute_receive :interval_msg, 100
    end

    test "handles already-cancelled timer gracefully" do
      ref = TimerManager.send_after(:msg, 500)
      Process.cancel_timer(ref)

      assert :ok = TimerManager.safe_cancel(ref)
    end

    test "handles arbitrary non-timer values" do
      assert :ok = TimerManager.safe_cancel(:not_a_timer)
      assert :ok = TimerManager.safe_cancel("string")
      assert :ok = TimerManager.safe_cancel(42)
    end
  end

  # ── Timer map management ────────────────────────────────────────────

  describe "add_timer/3 with :once" do
    test "adds a one-shot timer to the map" do
      timers = TimerManager.add_timer(%{}, :timeout, :once, 10)

      assert Map.has_key?(timers, :timeout)
      assert is_reference(timers[:timeout])
      assert_receive :timeout, 200
    end

    test "replaces existing timer of the same name" do
      timers = TimerManager.add_timer(%{}, :timeout, :once, 500)
      timers = TimerManager.add_timer(timers, :timeout, :once, 10)

      # Only one key
      assert map_size(timers) == 1
      # The old 500ms timer was cancelled, only the 10ms one fires
      assert_receive :timeout, 200
      refute_receive :timeout, 200
    end

    test "preserves other timers in the map" do
      timers =
        %{}
        |> TimerManager.add_timer(:a, :once, 500)
        |> TimerManager.add_timer(:b, :once, 500)

      assert Map.has_key?(timers, :a)
      assert Map.has_key?(timers, :b)

      TimerManager.cancel_all_timers(timers)
    end
  end

  describe "add_timer/3 with :interval" do
    test "adds an interval timer to the map" do
      timers = TimerManager.add_timer(%{}, :heartbeat, :interval, 10)

      assert Map.has_key?(timers, :heartbeat)
      assert_receive :heartbeat, 200

      TimerManager.cancel_all_timers(timers)
    end

    test "replaces existing interval timer" do
      timers = TimerManager.add_timer(%{}, :heartbeat, :interval, 500)
      timers = TimerManager.add_timer(timers, :heartbeat, :interval, 10)

      assert map_size(timers) == 1
      assert_receive :heartbeat, 200

      TimerManager.cancel_all_timers(timers)
    end
  end

  describe "remove_timer/2" do
    test "removes and cancels a timer from the map" do
      timers = TimerManager.add_timer(%{}, :timeout, :once, 500)
      timers = TimerManager.remove_timer(timers, :timeout)

      assert timers == %{}
      refute_receive :timeout, 100
    end

    test "returns map unchanged when name not present" do
      timers = %{other: make_ref()}
      assert timers == TimerManager.remove_timer(timers, :missing)
    end

    test "removes only the specified timer" do
      timers =
        %{}
        |> TimerManager.add_timer(:a, :once, 500)
        |> TimerManager.add_timer(:b, :once, 500)

      timers = TimerManager.remove_timer(timers, :a)

      refute Map.has_key?(timers, :a)
      assert Map.has_key?(timers, :b)

      TimerManager.cancel_all_timers(timers)
    end
  end

  describe "cancel_all_timers/1" do
    test "cancels all timers and returns :ok" do
      timers =
        %{}
        |> TimerManager.add_timer(:a, :once, 500)
        |> TimerManager.add_timer(:b, :once, 500)

      assert :ok = TimerManager.cancel_all_timers(timers)

      refute_receive :a, 100
      refute_receive :b, 100
    end

    test "works on an empty map" do
      assert :ok = TimerManager.cancel_all_timers(%{})
    end

    test "handles interval timers" do
      timers = TimerManager.add_timer(%{}, :tick, :interval, 500)
      assert :ok = TimerManager.cancel_all_timers(timers)

      refute_receive :tick, 100
    end
  end
end
