defmodule Raxol.Core.Runtime.Events.DispatcherTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Runtime.Events.Dispatcher

  # Mock modules for testing
  defmodule Mock.Application do
    def handle_event(_), do: {:test_message, []}

    def update(_module, {:test_message, []}, model),
      do: {%{model | count: model.count + 1}, []}

    def update(_module, _, model), do: {model, []}
  end

  describe "dispatch_event/2" do
    test "successfully dispatches application event" do
      # Setup state with our mock application
      state = %{
        app_module: Mock.Application,
        model: %{count: 0},
        commands: [],
        debug_mode: false,
        plugin_manager: nil
      }

      event = %Event{type: :key, key: :enter, modifiers: []}

      # Test that the event is dispatched and state is updated
      assert {:ok, updated_state} = Dispatcher.dispatch_event(event, state)
      assert updated_state.model.count == 1
    end

    test "handles errors during dispatch" do
      state = %{
        # This will cause an error
        app_module: nil,
        model: %{},
        commands: [],
        debug_mode: false
      }

      event = %Event{type: :key, key: :enter, modifiers: []}

      # Capture log to verify error is logged
      log =
        capture_log(fn ->
          assert {:error, {:dispatch_error, _}, ^state} =
                   Dispatcher.dispatch_event(event, state)
        end)

      assert log =~ "Error dispatching event"
    end
  end

  describe "process_system_event/2" do
    test "handles resize event" do
      state = %{width: 80, height: 24}
      event = %Event{type: :resize, width: 100, height: 50}

      assert {:ok, updated_state} =
               Dispatcher.process_system_event(event, state)

      assert updated_state.width == 100
      assert updated_state.height == 50
    end

    test "handles quit event" do
      state = %{app_module: Mock.Application}
      event = %Event{type: :quit}

      assert {:quit, ^state} = Dispatcher.process_system_event(event, state)
    end

    test "handles focus event" do
      state = %{focused: false}
      event = %Event{type: :focus, focused: true}

      assert {:ok, updated_state} =
               Dispatcher.process_system_event(event, state)

      assert updated_state.focused == true
    end

    test "handles error event" do
      state = %{}
      event = %Event{type: :error, error: "Test error"}

      # Capture log to verify error is logged
      log =
        capture_log(fn ->
          assert {:error, "Test error", ^state} =
                   Dispatcher.process_system_event(event, state)
        end)

      assert log =~ "System error event"
    end

    test "passes through unknown system events" do
      state = %{}
      event = %Event{type: :unknown_system_event}

      assert {:ok, ^state} = Dispatcher.process_system_event(event, state)
    end
  end

  describe "handle_event/2" do
    test "processes event and updates model" do
      state = %{
        app_module: Mock.Application,
        model: %{count: 0},
        commands: []
      }

      event = %Event{type: :key, key: :enter, modifiers: []}

      assert {:ok, updated_state} = Dispatcher.handle_event(event, state)
      assert updated_state.model.count == 1
    end

    test "handles default event conversions" do
      state = %{
        app_module: Mock.Application,
        model: %{count: 0},
        commands: []
      }

      # Test different event types
      key_event = %Event{type: :key, key: :a, modifiers: [:shift]}

      mouse_event = %Event{
        type: :mouse,
        action: :click,
        x: 10,
        y: 20,
        button: :left
      }

      text_event = %Event{type: :text, text: "Hello"}

      # Mock the update function to return the message for verification
      :meck.new(Mock.Application, [:passthrough])

      :meck.expect(Mock.Application, :update, fn _, msg, model ->
        {{:captured, msg}, model, []}
      end)

      # Test key event
      {:ok, result} = Dispatcher.handle_event(key_event, state)
      assert result.model == {:captured, {:key_press, :a, [:shift]}}

      # Test mouse event
      {:ok, result} = Dispatcher.handle_event(mouse_event, state)
      assert result.model == {:captured, {:mouse_event, :click, 10, 20, :left}}

      # Test text event
      {:ok, result} = Dispatcher.handle_event(text_event, state)
      assert result.model == {:captured, {:text_input, "Hello"}}

      # Clean up
      :meck.unload(Mock.Application)
    end
  end
end
