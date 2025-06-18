defmodule Raxol.Terminal.Driver.ResizeEventTest do
  use ExUnit.Case
  import Mox

  alias Raxol.Terminal.Driver
  alias Raxol.Terminal.DriverTestHelper, as: Helper

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Process.flag(:trap_exit, true)
    Helper.setup_terminal()
  end

  describe "handle_info({:termbox_event, ...}) for resize events" do
    test 'parses and dispatches resize events' do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Test resize event
      Helper.simulate_resize_event(driver_pid, 100, 50)
      Helper.assert_resize_event(100, 50)

      Process.exit(driver_pid, :shutdown)
    end

    test 'handles multiple resize events' do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Send multiple resize events
      Helper.simulate_resize_event(driver_pid, 90, 30)
      Helper.simulate_resize_event(driver_pid, 100, 40)
      Helper.simulate_resize_event(driver_pid, 110, 50)

      # Verify all events were processed
      Helper.assert_resize_event(90, 30)
      Helper.assert_resize_event(100, 40)
      Helper.assert_resize_event(110, 50)

      Process.exit(driver_pid, :shutdown)
    end
  end

  describe "handle_signal(:sigwinch, ...)" do
    test 'sends resize event when SIGWINCH is received' do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Simulate SIGWINCH
      Helper.simulate_sigwinch(driver_pid)

      # Assert that a resize event is dispatched
      Helper.assert_resize_event(90, 30)

      Process.exit(driver_pid, :shutdown)
    end
  end

  @tag :skip
  describe "handle_info({:signal, :SIGWINCH})" do
    test 'sends resize event when SIGWINCH is received' do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Simulate SIGWINCH
      Helper.simulate_sigwinch(driver_pid)

      # Assert that a resize event is dispatched
      Helper.assert_resize_event(90, 30)

      Process.exit(driver_pid, :shutdown)
    end
  end
end
