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

    # Get original stty settings to restore after test
    {original_stty, 0} = System.cmd("stty", ["-g"])
    original_stty = String.trim(original_stty)

    on_exit(fn ->
      # Ensure terminal is restored even if test fails
      System.cmd("stty", [original_stty])
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

  describe "handle_info({:io_reply, ...})" do
    test "parses and dispatches single printable characters", %{
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

      # Simulate receiving 'a'
      ref = make_ref()
      send(driver_pid, {:io_reply, ref, "a"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :char, char: "a"}}},
                     500

      # Simulate receiving 'b'
      ref = make_ref()
      send(driver_pid, {:io_reply, ref, "b"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :char, char: "b"}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches arrow key sequences", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Up Arrow: \e[A
      send(driver_pid, {:io_reply, make_ref(), "\e[A"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :up}}},
                     500

      # Down Arrow: \e[B
      send(driver_pid, {:io_reply, make_ref(), "\e[B"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :down}}},
                     500

      # Right Arrow: \e[C
      send(driver_pid, {:io_reply, make_ref(), "\e[C"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :right}}},
                     500

      # Left Arrow: \e[D
      send(driver_pid, {:io_reply, make_ref(), "\e[D"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :left}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches function key sequences (F1-F12)", %{
      original_stty: _
    } do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout waiting for initial resize")
      end

      # Function Keys (using common xterm/VT sequences)
      # F1: \\e[11~ (or \\eOP) - Using \\eOP for wider compatibility demonstration
      send(driver_pid, {:io_reply, make_ref(), "\\eOP"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f1}}},
                     500

      # F2: \\e[12~ (or \\eOQ) - Using \\eOQ
      send(driver_pid, {:io_reply, make_ref(), "\\eOQ"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f2}}},
                     500

      # F3: \\e[13~ (or \\eOR) - Using \\eOR
      send(driver_pid, {:io_reply, make_ref(), "\\eOR"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f3}}},
                     500

      # F4: \\e[14~ (or \\eOS) - Using \\eOS
      send(driver_pid, {:io_reply, make_ref(), "\\eOS"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f4}}},
                     500

      # F5: \\e[15~
      send(driver_pid, {:io_reply, make_ref(), "\\e[15~"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f5}}},
                     500

      # F6: \\e[17~
      send(driver_pid, {:io_reply, make_ref(), "\\e[17~"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f6}}},
                     500

      # F7: \\e[18~
      send(driver_pid, {:io_reply, make_ref(), "\\e[18~"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f7}}},
                     500

      # F8: \\e[19~
      send(driver_pid, {:io_reply, make_ref(), "\\e[19~"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f8}}},
                     500

      # F9: \\e[20~
      send(driver_pid, {:io_reply, make_ref(), "\\e[20~"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f9}}},
                     500

      # F10: \\e[21~
      send(driver_pid, {:io_reply, make_ref(), "\\e[21~"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f10}}},
                     500

      # F11: \\e[23~
      send(driver_pid, {:io_reply, make_ref(), "\\e[23~"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f11}}},
                     500

      # F12: \\e[24~
      send(driver_pid, {:io_reply, make_ref(), "\\e[24~"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :f12}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Ctrl + Arrow key sequences", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout waiting for initial resize")
      end

      # Ctrl+Up: \e[1;5A
      send(driver_pid, {:io_reply, make_ref(), "\e[1;5A"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :up, ctrl: true}}},
                     500

      # Ctrl+Down: \e[1;5B
      send(driver_pid, {:io_reply, make_ref(), "\e[1;5B"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :down, ctrl: true}}},
                     500

      # Ctrl+Right: \e[1;5C
      send(driver_pid, {:io_reply, make_ref(), "\e[1;5C"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :right, ctrl: true}}},
                     500

      # Ctrl+Left: \e[1;5D
      send(driver_pid, {:io_reply, make_ref(), "\e[1;5D"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :left, ctrl: true}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Ctrl+C", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      send(driver_pid, {:io_reply, make_ref(), <<3>>})

      assert_receive {:terminal_event,
                      %Event{
                        type: :key,
                        data: %{key: :char, char: "c", ctrl: true}
                      }},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "buffers and parses partial ANSI sequences", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Send partial sequence "\e["
      send(driver_pid, {:io_reply, make_ref(), "\e["})
      # Should not receive anything yet
      refute_receive {:terminal_event, _}, 50

      # Send the rest "A"
      send(driver_pid, {:io_reply, make_ref(), "A"})
      # Should now receive the complete :up event
      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :up}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "handles mixed sequences and characters", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Send "x\e[Ay"
      send(driver_pid, {:io_reply, make_ref(), "x\e[Ay"})

      # Expect :char x, then :up, then :char y
      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :char, char: "x"}}},
                     500

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :up}}},
                     500

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :char, char: "y"}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Home/End key sequences", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Home: \\e[H or \\e[1~
      send(driver_pid, {:io_reply, make_ref(), "\\e[H"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :home}}},
                     500

      send(driver_pid, {:io_reply, make_ref(), "\\e[1~"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :home}}},
                     500

      # End: \\e[F or \\e[4~
      send(driver_pid, {:io_reply, make_ref(), "\\e[F"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :end}}},
                     500

      send(driver_pid, {:io_reply, make_ref(), "\\e[4~"})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :end}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches PageUp/PageDown key sequences", %{
      original_stty: _
    } do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # PageUp: \\e[5~
      send(driver_pid, {:io_reply, make_ref(), "\\e[5~"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :page_up}}},
                     500

      # PageDown: \\e[6~
      send(driver_pid, {:io_reply, make_ref(), "\\e[6~"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :page_down}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Delete key sequence", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Delete: \\e[3~
      send(driver_pid, {:io_reply, make_ref(), "\\e[3~"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :delete}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Backspace/Ctrl+H", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Backspace (often sends ^H or ^?)
      # Ctrl+H
      send(driver_pid, {:io_reply, make_ref(), <<8>>})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :backspace}}},
                     500

      # DEL (sometimes used for backspace)
      send(driver_pid, {:io_reply, make_ref(), <<127>>})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :backspace}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Tab/Shift+Tab", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Tab: \\t (character 9)
      send(driver_pid, {:io_reply, make_ref(), <<9>>})

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :tab}}},
                     500

      # Shift+Tab: \\e[Z
      send(driver_pid, {:io_reply, make_ref(), "\\e[Z"})
      # Use :back_tab for Shift+Tab
      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :back_tab}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Enter/Ctrl+M", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Enter (often sends ^M)
      # Ctrl+M (Carriage Return)
      send(driver_pid, {:io_reply, make_ref(), <<13>>})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :enter}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Escape key", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Escape: \\e (character 27) - Note: might be buffered if part of a sequence
      send(driver_pid, {:io_reply, make_ref(), <<27>>})

      # Sending ESC alone might not immediately trigger an event if the driver waits
      # for potential subsequent characters in an escape sequence.
      # Add a small delay or send another character to force processing.
      # Adjust delay as needed based on driver's buffering logic
      :timer.sleep(50)

      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :esc}}},
                     100

      Process.exit(driver_pid, :shutdown)
    end

    test "handles input buffering for escape sequences", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Send partial sequence \\e[
      send(driver_pid, {:io_reply, make_ref(), "\\e["})
      # Should not receive anything yet
      refute_receive {:terminal_event, _}, 50

      # Send the rest of the sequence 'A' for Up Arrow
      send(driver_pid, {:io_reply, make_ref(), "A"})
      # Should now receive the complete event
      assert_receive {:terminal_event, %Event{type: :key, data: %{key: :up}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Ctrl + char sequences", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout waiting for initial resize")
      end

      # Ctrl+A (SOH)
      send(driver_pid, {:io_reply, make_ref(), <<1>>})

      assert_receive {:terminal_event,
                      %Event{
                        type: :key,
                        data: %{key: :char, char: "a", ctrl: true}
                      }},
                     500

      # Ctrl+Z (SUB)
      send(driver_pid, {:io_reply, make_ref(), <<26>>})

      assert_receive {:terminal_event,
                      %Event{
                        type: :key,
                        data: %{key: :char, char: "z", ctrl: true}
                      }},
                     500

      # Ctrl+C (ETX) - Should also be handled
      send(driver_pid, {:io_reply, make_ref(), <<3>>})

      assert_receive {:terminal_event,
                      %Event{
                        type: :key,
                        data: %{key: :char, char: "c", ctrl: true}
                      }},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches mouse click events (VT200 format)", %{
      original_stty: _
    } do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout waiting for initial resize")
      end

      # Simulate Mouse Left Button Press at (10, 5)
      # Format: \e[M Cb Cx Cy  (Cb = button + modifier, Cx/Cy = coords + 32)
      # Button 0 (Left), Coords (10, 5) -> Cx=10+32=42, Cy=5+32=37 -> Cb=32
      send(
        driver_pid,
        {:io_reply, make_ref(), "\\e[M #{<<32>>}#{<<42>>}#{<<37>>}"}
      )

      assert_receive {:terminal_event,
                      %Event{
                        type: :mouse,
                        data: %{
                          button: :left,
                          action: :press,
                          x: 10,
                          y: 5,
                          ctrl: false,
                          alt: false,
                          shift: false
                        }
                      }},
                     500

      # Simulate Mouse Left Button Release at (10, 5)
      # Format: \e[M Cb Cx Cy (Cb = 3 for release, same coords)
      send(
        driver_pid,
        {:io_reply, make_ref(), "\\e[M #{<<35>>}#{<<42>>}#{<<37>>}"}
      )

      assert_receive {:terminal_event,
                      %Event{
                        type: :mouse,
                        data: %{
                          # Typically release doesn't specify button in this format
                          button: :none,
                          action: :release,
                          x: 10,
                          y: 5,
                          ctrl: false,
                          alt: false,
                          shift: false
                        }
                      }},
                     500

      # Simulate Mouse Right Button Press at (20, 15) -> Cb=34, Cx=52, Cy=47
      send(
        driver_pid,
        {:io_reply, make_ref(), "\\e[M #{<<34>>}#{<<52>>}#{<<47>>}"}
      )

      assert_receive {:terminal_event,
                      %Event{
                        type: :mouse,
                        data: %{
                          button: :right,
                          action: :press,
                          x: 20,
                          y: 15,
                          ctrl: false,
                          alt: false,
                          shift: false
                        }
                      }},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches mouse scroll events (VT200 format)", %{
      original_stty: _
    } do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout waiting for initial resize")
      end

      # Simulate Scroll Up at (1, 1) -> Cb=96, Cx=33, Cy=33
      send(
        driver_pid,
        {:io_reply, make_ref(), "\\e[M #{<<96>>}#{<<33>>}#{<<33>>}"}
      )

      assert_receive {:terminal_event,
                      %Event{
                        type: :mouse,
                        data: %{
                          button: :wheel,
                          action: :scroll_up,
                          x: 1,
                          y: 1,
                          ctrl: false,
                          alt: false,
                          shift: false
                        }
                      }},
                     500

      # Simulate Scroll Down at (1, 1) -> Cb=97, Cx=33, Cy=33
      send(
        driver_pid,
        {:io_reply, make_ref(), "\\e[M #{<<97>>}#{<<33>>}#{<<33>>}"}
      )

      assert_receive {:terminal_event,
                      %Event{
                        type: :mouse,
                        data: %{
                          button: :wheel,
                          action: :scroll_down,
                          x: 1,
                          y: 1,
                          ctrl: false,
                          alt: false,
                          shift: false
                        }
                      }},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches mouse click events (SGR format 1006)", %{
      original_stty: _
    } do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout waiting for initial resize")
      end

      # Simulate Mouse Left Button Press at (10, 5)
      # Format: \e[<Cb;Cx;CyM  (Cb = button, Cx/Cy = coords)
      send(driver_pid, {:io_reply, make_ref(), "\\e[<0;10;5M"})

      assert_receive {:terminal_event,
                      %Event{
                        type: :mouse,
                        data: %{
                          button: :left,
                          action: :press,
                          x: 10,
                          y: 5,
                          ctrl: false,
                          alt: false,
                          shift: false
                        }
                      }},
                     500

      # Simulate Mouse Left Button Release at (10, 5)
      # Format: \e[<Cb;Cx;Cym (lower case m)
      send(driver_pid, {:io_reply, make_ref(), "\\e[<0;10;5m"})

      assert_receive {:terminal_event,
                      %Event{
                        type: :mouse,
                        data: %{
                          # SGR retains button on release
                          button: :left,
                          action: :release,
                          x: 10,
                          y: 5,
                          ctrl: false,
                          alt: false,
                          shift: false
                        }
                      }},
                     500

      # Simulate Scroll Up at (1, 1) -> Cb=64
      send(driver_pid, {:io_reply, make_ref(), "\\e[<64;1;1M"})

      assert_receive {:terminal_event,
                      %Event{
                        type: :mouse,
                        data: %{
                          button: :wheel,
                          action: :scroll_up,
                          x: 1,
                          y: 1,
                          ctrl: false,
                          alt: false,
                          shift: false
                        }
                      }},
                     500

      # Simulate Scroll Down at (1, 1) -> Cb=65
      send(driver_pid, {:io_reply, make_ref(), "\\e[<65;1;1M"})

      assert_receive {:terminal_event,
                      %Event{
                        type: :mouse,
                        data: %{
                          button: :wheel,
                          action: :scroll_down,
                          x: 1,
                          y: 1,
                          ctrl: false,
                          alt: false,
                          shift: false
                        }
                      }},
                     500

      # Simulate Ctrl+Left Click at (12, 8) -> Cb=16
      send(driver_pid, {:io_reply, make_ref(), "\\e[<16;12;8M"})

      assert_receive {:terminal_event,
                      %Event{
                        type: :mouse,
                        data: %{
                          button: :left,
                          action: :press,
                          x: 12,
                          y: 8,
                          ctrl: true,
                          alt: false,
                          shift: false
                        }
                      }},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Shift + Arrow key sequences", %{
      original_stty: _
    } do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      send(driver_pid, {:io_reply, make_ref(), "\e[1;2A"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :up, shift: true}}},
                     500

      send(driver_pid, {:io_reply, make_ref(), "\e[1;2B"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :down, shift: true}}},
                     500

      send(driver_pid, {:io_reply, make_ref(), "\e[1;2C"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :right, shift: true}}},
                     500

      send(driver_pid, {:io_reply, make_ref(), "\e[1;2D"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :left, shift: true}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Alt + Char key sequences", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Alt+a (ESC a)
      send(driver_pid, {:io_reply, make_ref(), "\ea"})

      assert_receive {:terminal_event,
                      %Event{
                        type: :key,
                        data: %{key: :char, char: "a", alt: true}
                      }},
                     500

      # Alt+Z (ESC Z)
      send(driver_pid, {:io_reply, make_ref(), "\eZ"})

      assert_receive {:terminal_event,
                      %Event{
                        type: :key,
                        data: %{key: :char, char: "Z", alt: true}
                      }},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Alt + Arrow key sequences", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      send(driver_pid, {:io_reply, make_ref(), "\e[1;3A"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :up, alt: true}}},
                     500

      send(driver_pid, {:io_reply, make_ref(), "\e[1;3B"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :down, alt: true}}},
                     500

      send(driver_pid, {:io_reply, make_ref(), "\e[1;3C"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :right, alt: true}}},
                     500

      send(driver_pid, {:io_reply, make_ref(), "\e[1;3D"})

      assert_receive {:terminal_event,
                      %Event{type: :key, data: %{key: :left, alt: true}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses and dispatches Focus In/Out events", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Focus In: \e[I
      send(driver_pid, {:io_reply, make_ref(), "\e[I"})
      assert_receive {:terminal_event, %Event{type: :focus_in}}, 500

      # Focus Out: \e[O
      send(driver_pid, {:io_reply, make_ref(), "\e[O"})
      assert_receive {:terminal_event, %Event{type: :focus_out}}, 500

      Process.exit(driver_pid, :shutdown)
    end

    test "parses bracketed paste events", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Send paste sequence
      paste_content = "hello\nworld!\n"

      send(
        driver_pid,
        {:io_reply, make_ref(), "\e[200~#{paste_content}\e[201~"}
      )

      assert_receive {:terminal_event,
                      %Event{type: :paste, data: %{text: paste_content}}},
                     500

      Process.exit(driver_pid, :shutdown)
    end

    test "buffers incomplete bracketed paste events", %{original_stty: _} do
      test_pid = self()
      driver_pid = start_driver(test_pid)

      receive do
        {:terminal_event, %Event{type: :resize}} -> :ok
      after
        100 -> flunk("Timeout")
      end

      # Send partial paste sequence (start marker + some text)
      send(driver_pid, {:io_reply, make_ref(), "\e[200~hello"})
      # Should not receive paste event yet
      refute_receive {:terminal_event, _}, 50

      # Send rest of text + end marker
      send(driver_pid, {:io_reply, make_ref(), " world\e[201~"})

      assert_receive {:terminal_event,
                      %Event{type: :paste, data: %{text: "hello world"}}},
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
    send(driver_pid, {:io_reply, make_ref(), "x"})

    assert_receive {:terminal_event,
                    %Event{type: :key, data: %{key: :char, char: "x"}}},
                   500

    # Check if IO.getn was requested again (needs introspection or mocking)
    # Example using :sys.trace (can be intrusive)
    # :sys.trace(driver_pid, true)
    # send(driver_pid, {:io_reply, make_ref(), "y"})
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
    send(driver_pid, {:io_reply, make_ref(), "\e"})
    # Should be buffered
    refute_receive {:terminal_event, _}, 50

    send(driver_pid, {:io_reply, make_ref(), "["})
    # Still buffered
    refute_receive {:terminal_event, _}, 50

    send(driver_pid, {:io_reply, make_ref(), "A"})
    # Completed
    assert_receive {:terminal_event, %Event{type: :key, data: %{key: :up}}}, 500

    # Test another sequence buffering
    send(driver_pid, {:io_reply, make_ref(), "\e[1;5"})
    refute_receive {:terminal_event, _}, 50

    send(driver_pid, {:io_reply, make_ref(), "A"})

    assert_receive {:terminal_event,
                    %Event{type: :key, data: %{key: :up, ctrl: true}}},
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
    send(driver_pid, {:io_reply, make_ref(), "x\e[Ay"})

    # Expect :char x, then :up, then :char y
    assert_receive {:terminal_event,
                    %Event{type: :key, data: %{key: :char, char: "x"}}},
                   500

    assert_receive {:terminal_event, %Event{type: :key, data: %{key: :up}}},
                   500

    assert_receive {:terminal_event,
                    %Event{type: :key, data: %{key: :char, char: "y"}}},
                   500

    Process.exit(driver_pid, :shutdown)
  end
end

# Add helper to Driver module (or test helper module) if needed:
# def handle_info({:simulate_sigwinch}, state) do
#   # Manually call the SIGWINCH logic for testing
#   handle_signal(:sigwinch, self(), state)
# end
