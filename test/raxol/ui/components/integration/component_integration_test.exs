defmodule Raxol.UI.Components.Integration.ComponentIntegrationTest do
  use ExUnit.Case, async: false
  import Raxol.ComponentTestHelpers
  alias Raxol.UI.Components.Unit
  alias Raxol.UI.Components.Manager, as: ComponentManager

  # Parent component that manages child components
  defmodule ParentComponent do
    @behaviour Raxol.UI.Components.Base.Component

    def init(props) do
      Map.merge(%{
        children: [],
        events: [],
        child_states: %{},
        mounted: false,
        unmounted: false
      }, props)
    end

    def mount(state) do
      {Map.put(state, :mounted, true), []}
    end

    def update({:child_updated, child_id, new_state}, state) do
      new_state = put_in(state.child_states[child_id], new_state)
      {new_state, []}
    end

    def render(state, context) do
      {state, %{
        type: :parent,
        id: state.id,
        children: state.children,
        child_states: state.child_states,
        mounted: state.mounted,
        unmounted: state.unmounted
      }}
    end

    def handle_event(%{type: :child_event, child_id: child_id, value: value}, state) do
      new_state = %{state | events: [{child_id, value} | state.events]}
      {new_state, [{:command, {:child_event, child_id, value}}]}
    end

    def handle_event(_event, state) do
      {state, []}
    end

    def unmount(state) do
      Map.put(state, :unmounted, true)
    end
  end

  # Child component that communicates with parent
  defmodule ChildComponent do
    @behaviour Raxol.UI.Components.Base.Component

    def init(props) do
      Map.merge(%{
        value: 0,
        parent_id: nil,
        mounted: false,
        unmounted: false
      }, props)
    end

    def mount(state) do
      {Map.put(state, :mounted, true), []}
    end

    def update(:increment, state) do
      new_state = %{state | value: state.value + 1}
      {new_state, [{:command, {:notify_parent, new_state}}]}
    end

    def render(state, _context) do
      {state, %{
        type: :child,
        id: state.id,
        value: state.value,
        parent_id: state.parent_id,
        mounted: state.mounted,
        unmounted: state.unmounted
      }}
    end

    def handle_event(%{type: :click}, state) do
      new_state = %{state | value: state.value + 1}
      {new_state, [{:command, {:notify_parent, new_state}}]}
    end

    def handle_event(_event, state) do
      {state, []}
    end

    def unmount(state) do
      Map.put(state, :unmounted, true)
    end
  end

  describe "Component Hierarchy" do
    test "parent-child relationship" do
      # Set up parent and child components
      parent = create_test_component(ParentComponent)
      child = create_test_component(ChildComponent, %{parent_id: parent.state.id})

      # Set up hierarchy
      {parent, child} = Raxol.ComponentTestHelpers.setup_component_hierarchy(ParentComponent, ChildComponent)

      # Verify hierarchy
      verify_hierarchy_valid(parent, [child])
      assert child.state.parent_id == parent.state.id
    end

    test "event propagation up the hierarchy" do
      # Set up components
      parent = create_test_component(ParentComponent)
      child = create_test_component(ChildComponent, %{parent_id: parent.state.id})

      # Set up hierarchy
      {parent, child} = Raxol.ComponentTestHelpers.setup_component_hierarchy(ParentComponent, ChildComponent)

      # Simulate child event
      {updated_child, child_commands} = Unit.simulate_event(child, %{type: :click})
      assert updated_child.state.value == 1
      assert child_commands == [{:command, {:notify_parent, updated_child.state}}]

      # Store parent ID for assertion
      parent_id = parent.state.id

      # Verify parent received event
      assert_receive {:component_updated, ^parent_id}
      updated_parent = ComponentManager.get_component(parent_id)
      assert updated_parent.state.events == [{child.state.id, 1}]
    end

    test "state updates down the hierarchy" do
      # Set up components
      parent = create_test_component(ParentComponent)
      child = create_test_component(ChildComponent, %{parent_id: parent.state.id})

      # Set up hierarchy
      {parent, child} = Raxol.ComponentTestHelpers.setup_component_hierarchy(ParentComponent, ChildComponent)

      # Update child through parent
      {updated_parent, _} = Unit.simulate_event(parent, %{
        type: :child_event,
        child_id: child.state.id,
        value: 5
      })

      # Verify child state was updated
      updated_child = ComponentManager.get_component(child.state.id)
      assert updated_child.state.value == 5
    end
  end

  describe "Component Communication" do
    test "broadcast events" do
      # Set up multiple components
      parent = create_test_component(ParentComponent)
      child1 = create_test_component(ChildComponent, %{parent_id: parent.state.id})
      child2 = create_test_component(ChildComponent, %{parent_id: parent.state.id})

      # Set up hierarchy
      {parent, [child1, child2]} = Raxol.ComponentTestHelpers.setup_component_hierarchy(ParentComponent, [ChildComponent, ChildComponent])

      # Simulate broadcast event
      {updated_parent, _} = Unit.simulate_event(parent, %{
        type: :broadcast,
        value: :increment
      })

      # Verify all children received the event
      updated_child1 = ComponentManager.get_component(child1.state.id)
      updated_child2 = ComponentManager.get_component(child2.state.id)
      assert updated_child1.state.value == 1
      assert updated_child2.state.value == 1
    end

    test "component state synchronization" do
      # Set up components
      parent = create_test_component(ParentComponent)
      child = create_test_component(ChildComponent, %{parent_id: parent.state.id})

      # Set up hierarchy
      {parent, child} = Raxol.ComponentTestHelpers.setup_component_hierarchy(ParentComponent, ChildComponent)

      # Update child state
      {updated_child, _} = Unit.simulate_event(child, %{type: :click})

      # Verify parent state was synchronized
      updated_parent = ComponentManager.get_component(parent.state.id)
      assert updated_parent.state.child_states[child.state.id] == updated_child.state
    end
  end

  describe "Component Lifecycle in Hierarchy" do
    test "mounting order" do
      # Set up components
      parent = create_test_component(ParentComponent)
      child = create_test_component(ChildComponent, %{parent_id: parent.state.id})

      # Set up hierarchy
      {parent, child} = Raxol.ComponentTestHelpers.setup_component_hierarchy(ParentComponent, ChildComponent)

      # Mount components
      mounted_parent = mount_component(parent)
      mounted_child = mount_component(child, mounted_parent)

      # Verify mounting order
      assert mounted_parent.state.mounted
      assert mounted_child.state.mounted
      assert mounted_child.state.parent_id == mounted_parent.state.id
    end

    test "unmounting order" do
      # Set up components
      parent = create_test_component(ParentComponent)
      child = create_test_component(ChildComponent, %{parent_id: parent.state.id})

      # Set up hierarchy
      {parent, child} = Raxol.ComponentTestHelpers.setup_component_hierarchy(ParentComponent, ChildComponent)

      # Mount components
      mounted_parent = mount_component(parent)
      mounted_child = mount_component(child, mounted_parent)

      # Unmount components
      unmounted_child = unmount_component(mounted_child)
      unmounted_parent = unmount_component(mounted_parent)

      # Verify unmounting order
      assert unmounted_child.state.unmounted
      assert unmounted_parent.state.unmounted
    end
  end

  describe "Error Handling in Hierarchy" do
    test "handles child errors gracefully" do
      # Set up components
      parent = create_test_component(ParentComponent)
      child = create_test_component(ChildComponent, %{parent_id: parent.state.id})

      # Set up hierarchy
      {parent, child} = Raxol.ComponentTestHelpers.setup_component_hierarchy(ParentComponent, ChildComponent)

      # Simulate child error
      {updated_child, _} = Unit.simulate_event(child, %{type: :error_event})

      # Verify parent remains stable
      updated_parent = ComponentManager.get_component(parent.state.id)
      assert updated_parent.state == parent.state
    end

    test "handles parent errors gracefully" do
      # Set up components
      parent = create_test_component(ParentComponent)
      child = create_test_component(ChildComponent, %{parent_id: parent.state.id})

      # Set up hierarchy
      {parent, child} = Raxol.ComponentTestHelpers.setup_component_hierarchy(ParentComponent, ChildComponent)

      # Simulate parent error
      {updated_parent, _} = Unit.simulate_event(parent, %{type: :error_event})

      # Verify child remains stable
      updated_child = ComponentManager.get_component(child.state.id)
      assert updated_child.state == child.state
    end
  end

  # Helper function to validate parent-child relationships
  defp assert_hierarchy_valid(parent, children) do
    # Verify parent has correct children
    assert parent.state.children == Enum.map(children, & &1.state.id)

    # Verify each child has correct parent
    Enum.each(children, fn child ->
      assert child.state.parent_id == parent.state.id
    end)
  end

  defp verify_hierarchy_valid(parent, children) do
    assert parent.state.children == Enum.map(children, & &1.state.id)
    Enum.each(children, fn child ->
      assert child.state.parent_id == parent.state.id
    end)
  end
end
