defmodule Raxol.Terminal.ManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Manager
  alias Raxol.Core.Events.Event

  setup do
    emulator = Raxol.Terminal.Emulator.new()

    # Start the manager with test configuration using unique naming
    {:ok, pid} =
      start_supervised(
        {Manager,
         [
           terminal: emulator,
           runtime_pid: self(),
           name: Raxol.Test.ProcessNaming.generate_name(Manager)
         ]}
      )

    %{pid: pid}
  end

  test "window resize event triggers notify_resized", %{pid: pid} do
    # Debug: Check the manager's state
    state = :sys.get_state(pid)
    IO.inspect(state, label: "Manager State")

    event = %Event{
      type: :window,
      data: %{action: :resize, width: 100, height: 40}
    }

    Manager.process_event(pid, event)
    assert_receive {:terminal_resized, 100, 40}, 100
  end

  test "window focus event triggers notify_focus_changed", %{pid: pid} do
    event = %Event{type: :window, data: %{action: :focus, focused: true}}
    Manager.process_event(pid, event)
    assert_receive {:terminal_focus_changed, true}, 100
  end

  test "window blur event triggers notify_focus_changed(false)", %{pid: pid} do
    event = %Event{type: :window, data: %{action: :blur}}
    Manager.process_event(pid, event)
    assert_receive {:terminal_focus_changed, false}, 100
  end

  test "mode event triggers notify_mode_changed", %{pid: pid} do
    event = %Event{type: :mode, data: %{mode: :insert}}
    Manager.process_event(pid, event)
    assert_receive {:terminal_mode_changed, :insert}, 100
  end

  test "focus event triggers notify_focus_changed", %{pid: pid} do
    event = %Event{type: :focus, data: %{focused: false}}
    Manager.process_event(pid, event)
    assert_receive {:terminal_focus_changed, false}, 100
  end

  test "clipboard event triggers notify_clipboard_event", %{pid: pid} do
    event = %Event{type: :clipboard, data: %{op: :copy, content: "abc"}}
    Manager.process_event(pid, event)
    assert_receive {:terminal_clipboard_event, :copy, "abc"}, 100
  end

  test "selection event triggers notify_selection_changed", %{pid: pid} do
    event = %Event{
      type: :selection,
      data: %{start_pos: {0, 0}, end_pos: {1, 1}, text: "hi"}
    }

    Manager.process_event(pid, event)

    assert_receive {:terminal_selection_changed,
                    %{start_pos: {0, 0}, end_pos: {1, 1}, text: "hi"}},
                   100
  end

  test "paste event triggers notify_paste_event", %{pid: pid} do
    event = %Event{type: :paste, data: %{text: "foo", position: {2, 3}}}
    Manager.process_event(pid, event)
    assert_receive {:terminal_paste_event, "foo", {2, 3}}, 100
  end

  test "cursor event triggers notify_cursor_event", %{pid: pid} do
    event = %Event{
      type: :cursor,
      data: %{visible: true, style: :block, blink: true, position: {1, 2}}
    }

    Manager.process_event(pid, event)

    assert_receive {:terminal_cursor_event,
                    %{
                      visible: true,
                      style: :block,
                      blink: true,
                      position: {1, 2}
                    }},
                   100
  end

  test "scroll event triggers notify_scroll_event", %{pid: pid} do
    event = %Event{
      type: :scroll,
      data: %{direction: :down, delta: 5, position: {0, 0}}
    }

    Manager.process_event(pid, event)
    assert_receive {:terminal_scroll_event, :down, 5, {0, 0}}, 100
  end

  test "unknown event type does not crash or send messages" do
    # Flush the mailbox to remove any previous messages
    flush()
    # Create a separate manager for this test - handle already started case
    pid =
      case Manager.start_link([]) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    # Send an unknown event
    event = %Raxol.Core.Events.Event{type: :unknown_event, data: %{}}
    Manager.process_event(pid, event)
    # Assert that an error message is received for unknown event type
    assert_receive {:terminal_error, :unknown_event_type,
                    %{action: :process_event, event: ^event}},
                   100
  end

  defp flush do
    receive do
      _ -> flush()
    after
      0 -> :ok
    end
  end

  test "missing terminal returns error", _ do
    # Create a separate manager without a terminal for this test
    {:ok, pid} =
      GenServer.start_link(Raxol.Terminal.Manager, %{
        sessions: %{},
        terminal: nil,
        runtime_pid: self(),
        callback_module: nil
      })

    event = %Event{
      type: :window,
      data: %{action: :resize, width: 10, height: 10}
    }

    assert {:error, :no_terminal} = Manager.process_event(pid, event)

    assert_receive {:terminal_error, :no_terminal,
                    %{action: :process_event, event: ^event}},
                   100
  end

  describe "telemetry event emission" do
    setup do
      test_pid = self()
      ref = System.unique_integer([:positive])

      events = [
        [:raxol, :terminal, :scroll_event, :delta],
        [:raxol, :terminal, :paste_event, :length]
      ]

      handler_id = "test-telemetry-handler-#{System.unique_integer()}"

      :telemetry.attach_many(
        handler_id,
        events,
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event, measurements, metadata, ref})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)
      %{ref: ref}
    end

    test "emits scroll_event.delta telemetry", %{pid: pid, ref: ref} do
      event = %Event{
        type: :scroll,
        data: %{direction: :vertical, delta: 7, position: {1, 2}}
      }

      Manager.process_event(pid, event)

      assert_receive {
                       :telemetry_event,
                       [:raxol, :terminal, :scroll_event, :delta],
                       %{delta: 7},
                       %{direction: :vertical, position: {1, 2}, pid: _},
                       ^ref
                     },
                     100
    end

    test "emits paste_event.length telemetry", %{pid: pid, ref: ref} do
      event = %Event{type: :paste, data: %{text: "foobar", position: {3, 4}}}
      Manager.process_event(pid, event)

      assert_receive {
                       :telemetry_event,
                       [:raxol, :terminal, :paste_event, :length],
                       %{length: 6},
                       %{position: {3, 4}, pid: _},
                       ^ref
                     },
                     100
    end
  end
end
