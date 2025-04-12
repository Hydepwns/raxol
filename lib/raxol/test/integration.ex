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
  alias Raxol.Test.TestHelper

  defmacro __using__(_opts) do
    quote do
      import Raxol.Test.Integration
      import Raxol.Test.Integration.Assertions

      setup do
        context = TestHelper.setup_test_env()
        {:ok, context}
      end

      teardown do
        TestHelper.cleanup_test_env(context)
      end
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

  Returns the initialized parent and child components with proper event routing.
  """
  def setup_component_hierarchy(parent_module, child_module, _opts \\ []) do
    # Initialize parent and child
    {:ok, parent} = setup_component(parent_module)
    {:ok, child} = setup_component(child_module)

    # Configure parent-child relationship
    parent = put_in(parent.children, [child])
    child = put_in(child.parent, parent)

    # Set up event routing
    {parent, child} = setup_hierarchy_routing(parent, child)

    {:ok, parent, child}
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
      events when is_list(events) ->
        Enum.each(events, &dispatch_event(component, &1))

      event ->
        dispatch_event(component, event)
    end
  end

  @doc """
  Simulates component mounting in the application.
  """
  def mount_component(component, parent \\ nil) do
    # Initialize mount state
    mounted_component = put_in(component.mounted, true)

    # Set up parent relationship if provided
    mounted_component =
      if parent do
        put_in(mounted_component.parent, parent)
      else
        mounted_component
      end

    # Trigger mount callbacks
    if function_exported?(component.module, :mount, 1) do
      {new_state, _commands} = component.module.mount(mounted_component.state)
      put_in(mounted_component.state, new_state)
    else
      mounted_component
    end
  end

  @doc """
  Simulates component unmounting from the application.
  """
  def unmount_component(component) do
    # Trigger unmount callbacks
    if function_exported?(component.module, :unmount, 1) do
      component.module.unmount(component.state)
    end

    # Clean up subscriptions
    Enum.each(component.subscriptions, &Subscription.unsubscribe(&1))

    # Reset mount state
    %{component | mounted: false, subscriptions: []}
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

  # Private Helpers

  defp setup_component(module) do
    {:ok, component} = Raxol.Test.Unit.setup_isolated_component(module)

    component =
      Map.merge(component, %{
        mounted: false,
        parent: nil,
        children: [],
        event_queue: :queue.new()
      })

    {:ok, component}
  end

  defp setup_event_routing(components) do
    # Set up event routing between components
    Enum.reduce(components, components, fn {name, component}, acc ->
      routed_component = setup_component_routing(component, acc)
      Map.put(acc, name, routed_component)
    end)
  end

  defp setup_component_routing(component, components) do
    event_handler = fn event ->
      # Route event to appropriate handlers
      handle_routed_event(component, event, components)
    end

    %{component | event_handler: event_handler}
  end

  defp setup_hierarchy_routing(parent, child) do
    parent_handler = fn event ->
      # Handle parent events and propagate to child
      handle_parent_event(parent, child, event)
    end

    child_handler = fn event ->
      # Handle child events and bubble to parent
      handle_child_event(parent, child, event)
    end

    {%{parent | event_handler: parent_handler},
     %{child | event_handler: child_handler}}
  end

  defp dispatch_event(component, event) do
    result = component.event_handler.(event)
    send(self(), {:event_dispatched, component.module, event})
    result
  end

  defp handle_routed_event(component, event, components) do
    # Handle event based on routing rules
    {new_state, commands} =
      component.module.handle_event(event, component.state)

    # Update component state
    updated_component = %{component | state: new_state}

    # Process commands and route to other components
    process_commands(updated_component, commands, components)
  end

  defp handle_parent_event(parent, child, event) do
    # Handle parent event
    {new_state, commands} = parent.module.handle_event(event, parent.state)

    # Update parent state
    updated_parent = %{parent | state: new_state}

    # Process commands and propagate to child
    process_commands(updated_parent, commands, %{child: child})
  end

  defp handle_child_event(parent, child, event) do
    # Handle child event
    {new_state, commands} = child.module.handle_event(event, child.state)

    # Update child state
    updated_child = %{child | state: new_state}

    # Process commands and bubble to parent
    process_commands(updated_child, commands, %{parent: parent})
  end

  defp process_commands(component, commands, components) do
    Enum.reduce(commands, {component, []}, fn command,
                                              {acc_component, acc_commands} ->
      case command do
        {:propagate, event} ->
          target_component = find_target_component(event, components)

          if target_component do
            {_updated_target, target_commands} =
              propagate_to_children(target_component, event, [])

            {acc_component, acc_commands ++ target_commands}
          else
            {acc_component, acc_commands}
          end

        {:bubble, event} ->
          if component.parent do
            {_updated_parent, parent_commands} =
              bubble_to_parent(component.parent, event, [])

            {acc_component, acc_commands ++ parent_commands}
          else
            {acc_component, acc_commands}
          end

        _ ->
          {acc_component, acc_commands ++ [command]}
      end
    end)
  end

  defp find_target_component(event, components) do
    case event do
      %{target: target} when is_atom(target) ->
        Map.get(components, target)

      _ ->
        nil
    end
  end

  defp propagate_to_children(component, event, acc) do
    Enum.reduce(component.children, {component, acc}, fn child,
                                                         {acc_component,
                                                          acc_commands} ->
      {_updated_child, child_commands} = dispatch_event(child, event)
      {acc_component, acc_commands ++ child_commands}
    end)
  end

  defp bubble_to_parent(component, event, acc) do
    {updated_component, commands} = dispatch_event(component, event)
    {updated_component, acc ++ commands}
  end
end
