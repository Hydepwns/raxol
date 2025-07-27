defmodule Raxol.Test.Integration.EventSimulation do
  @moduledoc """
  Handles event simulation for integration testing.

  This module provides functions for:
  - Simulating user actions (clicks, typing, key presses)
  - Processing events with commands
  - Broadcasting events between components
  - Managing event propagation in component hierarchies
  """

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Runtime.ComponentManager
  import Raxol.Guards
  import ExUnit.Assertions

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

      # Update the component in ComponentManager with the new state using set_component_state
      case ComponentManager.set_component_state(
             component_id,
             updated_component.state
           ) do
        :ok ->
          # Process commands for parent notification
          Enum.each(commands, fn
            {:command, {:notify_parent, updated_child_state}} ->
              parent_id = updated_child_state.parent_id
              child_id = updated_child_state.id
              value = updated_child_state.value

              # Find parent in ComponentManager
              parent_component =
                if parent_id do
                  ComponentManager.get_all_components()
                  |> Enum.find_value(fn {_id, comp} ->
                    if comp.state.id == parent_id, do: comp, else: nil
                  end)
                else
                  nil
                end

              if parent_component do
                # Simulate :child_event on parent
                {updated_parent, _parent_cmds} =
                  Raxol.Test.Unit.simulate_event(parent_component, %{
                    type: :child_event,
                    child_id: child_id,
                    value: value
                  })

                # Update parent in ComponentManager
                if Map.has_key?(updated_parent.state, :component_manager_id) do
                  ComponentManager.set_component_state(
                    updated_parent.state.component_manager_id,
                    updated_parent.state
                  )
                end
              end

            _ ->
              :ok
          end)

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

  # Private helper functions

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
end
