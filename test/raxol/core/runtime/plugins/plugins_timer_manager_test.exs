defmodule Raxol.Core.Runtime.Plugins.TimerManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.TimerManager

  defp build_state(opts \\ []) do
    %{
      file_event_timer: Keyword.get(opts, :file_event_timer, nil),
      tick_timer: Keyword.get(opts, :tick_timer, nil)
    }
  end

  describe "cancel_existing_timer/1" do
    test "returns state unchanged when timer is nil" do
      state = build_state()
      result = TimerManager.cancel_existing_timer(state)
      assert result.file_event_timer == nil
    end

    test "cancels timer ref and sets to nil" do
      ref = Process.send_after(self(), :test_cancel, 60_000)
      state = build_state(file_event_timer: ref)

      result = TimerManager.cancel_existing_timer(state)
      assert result.file_event_timer == nil
      # Timer should be cancelled
      assert Process.read_timer(ref) == false
    end

    test "does not affect tick_timer" do
      tick_ref = Process.send_after(self(), :tick, 60_000)
      file_ref = Process.send_after(self(), :file, 60_000)
      state = build_state(file_event_timer: file_ref, tick_timer: tick_ref)

      result = TimerManager.cancel_existing_timer(state)
      assert result.file_event_timer == nil
      assert result.tick_timer == tick_ref

      # Cleanup
      Process.cancel_timer(tick_ref)
    end
  end

  describe "cancel_periodic_tick/1" do
    test "returns {:ok, state} when tick_timer is nil" do
      state = build_state()
      assert {:ok, result} = TimerManager.cancel_periodic_tick(state)
      assert result.tick_timer == nil
    end

    test "cancels tick timer and sets to nil" do
      ref = Process.send_after(self(), :tick_cancel, 60_000)
      state = build_state(tick_timer: ref)

      assert {:ok, result} = TimerManager.cancel_periodic_tick(state)
      assert result.tick_timer == nil
      assert Process.read_timer(ref) == false
    end

    test "does not affect file_event_timer" do
      file_ref = Process.send_after(self(), :file, 60_000)
      tick_ref = Process.send_after(self(), :tick, 60_000)
      state = build_state(file_event_timer: file_ref, tick_timer: tick_ref)

      assert {:ok, result} = TimerManager.cancel_periodic_tick(state)
      assert result.tick_timer == nil
      assert result.file_event_timer == file_ref

      # Cleanup
      Process.cancel_timer(file_ref)
    end
  end

  describe "start_periodic_tick/2" do
    test "starts a tick timer with default interval" do
      state = build_state()
      result = TimerManager.start_periodic_tick(state)
      assert is_reference(result.tick_timer)
      remaining = Process.read_timer(result.tick_timer)
      assert is_integer(remaining)
      assert remaining > 0 and remaining <= 5000

      # Cleanup
      Process.cancel_timer(result.tick_timer)
    end

    test "starts a tick timer with custom interval" do
      state = build_state()
      result = TimerManager.start_periodic_tick(state, 10_000)
      assert is_reference(result.tick_timer)
      remaining = Process.read_timer(result.tick_timer)
      assert remaining > 5000 and remaining <= 10_000

      # Cleanup
      Process.cancel_timer(result.tick_timer)
    end

    test "sends :tick message after interval" do
      state = build_state()
      result = TimerManager.start_periodic_tick(state, 10)
      assert is_reference(result.tick_timer)
      assert_receive :tick, 200
    end
  end

  describe "schedule_file_event_timer/4" do
    test "schedules a file event timer with default interval" do
      state = build_state()

      result =
        TimerManager.schedule_file_event_timer(state, :my_plugin, "/some/path")

      assert is_reference(result.file_event_timer)
      remaining = Process.read_timer(result.file_event_timer)
      assert is_integer(remaining)
      assert remaining > 0 and remaining <= 1000

      # Cleanup
      Process.cancel_timer(result.file_event_timer)
    end

    test "schedules with custom interval" do
      state = build_state()
      result = TimerManager.schedule_file_event_timer(state, :p, "/path", 5000)
      assert is_reference(result.file_event_timer)
      remaining = Process.read_timer(result.file_event_timer)
      assert remaining > 1000 and remaining <= 5000

      # Cleanup
      Process.cancel_timer(result.file_event_timer)
    end

    test "cancels existing timer before scheduling new one" do
      old_ref = Process.send_after(self(), :old_timer, 60_000)
      state = build_state(file_event_timer: old_ref)

      result = TimerManager.schedule_file_event_timer(state, :p, "/path")
      # Old timer should be cancelled
      assert Process.read_timer(old_ref) == false
      # New timer should be active
      assert is_reference(result.file_event_timer)
      assert result.file_event_timer != old_ref

      # Cleanup
      Process.cancel_timer(result.file_event_timer)
    end

    test "sends correct message after interval" do
      state = build_state()

      result =
        TimerManager.schedule_file_event_timer(
          state,
          :my_plug,
          "/test/path",
          10
        )

      assert is_reference(result.file_event_timer)

      assert_receive {:reload_plugin_file_debounced, :my_plug, "/test/path"},
                     200
    end

    test "does not affect tick_timer" do
      tick_ref = Process.send_after(self(), :tick, 60_000)
      state = build_state(tick_timer: tick_ref)

      result = TimerManager.schedule_file_event_timer(state, :p, "/path")
      assert result.tick_timer == tick_ref

      # Cleanup
      Process.cancel_timer(tick_ref)
      Process.cancel_timer(result.file_event_timer)
    end
  end
end
