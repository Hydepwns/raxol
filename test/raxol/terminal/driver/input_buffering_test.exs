defmodule Raxol.Terminal.Driver.InputBufferingTest do
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

  describe "Input Buffering" do
    test 'correctly requests more input if buffer is empty' do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Send a key event
      Helper.simulate_key_event(driver_pid, ?x)
      Helper.assert_key_event("x")

      Process.exit(driver_pid, :shutdown)
    end

    test 'correctly buffers partial input sequences' do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Send partial escape sequence
      Helper.simulate_key_event(driver_pid, ?\e)
      Helper.assert_key_event("\e")

      Helper.simulate_key_event(driver_pid, ?[)
      Helper.assert_key_event("[")

      Helper.simulate_key_event(driver_pid, ?A)
      Helper.assert_key_event("A")

      Process.exit(driver_pid, :shutdown)
    end

    test 'handles intermingled input correctly' do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Send mixed input sequence: "x\e[Ay"
      Helper.simulate_key_event(driver_pid, ?x)
      Helper.assert_key_event("x")

      Helper.simulate_key_event(driver_pid, ?\e)
      Helper.assert_key_event("\e")

      Helper.simulate_key_event(driver_pid, ?[)
      Helper.assert_key_event("[")

      # Up arrow
      Helper.simulate_key_event(driver_pid, 0, 65)
      Helper.assert_key_event(nil, :up)

      Helper.simulate_key_event(driver_pid, ?y)
      Helper.assert_key_event("y")

      Process.exit(driver_pid, :shutdown)
    end

    test 'handles rapid input sequences' do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Send multiple key events in quick succession
      Helper.simulate_key_event(driver_pid, ?a)
      Helper.simulate_key_event(driver_pid, ?b)
      Helper.simulate_key_event(driver_pid, ?c)

      # Verify all events were processed in order
      Helper.assert_key_event("a")
      Helper.assert_key_event("b")
      Helper.assert_key_event("c")

      Process.exit(driver_pid, :shutdown)
    end
  end
end
