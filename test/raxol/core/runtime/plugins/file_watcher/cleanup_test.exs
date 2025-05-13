defmodule Raxol.Core.Runtime.Plugins.FileWatcher.CleanupTest do
  use ExUnit.Case
  import Mox
  alias Raxol.Core.Runtime.Plugins.FileWatcher.Cleanup
  alias FileWatcherTestHelper, as: Helper

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Setup test environment
  setup do
    pid = Helper.setup_mocks()
    Helper.cleanup_test_plugins()

    on_exit(fn ->
      Helper.stop_manager(pid)
      Helper.cleanup_test_plugins()
    end)

    :ok
  end

  describe "cleanup_file_watching/1" do
    test "stops file watcher process and cancels timer" do
      # Setup test state with watcher PID and timer
      watcher_pid = spawn(fn -> :timer.sleep(1_000_000) end)
      timer = Process.send_after(self(), :test, 1_000_000)
      state = Helper.create_test_state()
      state = put_in(state.file_watcher_pid, watcher_pid)
      state = put_in(state.file_event_timer, timer)
      state = put_in(state.file_watching_enabled?, true)

      # Call the function
      new_state = Cleanup.cleanup_file_watching(state)

      # Verify watcher process is stopped
      refute Process.alive?(watcher_pid)

      # Verify timer is cancelled
      refute Process.cancel_timer(timer)

      # Verify state is updated
      assert new_state.file_watcher_pid == nil
      assert new_state.file_event_timer == nil
      assert new_state.file_watching_enabled? == false
    end

    test "handles cleanup when no watcher PID exists" do
      # Setup test state with only timer
      timer = Process.send_after(self(), :test, 1_000_000)
      state = Helper.create_test_state()
      state = put_in(state.file_event_timer, timer)
      state = put_in(state.file_watching_enabled?, true)

      # Call the function
      new_state = Cleanup.cleanup_file_watching(state)

      # Verify timer is cancelled
      refute Process.cancel_timer(timer)

      # Verify state is updated
      assert new_state.file_watcher_pid == nil
      assert new_state.file_event_timer == nil
      assert new_state.file_watching_enabled? == false
    end

    test "handles cleanup when no timer exists" do
      # Setup test state with only watcher PID
      watcher_pid = spawn(fn -> :timer.sleep(1_000_000) end)
      state = Helper.create_test_state()
      state = put_in(state.file_watcher_pid, watcher_pid)
      state = put_in(state.file_watching_enabled?, true)

      # Call the function
      new_state = Cleanup.cleanup_file_watching(state)

      # Verify watcher process is stopped
      refute Process.alive?(watcher_pid)

      # Verify state is updated
      assert new_state.file_watcher_pid == nil
      assert new_state.file_event_timer == nil
      assert new_state.file_watching_enabled? == false
    end

    test "handles cleanup when no resources exist" do
      # Setup test state with no resources
      state = Helper.create_test_state()
      state = put_in(state.file_watching_enabled?, true)

      # Call the function
      new_state = Cleanup.cleanup_file_watching(state)

      # Verify state is updated
      assert new_state.file_watcher_pid == nil
      assert new_state.file_event_timer == nil
      assert new_state.file_watching_enabled? == false
    end

    test "is idempotent - can be called multiple times" do
      # Setup test state
      state = Helper.create_test_state()
      state = put_in(state.file_watching_enabled?, true)

      # Call the function multiple times
      new_state1 = Cleanup.cleanup_file_watching(state)
      new_state2 = Cleanup.cleanup_file_watching(new_state1)
      new_state3 = Cleanup.cleanup_file_watching(new_state2)

      # Verify all states are the same
      assert new_state1 == new_state2
      assert new_state2 == new_state3
    end
  end
end
