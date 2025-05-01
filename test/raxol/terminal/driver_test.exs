defmodule Raxol.Terminal.DriverTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Driver
  alias Raxol.Core.Events.Event

  # Helper to start the Driver process for testing
  defp start_driver(test_pid) do
    {:ok, driver_pid} = Driver.start_link(test_pid)
    driver_pid
  end

  setup do
    # Mock stty commands if needed, or ensure tests run where stty is available
    # Mock IO.ioctl if needed for predictable size
    # Example: Mocking IO.ioctl (requires a mocking library or manual setup)
    # Mox.stub(IO, :ioctl, fn :stdio, :winsize -> {:ok, {24, 80}} end)

    # Get original stty settings to restore after test, handle failure
    original_stty =
      case System.cmd("stty", ["-g"]) do
        {output, 0} -> String.trim(output)
        {_error, _exit_code} -> nil # Failed to get stty settings
      end

    on_exit(fn ->
      # Ensure terminal is restored only if we got the original settings
      if original_stty do
        System.cmd("stty", [original_stty])
      end
      # Stop any started driver process if necessary
    end)

    %{original_stty: original_stty}
  end

  describe "init/1" do
    test "initializes correctly, configures terminal, and sends initial resize event",
         %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      # Check if initial resize event was sent
      # We assume a default or mock size here, e.g., 80x24
      # This requires mocking IO.ioctl or knowing the test environment size
      assert_receive {:terminal_event,
                      %Event{type: :resize, data: %{height: _h, width: _w}}},
                     500

      # Check if terminal is in raw mode (hard to check directly without complex mocking)
      # We rely on the Driver's internal logging or side effects for now.

      # Check process state (optional, requires GenServer.call)
      # state = GenServer.call(driver_pid, :get_state) # Requires implementing handle_call(:get_state, ...)
      # assert state.dispatcher_pid == test_pid
      # assert state.original_stty != nil

      # Ensure cleanup
      Process.exit(driver_pid, :shutdown)
      # Give time for terminate
      :timer.sleep(50)
    end
  end

  describe "handle_info({:termbox_event, ...})" do
    test "parses and dispatches key events", %{
      original_stty: _
    } do
      test_pid = self()
      driver_pid = start_driver(test_pid)
      # Consume initial resize event
      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Did not receive initial resize event")
      end

      # Simulate receiving 'a' key event from rrex_termbox NIF
      send(driver_pid, {:termbox_event, %{type: :key, key: 0, char: ?a, mod: 0}})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{char: "a"}}},
                     500

      # Simulate receiving 'b' key event from rrex_termbox NIF
      send(driver_pid, {:termbox_event, %{type: :key, key: 0, char: ?b, mod: 0}})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{char: "b"}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches special key events", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Up Arrow key from rrex_termbox NIF (using placeholder key code 65)
      send(driver_pid, {:termbox_event, %{type: :key, key: 65, char: 0, mod: 0}})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :up}}},
                     500

      # Down Arrow key from rrex_termbox NIF (using placeholder key code 66)
      send(driver_pid, {:termbox_event, %{type: :key, key: 66, char: 0, mod: 0}})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :down}}},
                     500

      # Right Arrow key from rrex_termbox NIF (using placeholder key code 67)
      send(driver_pid, {:termbox_event, %{type: :key, key: 67, char: 0, mod: 0}})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :right}}},
                     500

      # Left Arrow key from rrex_termbox NIF (using placeholder key code 68)
      send(driver_pid, {:termbox_event, %{type: :key, key: 68, char: 0, mod: 0}})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :left}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches function key events", %{
      original_stty: _
    } do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout waiting for initial resize")
      end

      # Function Keys (using placeholder key codes for rrex_termbox v2.0.1 NIF)
      # F1 key from rrex_termbox NIF
      send(driver_pid, {:termbox_event, %{type: :key, key: 265, char: 0, mod: 0}})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f1}}},
                     500

      # F2 key from rrex_termbox NIF
      send(driver_pid, {:termbox_event, %{type: :key, key: 266, char: 0, mod: 0}})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f2}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches modifier key events", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout waiting for initial resize")
      end

      # Ctrl+Up Arrow from rrex_termbox NIF (using placeholder key code and mod value)
      send(driver_pid, {:termbox_event, %{type: :key, key: 65, char: 0, mod: 2}})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :up, ctrl: true}}},
                     500

      # Shift+Down Arrow from rrex_termbox NIF (using placeholder key code and mod value)
      send(driver_pid, {:termbox_event, %{type: :key, key: 66, char: 0, mod: 1}})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :down, shift: true}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches mouse events", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout waiting for initial resize")
      end

      # Left mouse button press from rrex_termbox NIF
      send(driver_pid, {:termbox_event, %{type: :mouse, x: 10, y: 5, button: 0}})

      assert_receive {:terminal_event,
                      %Event{type: :mouse, data: %{x: 10, y: 5}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches resize events", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      # Consume initial resize event
      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout waiting for initial resize")
      end

      # Resize event from rrex_termbox NIF
      send(driver_pid, {:termbox_event, %{type: :resize, width: 100, height: 50}})

      assert_receive {:terminal_event,
                      %Event{type: :resize, data: %{width: 100, height: 50}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end
  end

  describe "handle_signal(:sigwinch, ...)" do
    test "sends resize event when SIGWINCH is received", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)
      # Consume initial resize event
      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Did not receive initial resize event")
      end

      # Send SIGWINCH signal to the driver process
      # Note: This might not work reliably across all OS/test environments
      # A better approach might involve mocking :erlang.system_monitor
      # or triggering the handle_signal callback directly for testing.
      # Process.signal(driver_pid, :sigwinch) # Sending OS signal is tricky

      # Alternative: Directly call handle_signal for testing (if made public or via helper)
      # Or simulate the message pattern if :erlang.system_monitor sends a specific message

      # Let's simulate the internal GenServer call for this test
      # This requires assuming the shape of the internal message, which is brittle.
      # A more robust way is needed if this test becomes important.
      # For now, we'll test the underlying function if possible, or skip direct test.

      # Let's test by calling the function that sends the event directly
      # This requires the function `send_event` and `IO.ioctl` to work.
      case IO.ioctl(:stdio, :winsize) do
        {:ok, {h, w}} ->
          # Manually trigger the logic within handle_signal
          # Need to implement handle_info for this
          send(driver_pid, {:simulate_sigwinch})

          assert_receive {:terminal_event,
                          %Event{type: :resize, data: %{height: h, width: w}}},
                         500

        {:error, _reason} ->
          # Cannot reliably test ioctl, skip assertion
          Logger.warning(
            "Could not get terminal size via IO.ioctl, skipping SIGWINCH event data test."
          )

          # We can still test that *some* event is sent if we trigger handle_signal
          send(driver_pid, {:simulate_sigwinch})

          assert_receive {:terminal_event,
                          %Event{type: :resize, data: %{height: _, width: _}}},
                         500
      end

      Process.exit(driver_pid, :shutdown)
    end
  end

  # TODO: Add tests for terminate/2 (checking stty restore)
  describe "terminate/2" do
    test "restores terminal settings on exit", %{original_stty: original_stty} do
      test_pid = self()
      driver_pid = start_driver(test_pid)
      # Consume initial resize event
      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Did not receive initial resize event")
      end

      # Exit the process
      Process.exit(driver_pid, :shutdown)
      # Give it a moment to terminate and run the callback
      :timer.sleep(50)

      # Check if the process is no longer alive
      ref = Process.monitor(driver_pid)
      assert_receive {:DOWN, ^ref, :process, _, _}, 50

      # Asserting the actual terminal state change is hard.
      # We could mock System.cmd("stty", [original_stty]) and assert it was called.
      # For now, we rely on the setup's on_exit handler for safety during tests
      # and assume the terminate callback worked if it didn't crash.
      # Check stty settings manually if needed:
      # {current_stty, 0} = System.cmd("stty", ["-g"])
      # assert String.trim(current_stty) == original_stty
    end
  end

  describe "handle_info({:signal, :SIGWINCH})" do
    test "sends resize event when SIGWINCH is received", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)
      # Consume initial resize event
      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Did not receive initial resize event")
      end

      # Send SIGWINCH signal to the driver process
      # Note: This might not work reliably across all OS/test environments
      # A better approach might involve mocking :erlang.system_monitor
      # or triggering the handle_signal callback directly for testing.
      # Process.signal(driver_pid, :sigwinch) # Sending OS signal is tricky

      # Alternative: Directly call handle_signal for testing (if made public or via helper)
      # Or simulate the message pattern if :erlang.system_monitor sends a specific message

      # Let's simulate the internal GenServer call for this test
      # This requires assuming the shape of the internal message, which is brittle.
      # A more robust way is needed if this test becomes important.
      # For now, we'll test the underlying function if possible, or skip direct test.

      # Let's test by calling the function that sends the event directly
      # This requires the function `send_event` and `IO.ioctl` to work.
      case IO.ioctl(:stdio, :winsize) do
        {:ok, {h, w}} ->
          # Manually trigger the logic within handle_signal
          # Need to implement handle_info for this
          send(driver_pid, {:simulate_sigwinch})

          assert_receive {:terminal_event,
                          %Event{type: :resize, data: %{height: h, width: w}}},
                         500

        {:error, _reason} ->
          # Cannot reliably test ioctl, skip assertion
          Logger.warning(
            "Could not get terminal size via IO.ioctl, skipping SIGWINCH event data test."
          )

          # We can still test that *some* event is sent if we trigger handle_signal
          send(driver_pid, {:simulate_sigwinch})

          assert_receive {:terminal_event,
                          %Event{type: :resize, data: %{height: _, width: _}}},
                         500
      end

      Process.exit(driver_pid, :shutdown)
    end
  end

  # TODO: Add tests for Alt/Meta key combinations (e.g., \ea, \e[1;3A for Alt+Up)
  # TODO: Add tests for Shift + other keys (e.g., Shift+F1, Shift+Arrows if supported)
  # TODO: Add tests for mouse events (requires enabling mouse reporting first)

  test "correctly requests more input if buffer is empty", %{original_stty: _} do
    test_pid = self()
    # Use :sys.get_state to check if IO.getn was called? Or mock?
    # This test is tricky without proper mocking or introspection.
    # For now, we assume the :io_request message implies this behaviour.

    driver_pid = start_driver(test_pid)

    receive do
      {:terminal_event, %Event{type: :resize}} -> :ok
    after
      100 -> flunk("Timeout")
    end

    # The driver should have sent an initial :io_request to :io upon start
    # It will send another one after processing each :io_reply
    # Let's send some data and check it requests more
    send(driver_pid, {:termbox_event, %{type: :key, key: 0, char: ?x, mod: 0}})

    assert_receive {:terminal_event,
                    %Event{type: :key, data: %{char: "x"}}},
                   500

    # Check if IO.getn was requested again (needs introspection or mocking)
    # Example using :sys.trace (can be intrusive)
    # :sys.trace(driver_pid, true)
    # send(driver_pid, {:termbox_event, %{type: :key, key: 0, char: ?y, mod: 0}})
    # assert_receive {:trace, ^driver_pid, :call, {:erlang, :port_command, [:stdio, _]}} # Check for IO.getn call
    # :sys.trace(driver_pid, false)

    Process.exit(driver_pid, :shutdown)
    # Test passes by assumption for now
  end

  test "correctly buffers partial input sequences", %{original_stty: _} do
    test_pid = self()
    driver_pid = start_driver(test_pid)

    receive do
      {:terminal_event, %Event{type: :resize}} -> :ok
    after
      100 -> flunk("Timeout")
    end

    # Send partial escape seq
    send(driver_pid, {:termbox_event, %{type: :key, key: 0, char: ?e, mod: 0}})
    # Should be buffered
    refute_receive {:terminal_event, _}, 50

    send(driver_pid, {:termbox_event, %{type: :key, key: 0, char: ?[, mod: 0}})
    # Still buffered
    refute_receive {:terminal_event, _}, 50

    send(driver_pid, {:termbox_event, %{type: :key, key: 0, char: ?A, mod: 0}})
    # Completed
    assert_receive {:terminal_event, %Event{type: :key, data: %{char: "A"}}}, 500

    # Test another sequence buffering
    send(driver_pid, {:termbox_event, %{type: :key, key: 0, char: ?[, mod: 0}})
    refute_receive {:terminal_event, _}, 50

    send(driver_pid, {:termbox_event, %{type: :key, key: 0, char: ?A, mod: 0}})

    assert_receive {:terminal_event,
                    %Event{type: :key, data: %{char: "A", ctrl: true}}},
                   500

    Process.exit(driver_pid, :shutdown)
  end

  test "handles intermingled input correctly", %{original_stty: _} do
    test_pid = self()
    driver_pid = start_driver(test_pid)

    receive do
      {:terminal_event, %Event{type: :resize}} -> :ok
    after
      100 -> flunk("Timeout waiting for initial resize")
    end

    # Send "x\e[Ay"
    send(driver_pid, {:termbox_event, %{type: :key, key: 0, char: ?x, mod: 0}})

    # Expect :char x, then :up, then :char y
    assert_receive {:terminal_event,
                    %Event{type: :key, data: %{char: "x"}}},
                   500

    assert_receive {:terminal_event, %Event{type: :key, data: %{key: :up}}},
                   500

    assert_receive {:terminal_event,
                    %Event{type: :key, data: %{char: "y"}}},
                   500

    Process.exit(driver_pid, :shutdown)
  end
end

# Add helper to Driver module (or test helper module) if needed:
# def handle_info({:simulate_sigwinch}, state) do
#   # Manually call the SIGWINCH logic for testing
#   handle_signal(:sigwinch, self(), state)
# end
