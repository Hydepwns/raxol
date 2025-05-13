defmodule Raxol.ComponentTestHelpers do
  @moduledoc """
  Enhanced test helpers for comprehensive component testing in Raxol.

  This module provides utilities for:
  - Lifecycle testing
  - State management testing
  - Event handling testing
  - Rendering validation
  - Performance testing
  - Accessibility testing
  """

  import ExUnit.Assertions
  alias Raxol.Core.Events.Event
  alias Raxol.Test.Unit
  alias Raxol.UI.Components.Manager, as: ComponentManager

  @doc """
  Creates a test component with configurable initial state and options.
  """
  def create_test_component(module, props \\ %{}) do
    id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    state = module.init(Map.merge(%{id: id}, props))
    {state, _} = module.mount(state)
    %{module: module, state: state}
  end

  @doc """
  Simulates a complete component lifecycle sequence.
  """
  def simulate_lifecycle(component, lifecycle_fn) do
    # Mount
    mounted = mount_component(component)

    # Execute lifecycle function
    result = lifecycle_fn.(mounted)

    # Unmount
    unmounted = unmount_component(result)

    # Return final state and lifecycle events
    {unmounted, get_lifecycle_events(unmounted)}
  end

  @doc """
  Simulates a series of events in sequence.
  """
  def simulate_event_sequence(component, events) do
    Enum.reduce(events, component, fn event, acc ->
      {updated, _commands} = Unit.simulate_event(acc, event)
      updated
    end)
  end

  @doc """
  Validates component rendering with various contexts.
  """
  def validate_rendering(component, contexts) do
    Enum.map(contexts, fn context ->
      {_updated, rendered} = component.module.render(component.state, context)
      rendered
    end)
  end

  @doc """
  Measures component performance with a given workload.
  """
  def measure_performance(component, workload_fn, iterations \\ 100) do
    start_time = System.monotonic_time()

    Enum.each(1..iterations, fn _ ->
      workload_fn.(component)
    end)

    end_time = System.monotonic_time()

    duration =
      System.convert_time_unit(end_time - start_time, :native, :millisecond)

    %{
      total_time: duration,
      average_time: duration / iterations,
      iterations: iterations
    }
  end

  @doc """
  Validates component accessibility features.
  """
  def validate_accessibility(component) do
    # Render with accessibility context
    {_updated, rendered} =
      component.module.render(component.state, %{
        accessibility: %{
          high_contrast: true,
          screen_reader: true
        }
      })

    # Validate rendered output
    validate_rendered_accessibility(rendered)
  end

  # Private Helpers

  @doc """
  Mounts a component, initializing its state and triggering mount-time effects.
  """
  def mount_component(component) do
    if function_exported?(component.module, :mount, 1) do
      {new_state, _commands} = component.module.mount(component.state)
      %{component | state: new_state}
    else
      component
    end
  end

  @doc """
  Unmounts a component, allowing it to clean up resources.
  """
  def unmount_component(component) do
    if function_exported?(component.module, :unmount, 1) do
      new_state = component.module.unmount(component.state)
      %{component | state: new_state}
    else
      component
    end
  end

  defp get_lifecycle_events(component) do
    Map.get(component.state, :__lifecycle_events__, [])
  end

  defp validate_rendered_accessibility(rendered) do
    # Basic accessibility checks
    checks = [
      has_contrast_ratio: check_contrast_ratio(rendered),
      has_aria_labels: check_aria_labels(rendered),
      has_keyboard_navigation: check_keyboard_navigation(rendered)
    ]

    # Return validation results
    %{
      passed: Enum.all?(checks, fn {_key, value} -> value end),
      checks: checks
    }
  end

  defp check_contrast_ratio(_rendered) do
    # TODO: Implement contrast ratio checking
    true
  end

  defp check_aria_labels(_rendered) do
    # TODO: Implement ARIA label checking
    true
  end

  defp check_keyboard_navigation(_rendered) do
    # TODO: Implement keyboard navigation checking
    true
  end

  @doc """
  Sets up a component hierarchy with parent and child components.
  """
  def setup_component_hierarchy(parent_module, child_module)
      when is_atom(child_module) do
    parent = create_test_component(parent_module)
    child = create_test_component(child_module, %{parent_id: parent.state.id})
    parent = %{parent | state: %{parent.state | children: [child.state.id]}}
    {parent, child}
  end

  def setup_component_hierarchy(parent_module, child_modules)
      when is_list(child_modules) do
    parent = create_test_component(parent_module)

    children =
      Enum.map(child_modules, fn module ->
        create_test_component(module, %{parent_id: parent.state.id})
      end)

    child_ids = Enum.map(children, & &1.state.id)
    parent = %{parent | state: %{parent.state | children: child_ids}}
    {parent, children}
  end

  @doc """
  Asserts that a component hierarchy is valid.
  """
  def assert_hierarchy_valid(parent, children) do
    assert parent.state.children == Enum.map(children, & &1.state.id)

    Enum.each(children, fn child ->
      assert child.state.parent_id == parent.state.id
    end)
  end

  @doc """
  Mounts a child component with a parent, updating the child's state to reference the parent as needed.
  """
  def mount_component(child_component, parent_component) do
    # Optionally update the child's state with parent_id if not already set
    child_state =
      if Map.get(child_component.state, :parent_id) == nil and
           Map.has_key?(parent_component.state, :id) do
        %{child_component.state | parent_id: parent_component.state.id}
      else
        child_component.state
      end

    if function_exported?(child_component.module, :mount, 1) do
      {new_state, _commands} = child_component.module.mount(child_state)
      %{child_component | state: new_state}
    else
      %{child_component | state: child_state}
    end
  end
end
