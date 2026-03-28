defmodule Raxol.Core.Utils.TimerUtilsTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Utils.TimerUtils

  # -- start_periodic/3 ------------------------------------------------------

  describe "start_periodic/3" do
    test "returns a reference" do
      ref = TimerUtils.start_periodic(self(), :tick, 10)
      assert is_reference(ref)
      Process.cancel_timer(ref)
    end

    test "delivers the message after the interval" do
      _ref = TimerUtils.start_periodic(self(), :tick, 10)
      assert_receive :tick, 200
    end

    test "delivers tuple messages" do
      _ref = TimerUtils.start_periodic(self(), {:check, :db}, 10)
      assert_receive {:check, :db}, 200
    end

    test "rejects non-pid first argument" do
      assert_raise FunctionClauseError, fn ->
        TimerUtils.start_periodic(:not_a_pid, :tick, 10)
      end
    end

    test "rejects zero interval" do
      assert_raise FunctionClauseError, fn ->
        TimerUtils.start_periodic(self(), :tick, 0)
      end
    end

    test "rejects negative interval" do
      assert_raise FunctionClauseError, fn ->
        TimerUtils.start_periodic(self(), :tick, -1)
      end
    end
  end

  # -- start_delayed/3 -------------------------------------------------------

  describe "start_delayed/3" do
    test "returns a reference" do
      ref = TimerUtils.start_delayed(self(), :cleanup, 10)
      assert is_reference(ref)
      Process.cancel_timer(ref)
    end

    test "delivers the message after the delay" do
      _ref = TimerUtils.start_delayed(self(), :cleanup, 10)
      assert_receive :cleanup, 200
    end

    test "delivers only once" do
      _ref = TimerUtils.start_delayed(self(), :once, 10)
      assert_receive :once, 200
      refute_receive :once, 50
    end

    test "delivers tuple messages" do
      _ref = TimerUtils.start_delayed(self(), {:flush, :buffer}, 10)
      assert_receive {:flush, :buffer}, 200
    end

    test "rejects non-pid first argument" do
      assert_raise FunctionClauseError, fn ->
        TimerUtils.start_delayed(:not_a_pid, :msg, 10)
      end
    end

    test "rejects zero delay" do
      assert_raise FunctionClauseError, fn ->
        TimerUtils.start_delayed(self(), :msg, 0)
      end
    end

    test "rejects negative delay" do
      assert_raise FunctionClauseError, fn ->
        TimerUtils.start_delayed(self(), :msg, -1)
      end
    end
  end

  # -- cancel_timer/1 --------------------------------------------------------

  describe "cancel_timer/1" do
    test "nil returns :ok" do
      assert TimerUtils.cancel_timer(nil) == :ok
    end

    test "cancels a valid timer reference" do
      ref = TimerUtils.start_delayed(self(), :should_not_arrive, 500)
      assert :ok = TimerUtils.cancel_timer(ref)
      refute_receive :should_not_arrive, 50
    end

    test "returns :ok for an already-expired timer" do
      ref = TimerUtils.start_delayed(self(), :fast, 10)
      assert_receive :fast, 200
      assert :ok = TimerUtils.cancel_timer(ref)
    end

    test "returns :ok for an already-cancelled timer" do
      ref = TimerUtils.start_delayed(self(), :msg, 500)
      Process.cancel_timer(ref)
      assert :ok = TimerUtils.cancel_timer(ref)
    end

    test "returns :ok for non-reference invalid input" do
      assert :ok = TimerUtils.cancel_timer(:not_a_ref)
      assert :ok = TimerUtils.cancel_timer("string")
      assert :ok = TimerUtils.cancel_timer(42)
    end
  end

  # -- restart_timer/4 -------------------------------------------------------

  describe "restart_timer/4" do
    test "cancels old timer and starts new one" do
      old_ref = TimerUtils.start_delayed(self(), :old_msg, 500)
      new_ref = TimerUtils.restart_timer(old_ref, self(), :new_msg, 10)

      assert is_reference(new_ref)
      refute_receive :old_msg, 50
      assert_receive :new_msg, 200
    end

    test "works when old timer is nil" do
      ref = TimerUtils.restart_timer(nil, self(), :fresh, 10)
      assert is_reference(ref)
      assert_receive :fresh, 200
    end

    test "old message does not arrive after restart" do
      old_ref = TimerUtils.start_delayed(self(), :stale, 20)
      _new_ref = TimerUtils.restart_timer(old_ref, self(), :current, 30)

      refute_receive :stale, 100
      assert_receive :current, 200
    end
  end

  # -- debounce_timer/5 ------------------------------------------------------

  describe "debounce_timer/5" do
    test "adds timer ref to state.timers under the given key" do
      state = %{timers: %{}}
      new_state = TimerUtils.debounce_timer(state, :reload, self(), :reload_file, 50)

      assert is_map(new_state.timers)
      assert is_reference(new_state.timers[:reload])
    end

    test "creates timers map if missing from state" do
      state = %{other: :data}
      new_state = TimerUtils.debounce_timer(state, :reload, self(), :reload_file, 50)

      assert is_reference(new_state.timers[:reload])
      assert new_state.other == :data
    end

    test "cancels existing timer for the same key" do
      state = %{timers: %{}}
      state = TimerUtils.debounce_timer(state, :reload, self(), :old, 500)
      old_ref = state.timers[:reload]

      state = TimerUtils.debounce_timer(state, :reload, self(), :new, 10)
      new_ref = state.timers[:reload]

      refute old_ref == new_ref
      # Old timer should have been cancelled
      assert Process.cancel_timer(old_ref) == false
      assert_receive :new, 200
    end

    test "only the last debounced message arrives" do
      state = %{timers: %{}}
      state = TimerUtils.debounce_timer(state, :save, self(), :save_v1, 10)
      state = TimerUtils.debounce_timer(state, :save, self(), :save_v2, 10)
      _state = TimerUtils.debounce_timer(state, :save, self(), :save_v3, 10)

      assert_receive :save_v3, 200
      refute_receive :save_v1, 50
      refute_receive :save_v2, 50
    end

    test "independent keys do not interfere" do
      state = %{timers: %{}}
      state = TimerUtils.debounce_timer(state, :save, self(), :save_msg, 10)
      state = TimerUtils.debounce_timer(state, :sync, self(), :sync_msg, 10)

      assert Map.has_key?(state.timers, :save)
      assert Map.has_key?(state.timers, :sync)

      assert_receive :save_msg, 200
      assert_receive :sync_msg, 200
    end

    test "preserves other state fields" do
      state = %{timers: %{}, name: "test", count: 42}
      new_state = TimerUtils.debounce_timer(state, :k, self(), :msg, 50)

      assert new_state.name == "test"
      assert new_state.count == 42
    end
  end

  # -- cancel_all_timers/1 ---------------------------------------------------

  describe "cancel_all_timers/1" do
    test "cancels all timers in the timers map" do
      ref_a = TimerUtils.start_delayed(self(), :a, 500)
      ref_b = TimerUtils.start_delayed(self(), :b, 500)
      state = %{timers: %{a: ref_a, b: ref_b}}

      assert :ok = TimerUtils.cancel_all_timers(state)

      refute_receive :a, 50
      refute_receive :b, 50
    end

    test "returns :ok for empty timers map" do
      assert :ok = TimerUtils.cancel_all_timers(%{timers: %{}})
    end

    test "returns :ok when state has no timers key" do
      assert :ok = TimerUtils.cancel_all_timers(%{})
    end

    test "returns :ok for non-map state" do
      assert :ok = TimerUtils.cancel_all_timers(:anything)
    end

    test "handles nil timer values gracefully" do
      state = %{timers: %{a: nil, b: nil}}
      assert :ok = TimerUtils.cancel_all_timers(state)
    end
  end

  # -- intervals/0 -----------------------------------------------------------

  describe "intervals/0" do
    test "returns a map" do
      intervals = TimerUtils.intervals()
      assert is_map(intervals)
    end

    test "contains expected keys" do
      intervals = TimerUtils.intervals()

      expected_keys = [
        :performance_sample,
        :health_check,
        :optimization,
        :cleanup,
        :flush,
        :render_tick,
        :animation_frame,
        :file_debounce,
        :file_reload,
        :connection_timeout,
        :retry_delay
      ]

      for key <- expected_keys do
        assert Map.has_key?(intervals, key), "missing key: #{key}"
      end
    end

    test "all values are positive integers" do
      for {name, ms} <- TimerUtils.intervals() do
        assert is_integer(ms), "#{name} should be integer, got: #{inspect(ms)}"
        assert ms > 0, "#{name} should be positive, got: #{ms}"
      end
    end

    test "render_tick is 16ms (~60fps)" do
      assert TimerUtils.intervals().render_tick == 16
    end

    test "health_check is 30 seconds" do
      assert TimerUtils.intervals().health_check == 30_000
    end
  end

  # -- get_interval/1 --------------------------------------------------------

  describe "get_interval/1" do
    test "returns known interval by name" do
      assert TimerUtils.get_interval(:health_check) == 30_000
      assert TimerUtils.get_interval(:flush) == 1_000
      assert TimerUtils.get_interval(:render_tick) == 16
    end

    test "returns 5000 default for unknown name" do
      assert TimerUtils.get_interval(:nonexistent) == 5_000
    end

    test "returns 5000 default for nil" do
      assert TimerUtils.get_interval(nil) == 5_000
    end
  end

  # -- start_periodic_with_state/5 -------------------------------------------

  describe "start_periodic_with_state/5" do
    test "stores timer ref in state.timers under the given key" do
      state = %{timers: %{}}

      new_state =
        TimerUtils.start_periodic_with_state(
          state,
          :health_timer,
          self(),
          :perform_health_check,
          :render_tick
        )

      assert is_reference(new_state.timers[:health_timer])
    end

    test "creates timers map if missing from state" do
      state = %{name: "test"}

      new_state =
        TimerUtils.start_periodic_with_state(
          state,
          :my_timer,
          self(),
          :my_message,
          :render_tick
        )

      assert is_reference(new_state.timers[:my_timer])
      assert new_state.name == "test"
    end

    test "uses the interval from get_interval for the named interval" do
      state = %{timers: %{}}

      # render_tick is 16ms, so message should arrive quickly
      new_state =
        TimerUtils.start_periodic_with_state(
          state,
          :tick_timer,
          self(),
          :render_tick_msg,
          :render_tick
        )

      assert_receive :render_tick_msg, 200
      Process.cancel_timer(new_state.timers[:tick_timer])
    end

    test "delivers the specified message" do
      state = %{timers: %{}}

      new_state =
        TimerUtils.start_periodic_with_state(
          state,
          :check,
          self(),
          {:health, :ping},
          :render_tick
        )

      assert_receive {:health, :ping}, 200
      Process.cancel_timer(new_state.timers[:check])
    end

    test "preserves existing timers in state" do
      existing_ref = make_ref()
      state = %{timers: %{existing: existing_ref}}

      new_state =
        TimerUtils.start_periodic_with_state(
          state,
          :new_timer,
          self(),
          :msg,
          :render_tick
        )

      assert new_state.timers[:existing] == existing_ref
      assert is_reference(new_state.timers[:new_timer])
      Process.cancel_timer(new_state.timers[:new_timer])
    end
  end
end
