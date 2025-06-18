defmodule Raxol.Test.Integration.Assertions do
  @moduledoc """
  Provides custom assertions for integration testing of Raxol components.

  This module includes assertions for:
  - Component interaction verification
  - Event propagation validation
  - State synchronization checking
  - Command routing verification
  - Component lifecycle testing
  """

  import ExUnit.Assertions

  @doc """
  Asserts that a child component received an event from its parent.

  ## Example

      assert_child_received child, :parent_clicked
  """
  def assert_child_received(child_component_map, expected_event_type_atom) do
    {:messages, messages} = Process.info(self(), :messages)
    # Get the atom like Button
    child_module_expected = child_component_map.module

    received =
      Enum.any?(messages, fn
        # Match against the module atom and the event struct's type
        # {:event_dispatched, ^child_module_expected, %Raxol.Core.Events.Event{type: actual_event_type}} ->
        #   actual_event_type == expected_event_type_atom
        # More flexible match
        {:event_dispatched, mod, event_struct} ->
          mod == child_module_expected &&
            event_struct.type == expected_event_type_atom

        _ ->
          false
      end)

    assert received,
           "Expected child component #{inspect(child_module_expected)} to receive event of type #{inspect(expected_event_type_atom)}. Messages: #{inspect(messages)}"
  end

  @doc """
  Asserts that a parent component was updated in response to a child event.

  ## Example

      assert_parent_updated parent, :child_responded
  """
  def assert_parent_updated(parent_component_map, expected_event_type_atom) do
    {:messages, messages} = Process.info(self(), :messages)
    parent_module_expected = parent_component_map.module

    updated =
      Enum.any?(messages, fn
        # {:event_dispatched, ^parent_module_expected, %Raxol.Core.Events.Event{type: actual_event_type}} ->
        #   actual_event_type == expected_event_type_atom
        # More flexible match
        {:event_dispatched, mod, event_struct} ->
          mod == parent_module_expected &&
            event_struct.type == expected_event_type_atom

        _ ->
          false
      end)

    assert updated,
           "Expected parent component #{inspect(parent_module_expected)} to have handled an event of type #{inspect(expected_event_type_atom)} (indicating update). Messages: #{inspect(messages)}"
  end

  @doc """
  Asserts that components are properly connected in a hierarchy.

  ## Example

      assert_hierarchy_valid parent, [child1, child2]
  """
  def assert_hierarchy_valid(parent, children) do
    # Verify parent-child relationships
    Enum.each(children, fn child ->
      assert child.parent == parent,
             "Expected child #{inspect(child.module)} to have parent #{inspect(parent.module)}"
    end)

    # Verify children list
    assert length(parent.children) == length(children),
           "Expected parent to have #{length(children)} children, but got #{length(parent.children)}"

    Enum.each(children, fn child ->
      assert child in parent.children,
             "Expected child #{inspect(child.module)} to be in parent's children list"
    end)
  end

  @doc """
  Asserts that a component properly handles mounting and unmounting.

  ## Example

      assert_lifecycle_handled component, fn comp ->
        mount_component(comp)
        # Test mounted state
        unmount_component(comp)
        # Test unmounted state
      end
  """
  def assert_lifecycle_handled(component, lifecycle_fn) do
    try do
      lifecycle_fn.(component)

      # Verify cleanup
      assert component.subscriptions == [],
             "Expected all subscriptions to be cleaned up"

      assert not component.mounted,
             "Expected component to be unmounted"
    rescue
      error ->
        flunk("Component failed to handle lifecycle: #{inspect(error)}")
    end
  end

  @doc """
  Asserts that events are properly propagated through the component hierarchy.

  ## Example

      assert_event_propagation [parent, child1, child2], event, fn components ->
        # Verify each component's response
      end
  """
  def assert_event_propagation(components, event, verification_fn)
      when is_list(components) do
    # Track event propagation
    ref = System.unique_integer([:positive])
    Process.put(ref, [])

    try do
      # Dispatch event to first component
      [first | _] = components
      Raxol.Test.Integration.simulate_user_action(first, event)

      # Get propagation history
      history = Process.get(ref)

      # Run verification
      verification_fn.(history)
    after
      Process.delete(ref)
    end
  end

  @doc """
  Asserts that commands are properly routed between components.

  ## Example

      assert_command_routing source, target, command
  """
  def assert_command_routing(source, target, command) do
    {:messages, messages} = Process.info(self(), :messages)

    routed =
      Enum.any?(messages, fn
        {:command_sent, ^source, ^target, ^command} -> true
        _ -> false
      end)

    assert routed,
           "Expected command #{inspect(command)} to be routed from #{inspect(source)} to #{inspect(target)}"
  end

  @doc """
  Asserts that component state is synchronized after interactions.

  ## Example

      assert_state_synchronized [comp1, comp2], fn states ->
        Enum.all?(states, & &1.counter == 0)
      end
  """
  def assert_state_synchronized(components, state_check)
      when is_list(components) do
    states = Enum.map(components, & &1.state)

    assert state_check.(states),
           "Expected component states to be synchronized"
  end

  @doc """
  Asserts that a component handles system events without corruption.

  ## Example

      assert_system_events_handled component, [:resize, :focus, :blur]
  """
  def assert_system_events_handled(component, events) when is_list(events) do
    Enum.each(events, fn event ->
      {updated, initial, _commands} =
        Raxol.Test.Integration.assert_handles_system_event(component, event)

      assert updated.state != nil,
             "Expected component to maintain valid state after #{inspect(event)}"

      assert Map.keys(updated.state) == Map.keys(initial),
             "Expected component state structure to remain consistent"
    end)
  end

  @doc """
  Asserts that error boundaries contain component failures.

  ## Example

      assert_error_contained parent, child, fn ->
        simulate_user_action(child, :trigger_error)
      end
  """
  def assert_error_contained(parent, child, error_fn) do
    parent_state = parent.state

    try do
      error_fn.()
      flunk("Expected error to be raised")
    rescue
      _ ->
        # Verify parent remained stable
        assert parent.state == parent_state,
               "Expected parent state to remain unchanged after child error"

        # Verify child was handled
        assert child.state != nil,
               "Expected child to maintain valid state after error"
    end
  end
end
