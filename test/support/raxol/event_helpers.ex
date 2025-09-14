defmodule Raxol.Test.EventHelpers do
  @moduledoc """
  Helpers for testing event handling in Raxol components.
  Provides utilities for simulating and verifying events.
  """

  alias Raxol.Core.Events.Event
  import ExUnit.Assertions

  @doc """
  Simulates a user action on a component.
  """
  def simulate_user_action(component, action) do
    case action do
      {:click, pos} ->
        simulate_event(
          component,
          Event.new(:click, target: component.state.id, position: pos)
        )

      :focus ->
        simulate_event(component, Event.new(:focus, target: component.state.id))

      :blur ->
        simulate_event(component, Event.new(:blur, target: component.state.id))

      {:key, key} ->
        simulate_event(
          component,
          Event.new(:key, target: component.state.id, key: key)
        )

      other ->
        simulate_event(component, other)
    end
  end

  @doc """
  Simulates an event on a component.
  """
  def simulate_event(component, event) do
    Raxol.Test.Unit.simulate_event(component, event)
  end

  @doc """
  Asserts that a child component received an event from parent.
  """
  def assert_child_received(_child, event_name) do
    receive do
      {:event, received_event_name} ->
        assert received_event_name == event_name
    after
      1000 -> flunk("Did not receive expected event: #{inspect(event_name)}")
    end
  end

  @doc """
  Asserts that a parent component was updated after a child event.
  """
  def assert_parent_updated(parent, update_type) do
    assert Map.get(parent.state, update_type) != nil
  end

  @doc """
  Verifies that state is synchronized between components.
  """
  def assert_state_synchronized(components, validation_fn) do
    component_states = Enum.map(components, & &1.state)
    assert validation_fn.(component_states)
  end

  @doc """
  Verifies that a component properly handles system events.
  """
  def assert_system_events_handled(component, events) do
    Enum.each(events, fn event ->
      {updated, _} = simulate_event(component, event)

      assert updated.state != nil,
             "Component failed to handle event: #{inspect(event)}"
    end)
  end

  @doc """
  Verifies that error handling works properly between components.
  """
  def assert_error_contained(parent, child, error_fn) do
    case Raxol.Core.ErrorHandling.safe_call(error_fn) do
      {:ok, _} ->
        flunk("Expected an error but none was raised")

      {:error, %RuntimeError{} = e} ->
        assert parent.state != nil
        assert child.state != nil
        assert e.__struct__ == RuntimeError

      {:error, _other} ->
        flunk("Expected a RuntimeError but got a different error type")
    end
  end
end
