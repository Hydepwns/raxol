# Driver test helper is loaded via test_helper.exs

defmodule Raxol.Terminal.Driver.MouseEventTest do
  use ExUnit.Case
  import Mox

  alias Raxol.Terminal.DriverTestHelper, as: Helper

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Process.flag(:trap_exit, true)
    Helper.setup_terminal()
  end

  describe "handle_info({:termbox_event, ...}) for mouse events" do
    test ~c"parses and dispatches mouse button events" do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Test left mouse button
      Helper.simulate_mouse_event(driver_pid, 10, 5, 0)
      Helper.assert_mouse_event(10, 5, :left)

      # Test right mouse button
      Helper.simulate_mouse_event(driver_pid, 15, 8, 1)
      Helper.assert_mouse_event(15, 8, :right)

      # Test middle mouse button
      Helper.simulate_mouse_event(driver_pid, 20, 12, 2)
      Helper.assert_mouse_event(20, 12, :middle)

      Process.exit(driver_pid, :shutdown)
    end

    test ~c"handles mouse events at screen boundaries" do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Test top-left corner
      Helper.simulate_mouse_event(driver_pid, 0, 0, 0)
      Helper.assert_mouse_event(0, 0, :left)

      # Test bottom-right corner (assuming 80x24 terminal)
      Helper.simulate_mouse_event(driver_pid, 79, 23, 0)
      Helper.assert_mouse_event(79, 23, :left)

      Process.exit(driver_pid, :shutdown)
    end

    test ~c"handles rapid mouse events" do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Send multiple mouse events in quick succession
      Helper.simulate_mouse_event(driver_pid, 10, 5, 0)
      Helper.simulate_mouse_event(driver_pid, 11, 5, 0)
      Helper.simulate_mouse_event(driver_pid, 12, 5, 0)

      # Verify all events were processed
      Helper.assert_mouse_event(10, 5, :left)
      Helper.assert_mouse_event(11, 5, :left)
      Helper.assert_mouse_event(12, 5, :left)

      Process.exit(driver_pid, :shutdown)
    end
  end
end
