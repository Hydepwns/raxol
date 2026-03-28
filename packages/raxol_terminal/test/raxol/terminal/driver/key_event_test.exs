defmodule Raxol.Terminal.Driver.KeyEventTest do
  use ExUnit.Case
  import Mox

  alias Raxol.Terminal.DriverTestHelper, as: Helper

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Process.flag(:trap_exit, true)
    Helper.setup_terminal()
  end

  describe "handle_info({:termbox_event, ...}) for key events" do
    test ~c"parses and dispatches regular key events" do
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

    test ~c"parses and dispatches special key events" do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Test arrow keys
      # Up arrow
      Helper.simulate_key_event(driver_pid, 0, 65)
      Helper.assert_key_event(nil, :up)

      # Down arrow
      Helper.simulate_key_event(driver_pid, 0, 66)
      Helper.assert_key_event(nil, :down)

      # Right arrow
      Helper.simulate_key_event(driver_pid, 0, 67)
      Helper.assert_key_event(nil, :right)

      # Left arrow
      Helper.simulate_key_event(driver_pid, 0, 68)
      Helper.assert_key_event(nil, :left)

      Process.exit(driver_pid, :shutdown)
    end

    test ~c"parses and dispatches function key events" do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Test function keys
      # F1
      Helper.simulate_key_event(driver_pid, 0, 265)
      Helper.assert_key_event(nil, :f1)

      # F2
      Helper.simulate_key_event(driver_pid, 0, 266)
      Helper.assert_key_event(nil, :f2)

      Process.exit(driver_pid, :shutdown)
    end

    test ~c"parses and dispatches modifier key events" do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Test modifier combinations
      # Ctrl+Up
      Helper.simulate_key_event(driver_pid, 0, 65, 2)
      Helper.assert_key_event(nil, :up, %{ctrl: true})

      # Shift+Down
      Helper.simulate_key_event(driver_pid, 0, 66, 1)
      Helper.assert_key_event(nil, :down, %{shift: true})

      Process.exit(driver_pid, :shutdown)
    end
  end
end
