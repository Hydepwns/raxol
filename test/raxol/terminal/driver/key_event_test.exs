defmodule Raxol.Terminal.Driver.KeyEventTest do
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

  describe "handle_info({:termbox_event, ...}) for key events" do
    test "parses and dispatches regular key events" do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Test regular keys
      Helper.simulate_key_event(driver_pid, ?a)
      Helper.assert_key_event("a")

      Helper.simulate_key_event(driver_pid, ?b)
      Helper.assert_key_event("b")

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches special key events" do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Test arrow keys
      Helper.simulate_key_event(driver_pid, 0, 65) # Up arrow
      Helper.assert_key_event(nil, :up)

      Helper.simulate_key_event(driver_pid, 0, 66) # Down arrow
      Helper.assert_key_event(nil, :down)

      Helper.simulate_key_event(driver_pid, 0, 67) # Right arrow
      Helper.assert_key_event(nil, :right)

      Helper.simulate_key_event(driver_pid, 0, 68) # Left arrow
      Helper.assert_key_event(nil, :left)

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches function key events" do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Test function keys
      Helper.simulate_key_event(driver_pid, 0, 265) # F1
      Helper.assert_key_event(nil, :f1)

      Helper.simulate_key_event(driver_pid, 0, 266) # F2
      Helper.assert_key_event(nil, :f2)

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches modifier key events" do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Test modifier combinations
      Helper.simulate_key_event(driver_pid, 0, 65, 2) # Ctrl+Up
      Helper.assert_key_event(nil, :up, %{ctrl: true})

      Helper.simulate_key_event(driver_pid, 0, 66, 1) # Shift+Down
      Helper.assert_key_event(nil, :down, %{shift: true})

      Process.exit(driver_pid, :shutdown)
    end
  end
end
