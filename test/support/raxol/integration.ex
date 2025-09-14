defmodule Raxol.Test.Integration do
  @moduledoc """
  Provides utilities for testing component interactions and system integration.

  This module focuses on testing:
  - Multi-component interactions
  - Event propagation between components
  - State synchronization
  - Terminal I/O simulation
  - Component hierarchy behavior

  ## Example

      defmodule MyApp.IntegrationTest do
        use ExUnit.Case
        use Raxol.Test.Integration

        test_scenario "parent-child communication", %{parent: Parent, child: Child} do
          # Set up component hierarchy
          {:ok, parent, child} = setup_component_hierarchy(Parent, Child)

          # Simulate user interaction
          simulate_user_action(parent, {:click, {10, 10}})

          # Verify component interaction
          assert_child_received(child, :parent_clicked)
          assert_parent_updated(parent, :child_responded)
        end
      end
  """

  # Delegation to focused modules
  alias Raxol.Test.Integration.{
    HierarchySetup,
    EventSimulation,
    ComponentManagement
  }

  defmacro __using__(_opts) do
    quote do
      import Raxol.Test.Integration
      import Raxol.Test.Integration.Assertions
    end
  end

  defmacro test_scenario(name, components, do: block) do
    quote do
      test unquote(name) do
        {:ok, components} = setup_test_scenario(unquote(components))
        var!(components) = components
        unquote(block)
      end
    end
  end

  @doc """
  Sets up a test scenario with multiple components.

  This function:
  1. Initializes all components
  2. Sets up event routing
  3. Configures component relationships
  4. Establishes test monitoring
  """
  def setup_test_scenario(components) when is_map(components) do
    ComponentManagement.setup_test_scenario(components)
  end

  @doc """
  Sets up a parent-child component hierarchy for testing.

  Returns the initialized parent and child test component structs with proper event routing.
  """
  def setup_component_hierarchy(a, b, opts \\ [])

  def setup_component_hierarchy(parent_module, child_modules, opts)
      when is_atom(parent_module) and is_list(child_modules) do
    HierarchySetup.setup_component_hierarchy(parent_module, child_modules, opts)
  end

  def setup_component_hierarchy(parent_module, child_module, opts)
      when is_atom(parent_module) and is_atom(child_module) do
    HierarchySetup.setup_component_hierarchy(parent_module, child_module, opts)
  end

  def setup_component_hierarchy(parent_struct, child_structs, opts)
      when is_map(parent_struct) and is_list(child_structs) do
    HierarchySetup.setup_component_hierarchy(parent_struct, child_structs, opts)
  end

  def setup_component_hierarchy(parent_struct, child_struct, opts)
      when is_map(parent_struct) and is_map(child_struct) do
    HierarchySetup.setup_component_hierarchy(parent_struct, child_struct, opts)
  end

  @doc """
  Sets up a parent-child component hierarchy and mounts components in ComponentManager.

  This is a convenience function that combines setup_component_hierarchy with mounting.
  """
  def setup_component_hierarchy_with_mounting(
        parent_module,
        child_modules,
        opts \\ []
      )

  def setup_component_hierarchy_with_mounting(
        parent_module,
        child_modules,
        opts
      )
      when is_list(child_modules) do
    HierarchySetup.setup_component_hierarchy_with_mounting(
      parent_module,
      child_modules,
      opts
    )
  end

  def setup_component_hierarchy_with_mounting(parent_module, child_module, opts) do
    HierarchySetup.setup_component_hierarchy_with_mounting(
      parent_module,
      child_module,
      opts
    )
  end

  @doc """
  Simulates a user action on a component.

  Handles various types of user interactions and ensures proper event propagation.
  """
  def simulate_user_action(component, action) do
    EventSimulation.simulate_user_action(component, action)
  end

  @doc """
  Simulates component mounting in the application.
  """
  def mount_component(component, parent \\ nil) do
    ComponentManagement.mount_component(component, parent)
  end

  @doc """
  Simulates component unmounting from the application.
  """
  def unmount_component(component) do
    ComponentManagement.unmount_component(component)
  end

  @doc """
  Verifies that a component properly handles a system event.
  """
  def assert_handles_system_event(component, event) do
    EventSimulation.assert_handles_system_event(component, event)
  end

  @doc """
  Simulates an event on a component and updates the ComponentManager state.

  This is the integration-style version that ensures state changes are reflected
  in the ComponentManager, not just the local struct.
  """
  def simulate_event_with_manager_update(component, event) do
    EventSimulation.simulate_event_with_manager_update(component, event)
  end

  @doc """
  Simulates a broadcast event from parent to children.

  This handles the case where a parent component needs to send events to all its children.
  """
  def simulate_broadcast_event(parent, event_type, event_data \\ %{}) do
    EventSimulation.simulate_broadcast_event(parent, event_type, event_data)
  end
end
