defmodule Raxol.Core.Runtime.ComponentManagerTest do
  use ExUnit.Case, async: false

  alias Raxol.Core.Runtime.ComponentManager

  alias Raxol.Test.ComponentManagerTestMocks.Raxol.Core.Runtime.ComponentManagerTest.TestComponent

  require Raxol.Test.ComponentManagerTestMocks

  setup do
    # Start ComponentManager with clean state
    start_supervised!(ComponentManager)
    :ok
  end

  describe "component lifecycle" do
    test 'mount registers a component' do
      {:ok, component_id} = ComponentManager.mount(TestComponent)

      # Verify component was registered
      component_data = ComponentManager.get_component(component_id)
      assert component_data.module == TestComponent
      assert component_data.state.counter == 0

      # Verify it was added to render queue
      render_queue = ComponentManager.get_render_queue()
      assert component_id in render_queue
    end

    test 'mount with props' do
      props = %{initial_value: 100}
      {:ok, component_id} = ComponentManager.mount(TestComponent, props)

      component_data = ComponentManager.get_component(component_id)
      assert component_data.props == props
      assert component_data.state.initial_value == 100
    end

    test 'unmount removes a component' do
      {:ok, component_id} = ComponentManager.mount(TestComponent)

      # Verify component was registered
      assert ComponentManager.get_component(component_id) != nil

      # Unmount component
      {:ok, _final_state} = ComponentManager.unmount(component_id)

      # Verify component was removed
      assert ComponentManager.get_component(component_id) == nil
    end

    test 'unmount returns error for unknown component' do
      assert {:error, :not_found} =
               ComponentManager.unmount("unknown_component")
    end

    test 'unmount cleans up component resources' do
      # Mount component with subscriptions
      {:ok, component_id} = ComponentManager.mount(TestComponent)

      # Add a subscription
      {:ok, _} = ComponentManager.update(component_id, :add_subscription)

      # Verify subscription was added
      component_data = ComponentManager.get_component(component_id)
      assert component_data.state.subscriptions != nil

      # Unmount component
      {:ok, _final_state} = ComponentManager.unmount(component_id)

      # Verify component and its resources were cleaned up
      assert ComponentManager.get_component(component_id) == nil
      # Verify no orphaned subscriptions remain
      assert ComponentManager.get_render_queue() == []
    end

    test 'mount handles invalid component module' do
      assert {:error, :invalid_component} = ComponentManager.mount(nil)

      assert {:error, :invalid_component} =
               ComponentManager.mount("not_a_module")
    end

    test 'mount handles component init failure' do
      defmodule BadComponent do
        def init(_props), do: {:error, :init_failed}
      end

      assert {:error, :init_failed} = ComponentManager.mount(BadComponent)
    end
  end

  describe "component updates" do
    test 'update modifies component state' do
      {:ok, component_id} = ComponentManager.mount(TestComponent)

      # Get initial state
      initial_data = ComponentManager.get_component(component_id)
      assert initial_data.state.counter == 0

      # Update component
      {:ok, updated_state} = ComponentManager.update(component_id, :increment)
      assert updated_state.counter == 1

      # Verify state was updated in manager
      updated_data = ComponentManager.get_component(component_id)
      assert updated_data.state.counter == 1
    end

    test 'update queues component for render' do
      {:ok, component_id} = ComponentManager.mount(TestComponent)

      # Clear render queue
      ComponentManager.get_render_queue()

      # Update component
      {:ok, _} = ComponentManager.update(component_id, :increment)

      # Verify component is in render queue
      render_queue = ComponentManager.get_render_queue()
      assert component_id in render_queue
    end

    test 'update returns error for unknown component' do
      assert {:error, :not_found} =
               ComponentManager.update("unknown_component", :increment)
    end

    test 'update handles component errors gracefully' do
      defmodule ErrorComponent do
        def init(_props), do: {:ok, %{error_count: 0}}
        def mount(state), do: {state, []}
        def update(:trigger_error, state), do: raise("Test error")
        def update(_msg, state), do: {state, []}
      end

      {:ok, component_id} = ComponentManager.mount(ErrorComponent)

      # Attempt to trigger an error
      assert {:error, :component_error} =
               ComponentManager.update(component_id, :trigger_error)

      # Verify component remains in a valid state
      component_data = ComponentManager.get_component(component_id)
      assert component_data != nil
      assert component_data.state.error_count == 0
    end

    test 'update handles invalid return values' do
      defmodule InvalidReturnComponent do
        def init(_props), do: {:ok, %{}}
        def mount(state), do: {state, []}
        def update(_msg, _state), do: :invalid_return
      end

      {:ok, component_id} = ComponentManager.mount(InvalidReturnComponent)

      # Attempt update with invalid return
      assert {:error, :invalid_component_return} =
               ComponentManager.update(component_id, :any_message)

      # Verify component remains in a valid state
      component_data = ComponentManager.get_component(component_id)
      assert component_data != nil
    end
  end

  describe "event dispatch" do
    test 'dispatch_event sends events to components' do
      {:ok, component_id} = ComponentManager.mount(TestComponent)

      # Dispatch event
      ComponentManager.dispatch_event({:test_event, "test_value"})

      # Wait for event processing
      assert_receive {:component_updated, ^component_id}, 100

      # Verify component state was updated
      component_data = ComponentManager.get_component(component_id)
      assert component_data.state.event_value == "test_value"

      # Verify it was queued for render
      render_queue = ComponentManager.get_render_queue()
      assert component_id in render_queue
    end
  end

  describe "render queue management" do
    test 'get_render_queue returns and clears the queue' do
      # Mount multiple components
      {:ok, component_id1} = ComponentManager.mount(TestComponent)
      {:ok, component_id2} = ComponentManager.mount(TestComponent)

      # Update components to add to render queue
      ComponentManager.update(component_id1, :increment)
      ComponentManager.update(component_id2, :increment)

      # Get render queue
      render_queue = ComponentManager.get_render_queue()

      # Verify both components are in the queue
      assert Enum.sort([component_id1, component_id2]) ==
               Enum.sort(render_queue)

      # Verify queue was cleared
      assert ComponentManager.get_render_queue() == []
    end
  end

  describe "command processing" do
    test 'handles component commands (e.g., scheduled messages)' do
      # Use standard mount
      {:ok, component_id} = ComponentManager.mount(TestComponent)

      # Manually schedule the message that mount_with_commands would have
      Process.send_after(
        ComponentManager,
        {:update, component_id, :delayed_message},
        50
      )

      # Wait for delayed message to be processed
      assert_receive {:component_updated, ^component_id}, 150

      # Verify the component received the delayed message via update
      final_component_data = ComponentManager.get_component(component_id)
      assert final_component_data.state.last_message == :delayed_message
    end

    test 'handles broadcast commands' do
      # Mount multiple components
      {:ok, component_id1} = ComponentManager.mount(TestComponent)
      {:ok, component_id2} = ComponentManager.mount(TestComponent)

      # Update component 1 to trigger the broadcast command
      {:ok, _} = ComponentManager.update(component_id1, :trigger_broadcast)

      # Wait for broadcasting to complete
      assert_receive {:component_updated, ^component_id2}, 500

      # Verify both components received the broadcast via update
      component1 = ComponentManager.get_component(component_id1)
      component2 = ComponentManager.get_component(component_id2)

      # Component 1's last message should be the trigger, not the broadcast
      assert component1.state.last_message == :trigger_broadcast
      assert component2.state.last_message == :broadcast_message
    end
  end
end
