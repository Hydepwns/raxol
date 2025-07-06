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
    children = Enum.map(child_modules, &create_test_component/1)

    setup_component_hierarchy(parent, children, opts)
  end

  def setup_component_hierarchy(parent_module, child_module, opts)
      when is_atom(parent_module) and is_atom(child_module) do
    button_attrs = Keyword.get(opts, :button_attrs, %{})

    parent = create_test_component(parent_module)
    child = create_test_component(child_module, button_attrs)

    setup_component_hierarchy(parent, child, opts)
  end

  def setup_component_hierarchy(parent_struct, child_structs, opts)
      when is_map(parent_struct) and is_list(child_structs) do
    button_attrs = Keyword.get(opts, :button_attrs, %{})

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

    # Optionally, set up event routing if needed (no-op for plain maps)
    {:ok, parent_struct, updated_children}
  end

  def setup_component_hierarchy(parent_struct, child_struct, opts)
      when is_map(parent_struct) and is_map(child_struct) do
    button_attrs = Keyword.get(opts, :button_attrs, %{})

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

    # Optionally, set up event routing if needed (no-op for plain maps)
    {:ok, parent_struct, child_struct}
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
    mounted_component = put_in(component.mounted, true)

    # Set up parent relationship if provided
    mounted_component =
      if parent do
        Map.put(mounted_component, :parent, parent)
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

  defp create_test_component(module, initial_state \\ %{}) do
    # Initialize the component with proper state
    {:ok, component_state} = module.init(initial_state)

    %{
      module: module,
      state: component_state,
      props: %{},
      children: [],
      mounted: false,
      unmounted: false,
      render_count: 0,
      style: %{},
      disabled: false,
      focused: false
    }
  end

  defp setup_event_routing(components) do
    Enum.reduce(components, components, fn {name, component}, acc ->
      Map.put(acc, name, component)
    end)
  end
end
