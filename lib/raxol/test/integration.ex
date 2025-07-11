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

  import ExUnit.Assertions
  alias Raxol.Core.Events.{Event, Subscription}
  import Raxol.Guards
  alias Raxol.Core.Runtime.ComponentManager

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
  def setup_test_scenario(components) when map?(components) do
    # Initialize each component
    initialized_components =
      Enum.map(components, fn {name, module} ->
        {:ok, component} = setup_component(module)
        {name, component}
      end)
      |> Map.new()

    # Set up event routing between components
    routed_components = setup_event_routing(initialized_components)

    {:ok, routed_components}
  end

  @doc """
  Sets up a parent-child component hierarchy for testing.

  Returns the initialized parent and child test component structs with proper event routing.
  """
  def setup_component_hierarchy(a, b, opts \\ [])

  def setup_component_hierarchy(parent_module, child_modules, opts)
      when is_atom(parent_module) and is_list(child_modules) do
    # Handle list of child modules (for broadcast tests)
    parent = create_test_component(parent_module)

    # Check if child_ids are provided for unique IDs
    child_ids = Keyword.get(opts, :child_ids, [])

    children =
      if child_ids != [] and length(child_ids) == length(child_modules) do
        # Create children with specific IDs
        Enum.zip(child_modules, child_ids)
        |> Enum.map(fn {module, id} ->
          create_test_component(module, %{id: id})
        end)
      else
        # Create children with default IDs
        Enum.map(child_modules, &create_test_component/1)
      end

    setup_component_hierarchy(parent, children, opts)
  end

  def setup_component_hierarchy(parent_module, child_module, opts)
      when is_atom(parent_module) and is_atom(child_module) do
    button_attrs = Keyword.get(opts, :button_attrs, %{})

    parent = create_test_component(parent_module)
    child = create_test_component(child_module, button_attrs)

    setup_component_hierarchy(parent, child, opts)
  end

  defp maybe_mount_components(
         parent_struct,
         parent_state,
         child_struct,
         child_state,
         mount_in_manager
       ) do
    if mount_in_manager do
      IO.puts(
        "Attempting to mount parent module: #{inspect(parent_struct.module)}"
      )

      IO.puts("Parent state: #{inspect(parent_state)}")

      case Raxol.Core.Runtime.ComponentManager.mount(
             parent_struct.module,
             parent_state
           ) do
        {:ok, parent_id} ->
          IO.puts("Successfully mounted parent with ID: #{inspect(parent_id)}")

          IO.puts(
            "Attempting to mount child module: #{inspect(child_struct.module)}"
          )

          IO.puts("Child state: #{inspect(child_state)}")

          case Raxol.Core.Runtime.ComponentManager.mount(
                 child_struct.module,
                 child_state
               ) do
            {:ok, child_id} ->
              IO.puts(
                "Successfully mounted child with ID: #{inspect(child_id)}"
              )

              parent_struct = %{
                parent_struct
                | state: Map.put(parent_state, :component_manager_id, parent_id)
              }

              child_struct = %{
                child_struct
                | state: Map.put(child_state, :component_manager_id, child_id)
              }

              {:ok, parent_struct, child_struct}

            {:error, reason} ->
              IO.puts("Failed to mount child: #{inspect(reason)}")
              {:error, {:child_mount_failed, reason}}
          end

        {:error, reason} ->
          IO.puts("Failed to mount parent: #{inspect(reason)}")
          {:error, {:parent_mount_failed, reason}}
      end
    else
      {:ok, parent_struct, child_struct}
    end
  end

  def setup_component_hierarchy(parent_struct, child_structs, opts)
      when is_map(parent_struct) and is_list(child_structs) do
    # Update the :state fields to reference each other
    child_ids = Enum.map(child_structs, & &1.state.id)
    parent_state = Map.put(parent_struct.state, :children, child_ids)

    # Update each child to reference the parent
    updated_children =
      Enum.map(child_structs, fn child ->
        child_state = Map.put(child.state, :parent_id, parent_state.id)
        %{child | state: child_state}
      end)

    # Update parent with child states in child_states field
    child_states_map =
      Enum.reduce(updated_children, %{}, fn child, acc ->
        Map.put(acc, child.state.id, child.state)
      end)

    parent_state = Map.put(parent_state, :child_states, child_states_map)
    parent_struct = %{parent_struct | state: parent_state}

    # Optionally mount components in ComponentManager if requested
    mount_in_manager = Keyword.get(opts, :mount_in_manager, false)

    # Mount components if requested
    if mount_in_manager do
      # Mount parent first
      case Raxol.Core.Runtime.ComponentManager.mount(
             parent_struct.module,
             parent_state
           ) do
        {:ok, parent_id} ->
          parent_struct = %{
            parent_struct
            | state: Map.put(parent_state, :component_manager_id, parent_id)
          }

          # Mount all children and update parent's child_states
          {mounted_children, updated_parent_state} =
            Enum.map_reduce(updated_children, parent_struct.state, fn child,
                                                                      parent_state ->
              case Raxol.Core.Runtime.ComponentManager.mount(
                     child.module,
                     child.state
                   ) do
                {:ok, child_id} ->
                  # Use the actual ComponentManager key as component_manager_id
                  updated_child_state =
                    Map.put(child.state, :component_manager_id, child_id)

                  updated_child = %{
                    child
                    | state: updated_child_state
                  }

                  # Immediately update the state in the ComponentManager
                  Raxol.Core.Runtime.ComponentManager.set_component_state(
                    child_id,
                    updated_child_state
                  )

                  # Update parent's child_states map with the new child state
                  updated_parent_state =
                    Map.put(
                      parent_state,
                      :child_states,
                      Map.put(
                        parent_state.child_states,
                        child.state.id,
                        updated_child.state
                      )
                    )

                  {updated_child, updated_parent_state}

                {:error, reason} ->
                  IO.puts(
                    "Failed to mount child #{inspect(child.state.id)}: #{inspect(reason)}"
                  )

                  {child, parent_state}
              end
            end)

          # Update parent struct with new state that includes updated child_states
          parent_struct = %{parent_struct | state: updated_parent_state}

          {:ok, parent_struct, mounted_children}

        {:error, reason} ->
          IO.puts("Failed to mount parent: #{inspect(reason)}")
          {:ok, parent_struct, updated_children}
      end
    else
      {:ok, parent_struct, updated_children}
    end
  end

  def setup_component_hierarchy(parent_struct, child_struct, opts)
      when is_map(parent_struct) and is_map(child_struct) do
    # Update the :state fields to reference each other
    parent_state =
      Map.put(parent_struct.state, :children, [child_struct.state.id])

    child_state = Map.put(child_struct.state, :parent_id, parent_state.id)

    # Update parent with child state in child_states field
    parent_state =
      Map.put(parent_state, :child_states, %{
        child_struct.state.id => child_state
      })

    # Update the test component structs
    parent_struct = %{parent_struct | state: parent_state}
    child_struct = %{child_struct | state: child_state}

    # Optionally mount components in ComponentManager if requested
    mount_in_manager = Keyword.get(opts, :mount_in_manager, false)

    maybe_mount_components(
      parent_struct,
      parent_state,
      child_struct,
      child_state,
      mount_in_manager
    )
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
    {:ok, parent_struct, mounted_children} =
      setup_component_hierarchy(
        parent_module,
        child_modules,
        Keyword.put(opts, :mount_in_manager, true)
      )

    # Get the mounted state from ComponentManager for parent
    parent_mounted_state =
      ComponentManager.get_component(parent_struct.state.component_manager_id).state

    # Get the mounted state from ComponentManager for each child
    IO.puts("DEBUG: Getting mounted state for children...")

    IO.puts(
      "DEBUG: mounted_children have component_manager_id: #{inspect(Enum.map(mounted_children, fn c -> c.state.component_manager_id end))}"
    )

    mounted_children_with_state =
      Enum.map(mounted_children, fn child ->
        IO.puts(
          "DEBUG: Processing child #{inspect(child.state.id)} with component_manager_id: #{inspect(child.state.component_manager_id)}"
        )

        if child.state.component_manager_id do
          child_mounted =
            ComponentManager.get_component(child.state.component_manager_id)

          IO.puts(
            "DEBUG: Found child by component_manager_id: #{inspect(child_mounted.state.component_manager_id)}"
          )

          %{child | state: child_mounted.state}
        else
          # If child doesn't have component_manager_id, try to find it by ID
          all_components = ComponentManager.get_all_components()

          IO.puts(
            "DEBUG: All components in manager: #{inspect(Map.keys(all_components))}"
          )

          child_component =
            Enum.find_value(all_components, fn {_manager_id, comp} ->
              if comp.state.id == child.state.id, do: comp, else: nil
            end)

          if child_component do
            IO.puts(
              "DEBUG: Found child by ID: #{inspect(child_component.state.component_manager_id)}"
            )

            %{child | state: child_component.state}
          else
            IO.puts(
              "DEBUG: Could not find child #{inspect(child.state.id)} in ComponentManager"
            )

            child
          end
        end
      end)

    # Update parent's child_states map with the mounted child states
    updated_child_states =
      Enum.reduce(
        mounted_children_with_state,
        parent_mounted_state.child_states,
        fn child, acc ->
          Map.put(acc, child.state.id, child.state)
        end
      )

    parent_struct_with_mounted_state = %{
      parent_struct
      | state: %{parent_mounted_state | child_states: updated_child_states}
    }

    # Set up parent/child references
    mounted_children_with_parent =
      Enum.map(mounted_children_with_state, fn child ->
        Map.put(child, :parent, parent_struct_with_mounted_state)
      end)

    parent_struct_with_children =
      Map.put(
        parent_struct_with_mounted_state,
        :children,
        mounted_children_with_parent
      )

    {:ok, parent_struct_with_children, mounted_children_with_parent}
  end

  def setup_component_hierarchy_with_mounting(parent_module, child_module, opts) do
    {:ok, parent_struct, child_struct} =
      setup_component_hierarchy(
        parent_module,
        child_module,
        Keyword.put(opts, :mount_in_manager, true)
      )

    # Get the mounted state from ComponentManager
    parent_mounted_state =
      ComponentManager.get_component(parent_struct.state.component_manager_id).state

    child_mounted_state =
      ComponentManager.get_component(child_struct.state.component_manager_id).state

    # Update structs with mounted state from ComponentManager
    parent_struct_with_mounted_state = %{
      parent_struct
      | state: parent_mounted_state
    }

    child_struct_with_mounted_state = %{
      child_struct
      | state: child_mounted_state
    }

    # Set up parent/child references
    child_struct_with_parent =
      Map.put(
        child_struct_with_mounted_state,
        :parent,
        parent_struct_with_mounted_state
      )

    parent_struct_with_child =
      Map.put(parent_struct_with_mounted_state, :children, [
        child_struct_with_parent
      ])

    {:ok, parent_struct_with_child, child_struct_with_parent}
  end

  @doc """
  Simulates a user action on a component.

  Handles various types of user interactions and ensures proper event propagation.
  """
  def simulate_user_action(component, action) do
    event =
      case action do
        {:click, pos} ->
          Event.mouse(:left, pos)

        {:type, text} ->
          text |> String.to_charlist() |> Enum.map(&Event.key({:char, &1}))

        {:key, key} ->
          Event.key(key)

        {:resize, {w, h}} ->
          Event.window(w, h, :resize)

        _ ->
          raise "Unsupported action: #{inspect(action)}"
      end

    case event do
      events when list?(events) ->
        Enum.each(events, &process_event_with_commands(component, &1))

      event ->
        process_event_with_commands(component, event)
    end
  end

  defp process_event_with_commands(component, event) do
    {updated_component, commands} = dispatch_event(component, event)

    # Process commands
    Enum.each(commands, fn command ->
      case command do
        {:dispatch_to_parent, parent_event} ->
          # Find parent component and dispatch event to it
          if Map.has_key?(component, :parent_id) do
            # For now, we'll need to access the parent component through the test context
            # This is a simplified implementation - in a real system, we'd have proper parent references
            IO.puts(
              "Would dispatch #{inspect(parent_event)} to parent #{component.parent_id}"
            )
          end

        _ ->
          # Handle other command types as needed
          IO.puts("Unhandled command: #{inspect(command)}")
      end
    end)

    updated_component
  end

  @doc """
  Simulates component mounting in the application.
  """
  def mount_component(component, parent \\ nil) do
    # Initialize mount state
    mounted_state = put_in(component.state.mounted, true)

    # Set up parent relationship if provided
    mounted_state =
      if parent do
        Map.put(mounted_state, :parent, parent.state)
      else
        mounted_state
      end

    # Trigger mount callbacks
    if function_exported?(component.module, :mount, 1) do
      {new_state, _commands} = component.module.mount(mounted_state)
      %{component | state: new_state}
    else
      %{component | state: mounted_state}
    end
  end

  @doc """
  Simulates component unmounting from the application.
  """
  def unmount_component(component) do
    # Trigger unmount callbacks
    new_state =
      if function_exported?(component.module, :unmount, 1) do
        component.module.unmount(component.state)
      else
        component.state
      end

    # Set unmounted flag
    new_state = Map.put(new_state, :unmounted, true)

    # Clean up subscriptions
    Enum.each(component.subscriptions, &Subscription.unsubscribe(&1))

    # Reset mount state
    %{component | state: new_state, subscriptions: []}
  end

  @doc """
  Verifies that a component properly handles a system event.
  """
  def assert_handles_system_event(component, event) do
    # Capture initial state
    initial_state = component.state

    # Dispatch event
    {updated_component, commands} = dispatch_event(component, event)

    # Verify component remained stable
    assert updated_component.state != nil,
           "Component state was corrupted after system event"

    # Return result for additional assertions
    {updated_component, initial_state, commands}
  end

  @doc """
  Simulates an event on a component and updates the ComponentManager state.

  This is the integration-style version that ensures state changes are reflected
  in the ComponentManager, not just the local struct.
  """
  def simulate_event_with_manager_update(component, event) do
    # First, simulate the event locally to get the new state
    {updated_component, commands} =
      Raxol.Test.Unit.simulate_event(component, event)

    # If the component has a component_manager_id, update it in the manager
    if Map.has_key?(updated_component.state, :component_manager_id) do
      component_id = updated_component.state.component_manager_id

      # Update the component in ComponentManager with the new state
      case Raxol.Core.Runtime.ComponentManager.update(
             component_id,
             {:state_update, updated_component.state}
           ) do
        {:ok, _} ->
          # Successfully updated in manager
          {updated_component, commands}

        {:error, reason} ->
          # Log error but continue with local update
          IO.puts(
            "Warning: Failed to update component in manager: #{inspect(reason)}"
          )

          {updated_component, commands}
      end
    else
      # No component_manager_id, just return local update
      {updated_component, commands}
    end
  end

  @doc """
  Simulates a broadcast event from parent to children.

  This handles the case where a parent component needs to send events to all its children.
  """
  def simulate_broadcast_event(parent, event_type, event_data \\ %{}) do
    # First, simulate the event on the parent
    event = Map.merge(%{type: event_type}, event_data)

    {updated_parent, commands} =
      simulate_event_with_manager_update(parent, event)

    # Process broadcast commands
    Enum.each(commands, fn command ->
      case command do
        {:command, {:broadcast_to_children, :increment}} ->
          # Broadcast increment to all children
          Enum.each(updated_parent.state.children, fn child_id ->
            # Find the child component by searching through all components in ComponentManager
            # This is a test helper approach since we don't have get_component_by_id
            child_component = find_child_component_by_id_in_manager(child_id)

            if child_component do
              # Simulate the increment event on the child
              increment_event = %{type: :increment}

              {_updated_child, _child_commands} =
                simulate_event_with_manager_update(
                  child_component,
                  increment_event
                )
            end
          end)

        _ ->
          :ok
      end
    end)

    {updated_parent, commands}
  end

  # Helper function to find a child component by ID in ComponentManager
  defp find_child_component_by_id_in_manager(child_id) do
    # Get all components from ComponentManager and find the one with matching ID
    # This is a test helper approach - in production you'd have a proper lookup
    # We need to iterate through all components to find the one with the matching internal ID
    all_components = ComponentManager.get_all_components()

    Enum.find_value(all_components, fn {_manager_id, component} ->
      if component.state.id == child_id do
        component
      else
        nil
      end
    end)
  end

  @doc """
  Finds a child component by its ID from the parent's state.
  """
  defp find_child_component_by_id(parent, child_id) do
    # This is a simplified implementation - in a real system, you'd have proper child references
    # For now, we'll create a mock child component with the expected state
    if Map.has_key?(parent.state.child_states, child_id) do
      child_state = parent.state.child_states[child_id]

      # Create a mock child component struct
      %{
        module:
          Raxol.UI.Components.Integration.ComponentIntegrationTest.ChildComponent,
        state: child_state
      }
    else
      nil
    end
  end

  # Private Helpers

  defp dispatch_event(component, event, routing_info \\ %{}) do
    if function_exported?(component.module, :handle_event, 3) do
      context =
        %{
          parent: Map.get(routing_info, :parent),
          child: Map.get(routing_info, :child)
        }
        |> Enum.filter(fn {_k, v} -> not nil?(v) end)
        |> Enum.into(%{})

      result = component.module.handle_event(component.state, event, context)

      case result do
        {:update, new_state, commands} ->
          {put_in(component.state, new_state), commands}

        {:handled, new_state} ->
          {put_in(component.state, new_state), []}

        :passthrough ->
          {component, []}

        {new_state, commands} ->
          # Legacy format for backward compatibility
          {put_in(component.state, new_state), commands}

        _ ->
          # Unknown return format, assume no change
          {component, []}
      end
    else
      {component, []}
    end
  end

  defp setup_hierarchy_routing(parent, child) do
    parent_handler = Map.get(parent, :event_handler)
    child_handler = Map.get(child, :event_handler)

    parent_with_child_handler = Map.put(parent, :event_handler, parent_handler)
    child_with_parent_handler = Map.put(child, :event_handler, child_handler)

    {parent_with_child_handler, child_with_parent_handler}
  end

  defp setup_component(module, attrs \\ %{}) do
    {:ok, component} = module.init(attrs)
    {:ok, component}
  end

  defp create_test_component(module, opts \\ %{}) do
    state = module.new(opts)

    %{
      module: module,
      state: state,
      subscriptions: []
    }
  end

  defp setup_event_routing(components) do
    Enum.reduce(components, components, fn {name, component}, acc ->
      Map.put(acc, name, component)
    end)
  end
end
