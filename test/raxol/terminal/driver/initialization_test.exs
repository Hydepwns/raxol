# Driver test helper is loaded via test_helper.exs

defmodule Raxol.Terminal.Driver.InitializationTest do
  use ExUnit.Case, async: false
  import Mox

  alias Raxol.Terminal.Driver

  # Use the correct test helper from the terminal directory, not the support directory
  alias Raxol.Terminal.DriverTestHelper, as: Helper

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Process.flag(:trap_exit, true)
    Helper.setup_terminal()
  end

  describe "init/1" do
    test ~c"initializes correctly, configures terminal, and sends initial resize event" do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready
      Helper.wait_for_driver_ready(driver_pid)

      # Check if initial resize event was sent
      Helper.assert_resize_event(80, 24)

      # Ensure driver is stopped cleanly
      ref = Process.monitor(driver_pid)
      Process.exit(driver_pid, :shutdown)
      assert_receive {:DOWN, ^ref, :process, _, :shutdown}, 500
    end
  end

  describe "terminate/2" do
    test ~c"restores terminal settings on exit" do
      test_pid = self()
      driver_pid = Helper.start_driver(test_pid)

      # Wait for driver to be ready and consume initial resize
      Helper.wait_for_driver_ready(driver_pid)
      Helper.consume_initial_resize()

      # Monitor the process before exiting it
      ref = Process.monitor(driver_pid)

      # Exit the process
      Process.exit(driver_pid, :shutdown)

      # Verify the process terminated cleanly
      assert_receive {:DOWN, ^ref, :process, _, :shutdown}, 500
    end
  end
end
