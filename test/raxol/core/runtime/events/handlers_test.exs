defmodule Raxol.Core.Runtime.Events.HandlerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Raxol.Core.Runtime.Events.Handler

  setup do
    # Create a sample event and state for testing
    event = %{type: :test_event, data: "test data"}
    state = %{count: 0}

    # Return these as the test context
    {:ok, %{event: event, state: state}}
  end

  describe "register_handler/4" do
    test ~c"registers a handler with default options" do
      handler_fun = fn _event, state -> {:ok, _event, state} end

      assert {:ok, :test_handler} =
               Handlers.register_handler(
                 :test_handler,
                 [:test_event],
                 handler_fun
               )
    end

    test ~c"registers a handler with custom priority and filter" do
      handler_fun = fn _event, state -> {:ok, _event, state} end
      filter_fun = fn event -> event.data == "test data" end

      assert {:ok, :custom_handler} =
               Handlers.register_handler(
                 :custom_handler,
                 [:test_event],
                 handler_fun,
                 priority: 50,
                 filter: filter_fun
               )
    end
  end

  describe "unregister_handler/1" do
    test ~c"unregisters an existing handler" do
      # First register a handler
      handler_fun = fn _event, state -> {:ok, _event, state} end

      {:ok, :temp_handler} =
        Handlers.register_handler(:temp_handler, [:test_event], handler_fun)

      # Then unregister it
      assert :ok = Handlers.unregister_handler(:temp_handler)
    end

    test ~c"returns error when unregistering non-existent handler" do
      assert {:error, :not_found} =
               Handlers.unregister_handler(:non_existent_handler)
    end
  end

  describe "execute_handlers/2" do
    test "executes handlers in priority order", %{event: event, state: state} do
      # Create handlers with different priorities and side effects to track execution order
      execution_order = []

      # Store execution_order in process dictionary to track updates across function calls
      Process.put(:execution_order, execution_order)

      # Register handlers with different priorities
      Handlers.register_handler(
        :handler1,
        [:test_event],
        fn e, s ->
          current = Process.get(:execution_order)
          Process.put(:execution_order, current ++ [:handler1])
          {:ok, e, s}
        end,
        priority: 30
      )

      Handlers.register_handler(
        :handler2,
        [:test_event],
        fn e, s ->
          current = Process.get(:execution_order)
          Process.put(:execution_order, current ++ [:handler2])
          {:ok, e, s}
        end,
        priority: 10
      )

      Handlers.register_handler(
        :handler3,
        [:test_event],
        fn e, s ->
          current = Process.get(:execution_order)
          Process.put(:execution_order, current ++ [:handler3])
          {:ok, e, s}
        end,
        priority: 20
      )

      # Execute all handlers
      assert {:ok, ^event, ^state} = Handlers.execute_handlers(event, state)

      # Check the execution order
      assert Process.get(:execution_order) == [:handler2, :handler3, :handler1]
    end

    test "filters events based on filter function", %{
      event: event,
      state: state
    } do
      # Register a handler that only processes events with specific data
      Handlers.register_handler(
        :filtered_handler,
        [:test_event],
        fn e, s ->
          # Update state to mark that the handler was executed
          {:ok, e, %{s | count: s.count + 1}}
        end,
        filter: fn e -> e.data == "test data" end
      )

      # This event should be processed
      {:ok, _updated_event, updated_state} =
        Handlers.execute_handlers(event, state)

      assert updated_state.count == 1

      # Create an event that doesn't match the filter
      filtered_event = %{type: :test_event, data: "other data"}

      # This event should not be processed
      {:ok, _updated_event, updated_state} =
        Handlers.execute_handlers(filtered_event, state)

      assert updated_state.count == 0
    end

    test "handler can transform event for next handler", %{
      event: event,
      state: state
    } do
      # First handler transforms the event
      Handlers.register_handler(
        :transformer,
        [:test_event],
        fn e, s ->
          {:ok, %{e | data: "transformed"}, s}
        end,
        priority: 10
      )

      # Second handler checks the transformed data
      Handlers.register_handler(
        :checker,
        [:test_event],
        fn e, s ->
          if e.data == "transformed" do
            {:ok, e, %{s | count: s.count + 1}}
          else
            {:ok, e, s}
          end
        end,
        priority: 20
      )

      # Execute the handlers
      {:ok, updated_event, updated_state} =
        Handlers.execute_handlers(event, state)

      # Verify the event was transformed
      assert updated_event.data == "transformed"
      # Verify the second handler saw the transformed event
      assert updated_state.count == 1
    end

    test "handler can stop event propagation", %{event: event, state: state} do
      # First handler will stop propagation
      Handlers.register_handler(
        :stopper,
        [:test_event],
        fn e, s ->
          {:stop, %{e | data: "stopped"}, s}
        end,
        priority: 10
      )

      # Second handler should not be executed
      Handlers.register_handler(
        :never_run,
        [:test_event],
        fn _e, s ->
          # This would make count 999 if executed
          {:ok, _e, %{s | count: 999}}
        end,
        priority: 20
      )

      # Execute the handlers
      {:ok, updated_event, updated_state} =
        Handlers.execute_handlers(event, state)

      # Verify the event was transformed by the first handler
      assert updated_event.data == "stopped"
      # Verify the second handler was not executed
      assert updated_state.count == 0
    end

    test "handles errors in handlers", %{event: event, state: state} do
      # Register a handler that raises an error
      Handlers.register_handler(:error_handler, [:test_event], fn _e, _s ->
        raise "Test error"
      end)

      # Execute handler and capture the log output
      log =
        capture_log(fn ->
          assert {:error, {:handler_error, _}, ^state} =
                   Handlers.execute_handlers(event, state)
        end)

      assert log =~ "Error executing handlers"
    end

    test "handles handler returning an error", %{event: event, state: state} do
      # Register a handler that returns an error
      Handlers.register_handler(:error_return_handler, [:test_event], fn _e,
                                                                         _s ->
        {:error, :test_error}
      end)

      # Execute handler and capture the log output
      log =
        capture_log(fn ->
          assert {:error, :test_error, ^state} =
                   Handlers.execute_handlers(event, state)
        end)

      assert log =~ "Handler error"
    end
  end
end
