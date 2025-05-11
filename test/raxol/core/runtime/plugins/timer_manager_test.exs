defmodule Raxol.Core.Runtime.Plugins.TimerManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.TimerManager

  describe "cancel_existing_timer/1" do
    test "returns state unchanged when no timer exists" do
      state = %{file_event_timer: nil}
      assert TimerManager.cancel_existing_timer(state) == state
    end

    test "cancels existing timer and returns updated state" do
      # Create a timer that will never fire
      timer_ref = Process.send_after(self(), :test_message, 1000000)
      state = %{file_event_timer: timer_ref}

      # Cancel the timer
      new_state = TimerManager.cancel_existing_timer(state)

      # Verify timer was cancelled
      assert new_state.file_event_timer == nil
      refute Process.cancel_timer(timer_ref)
    end
  end

  describe "schedule_timer/3" do
    test "schedules a new timer and returns updated state" do
      state = %{file_event_timer: nil}
      message = :test_message
      timeout = 100

      new_state = TimerManager.schedule_timer(state, message, timeout)

      # Verify timer was scheduled
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "cancels existing timer before scheduling new one" do
      # Create an initial timer
      initial_timer = Process.send_after(self(), :initial_message, 1000000)
      state = %{file_event_timer: initial_timer}

      # Schedule new timer
      new_state = TimerManager.schedule_timer(state, :new_message, 100)

      # Verify old timer was cancelled
      refute Process.cancel_timer(initial_timer)
      # Verify new timer was scheduled
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "handles timer message delivery" do
      state = %{file_event_timer: nil}
      message = :test_message
      timeout = 50

      new_state = TimerManager.schedule_timer(state, message, timeout)

      # Wait for timer to fire
      assert_receive :test_message, 100
      # Verify timer reference was cleared
      assert new_state.file_event_timer != nil
    end
  end
end
