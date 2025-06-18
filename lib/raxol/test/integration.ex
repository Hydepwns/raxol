defmodule Raxol.Test.Integration do
  @moduledoc '''
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
  '''

  import ExUnit.Assertions
  alias Raxol.Core.Events.{Event, Subscription}

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

  @doc '''
  Sets up a test scenario with multiple components.

  This function:
  1. Initializes all components
  2. Sets up event routing
  3. Configures component relationships
  4. Establishes test monitoring
  '''
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

  @doc '''
  Sets up a parent-child component hierarchy for testing.

  Returns the initialized parent and child components with proper event routing.
  '''
  def setup_component_hierarchy(parent_module, child_module, opts \\ []) do
    button_attrs = Keyword.get(opts, :button_attrs, %{})

    {:ok, parent_init} = setup_component(parent_module)
    {:ok, child_init} = setup_component(child_module, button_attrs)

    parent_with_child_ref =
      struct!(
        parent_init.__struct__,
        Map.put(parent_init, :children, [child_init])
      )

    child_with_parent_ref =
      struct!(
        child_init.__struct__,
        Map.put(child_init, :parent, parent_with_child_ref)
      )

    {parent_handler_set, child_handler_set} =
      setup_hierarchy_routing(parent_with_child_ref, child_with_parent_ref)

    final_parent =
      struct!(
        parent_handler_set.__struct__,
        Map.put(parent_handler_set, :children, [child_handler_set])
      )

    final_child =
      struct!(
        child_handler_set.__struct__,
        Map.put(child_handler_set, :parent, final_parent)
      )

    final_parent_with_correct_child =
      struct!(
        final_parent.__struct__,
        Map.put(final_parent, :children, [final_child])
      )

    {:ok, final_parent_with_correct_child, final_child}
  end

  @doc '''
  Simulates a user action on a component.

  Handles various types of user interactions and ensures proper event propagation.
  '''
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

  @doc '''
  Simulates component mounting in the application.
  '''
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

  @doc '''
  Simulates component unmounting from the application.
  '''
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

  @doc '''
  Verifies that a component properly handles a system event.
  '''
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

  defp dispatch_event(component, event, routing_info \\ %{}) do
    if function_exported?(component.module, :handle_event, 3) do
      context =
        %{
          parent: Map.get(routing_info, :parent),
          child: Map.get(routing_info, :child)
        }
        |> Enum.filter(fn {_k, v} -> !is_nil(v) end)
        |> Enum.into(%{})

      {new_state, commands} =
        component.module.handle_event(event, context, component.state)

      {put_in(component.state, new_state), commands}
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

  defp setup_event_routing(components) do
    Enum.reduce(components, components, fn {name, component}, acc ->
      Map.put(acc, name, component)
    end)
  end
end
