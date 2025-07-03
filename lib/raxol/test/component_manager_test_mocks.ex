defmodule Raxol.Test.ComponentManagerTestMocks do
  defmodule Raxol.Core.Runtime.ComponentManagerTest.TestComponent do
    # Mock component module for testing ComponentManager
    # Moved from component_manager_test.exs

    def init(props) do
      # Ensure all keys are present
      Map.merge(
        %{
          counter: 0,
          last_message: nil,
          event_value: nil,
          subscriptions: [],
          error_count: 0
        },
        props
      )
    end

    def mount(state) do
      {state, []}
    end

    def unmount(state) do
      state
    end

    def update(:increment, state) do
      {Map.update!(state, :counter, &(&1 + 1)), []}
    end

    def update(:decrement, state) do
      {Map.update!(state, :counter, &(&1 - 1)), []}
    end

    def update(:trigger_broadcast, state) do
      # Return state unchanged, but issue broadcast command
      {Map.put(state, :last_message, :trigger_broadcast),
       [{:broadcast, :broadcast_message}]}
    end

    def update(:add_subscription, state) do
      # Add a test subscription
      {Map.update!(state, :subscriptions, &[:test_sub | &1]),
       [{:subscribe, [:test_event]}]}
    end

    def update(:trigger_error, _state) do
      # Simulate an error condition
      raise "Test error"
    end

    def update(msg, state) do
      # Just return the message in the state for testing
      # Return empty command list by default
      {Map.put(state, :last_message, msg), []}
    end

    def handle_event({:test_event, value}, state) do
      new_state = Map.put(state, :event_value, value)
      {new_state, []}
    end

    def handle_event(_event, state) do
      {state, []}
    end

    # Note: These functions below were used by the old test structure
    # They might not be needed with the refactored tests, but keeping them
    # here doesn't hurt.
    def mount_with_commands(state) do
      commands = [
        {:command, {:subscribe, [:test_event]}},
        {:schedule, :delayed_message, 50}
      ]

      {state, commands}
    end

    def handle_event_with_commands(_event, state) do
      commands = [
        {:broadcast, :broadcast_message}
      ]

      {state, commands}
    end
  end
end
