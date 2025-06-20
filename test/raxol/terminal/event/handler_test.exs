defmodule Raxol.Terminal.Event.HandlerTest do
  use ExUnit.Case
  alias Raxol.Terminal.{Event.Handler, TestHelper}

  describe "new/0" do
    test "creates a new event handler with default values" do
      event = Handler.new()
      assert event.handlers == %{}
      assert :queue.is_empty(event.queue)
    end
  end

  describe "register_handler/3" do
    test "registers a new event handler" do
      emulator = TestHelper.create_test_emulator()
      handler = fn emulator, _data -> emulator end
      emulator = Handler.register_handler(emulator, :test_event, handler)
      assert Map.has_key?(emulator.event.handlers, :test_event)
    end

    test "updates existing event handler" do
      emulator = TestHelper.create_test_emulator()
      handler1 = fn emulator, _data -> emulator end
      handler2 = fn emulator, _data -> emulator end
      emulator = Handler.register_handler(emulator, :test_event, handler1)
      emulator = Handler.register_handler(emulator, :test_event, handler2)
      assert emulator.event.handlers[:test_event] == handler2
    end
  end

  describe "unregister_handler/2" do
    test "removes an event handler" do
      emulator = TestHelper.create_test_emulator()
      handler = fn emulator, _data -> emulator end
      emulator = Handler.register_handler(emulator, :test_event, handler)
      emulator = Handler.unregister_handler(emulator, :test_event)
      refute Map.has_key?(emulator.event.handlers, :test_event)
    end

    test "does nothing for non-existent handler" do
      emulator = TestHelper.create_test_emulator()
      emulator = Handler.unregister_handler(emulator, :non_existent)
      assert emulator.event.handlers == %{}
    end
  end

  describe "dispatch_event/3" do
    test "calls registered handler with event data" do
      emulator = TestHelper.create_test_emulator()
      test_pid = self()

      handler = fn emulator, data ->
        send(test_pid, {:event_handled, data})
        emulator
      end

      emulator = Handler.register_handler(emulator, :test_event, handler)
      emulator = Handler.dispatch_event(emulator, :test_event, "test_data")
      assert_receive {:event_handled, "test_data"}
    end

    test "returns emulator unchanged when no handler exists" do
      emulator = TestHelper.create_test_emulator()
      result = Handler.dispatch_event(emulator, :non_existent, "test_data")
      assert result == emulator
    end
  end

  describe "queue_event/3" do
    test "adds event to queue" do
      emulator = TestHelper.create_test_emulator()
      emulator = Handler.queue_event(emulator, :test_event, "test_data")
      refute :queue.is_empty(emulator.event.queue)
    end
  end

  describe "process_events/1" do
    test "processes all queued events" do
      emulator = TestHelper.create_test_emulator()
      test_pid = self()

      handler = fn emulator, data ->
        send(test_pid, {:event_handled, data})
        emulator
      end

      emulator = Handler.register_handler(emulator, :test_event, handler)
      emulator = Handler.queue_event(emulator, :test_event, "test_data1")
      emulator = Handler.queue_event(emulator, :test_event, "test_data2")
      emulator = Handler.process_events(emulator)
      assert_receive {:event_handled, "test_data1"}
      assert_receive {:event_handled, "test_data2"}
      assert :queue.is_empty(emulator.event.queue)
    end

    test "handles empty queue" do
      emulator = TestHelper.create_test_emulator()
      result = Handler.process_events(emulator)
      assert result == emulator
    end
  end

  describe "get_event_queue/1" do
    test "returns the current event queue" do
      emulator = TestHelper.create_test_emulator()
      emulator = Handler.queue_event(emulator, :test_event, "test_data")
      queue = Handler.get_event_queue(emulator)
      refute :queue.is_empty(queue)
    end
  end

  describe "clear_event_queue/1" do
    test "removes all events from queue" do
      emulator = TestHelper.create_test_emulator()
      emulator = Handler.queue_event(emulator, :test_event, "test_data")
      emulator = Handler.clear_event_queue(emulator)
      assert :queue.is_empty(emulator.event.queue)
    end
  end

  describe "reset_event_handler/1" do
    test "resets event handler to initial state" do
      emulator = TestHelper.create_test_emulator()
      handler = fn emulator, _data -> emulator end
      emulator = Handler.register_handler(emulator, :test_event, handler)
      emulator = Handler.queue_event(emulator, :test_event, "test_data")
      emulator = Handler.reset_event_handler(emulator)
      assert emulator.event.handlers == %{}
      assert :queue.is_empty(emulator.event.queue)
    end
  end
end
