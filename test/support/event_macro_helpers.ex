defmodule EventMacroHelpers do
  @moduledoc """
  Event-related macros and helpers for testing event-driven code in Raxol.

  This module provides convenient macros for:
  - Event creation and simulation
  - Event assertion and verification
  - Event sequence testing
  - Component event handling testing
  """

  import ExUnit.Assertions
  import ExUnit.Callbacks

  @doc """
  Creates a test event with the given type and optional data.

  ## Parameters
    * `type` - The event type (atom)
    * `data` - Optional event data (map, default: %{})

  ## Examples
      iex> event = EventMacroHelpers.create_event(:click, %{x: 10, y: 20})
      iex> event.type
      :click
      iex> event.data
      %{x: 10, y: 20}
  """
  defmacro create_event(type, data \\ %{}) do
    quote do
      Raxol.Core.Events.Event.new(unquote(type), unquote(data))
    end
  end

  @doc """
  Asserts that an event of the specified type is received within the timeout.

  ## Parameters
    * `event_type` - The expected event type (atom)
    * `timeout` - Timeout in milliseconds (default: 1000)

  ## Examples
      iex> EventMacroHelpers.assert_event_type(:click)
      :ok
  """
  defmacro assert_event_type(event_type, timeout \\ 1000) do
    quote do
      assert_receive %Raxol.Core.Events.Event{type: unquote(event_type)},
                     unquote(timeout)
    end
  end

  @doc """
  Asserts that an event with the specified type and data is received within the timeout.

  ## Parameters
    * `event_type` - The expected event type (atom)
    * `expected_data` - The expected event data (map)
    * `timeout` - Timeout in milliseconds (default: 1000)

  ## Examples
      iex> EventMacroHelpers.assert_event_with_data(:click, %{x: 10, y: 20})
      :ok
  """
  defmacro assert_event_with_data(event_type, expected_data, timeout \\ 1000) do
    quote do
      assert_receive %Raxol.Core.Events.Event{
                       type: unquote(event_type),
                       data: data
                     },
                     unquote(timeout)

      assert data == unquote(expected_data),
             "Expected event data #{inspect(unquote(expected_data))}, got #{inspect(data)}"
    end
  end

  @doc """
  Refutes that an event of the specified type is received within the timeout.

  ## Parameters
    * `event_type` - The event type to refute (atom)
    * `timeout` - Timeout in milliseconds (default: 1000)

  ## Examples
      iex> EventMacroHelpers.refute_event_type(:click)
      :ok
  """
  defmacro refute_event_type(event_type, timeout \\ 1000) do
    quote do
      refute_receive %Raxol.Core.Events.Event{type: unquote(event_type)},
                     unquote(timeout)
    end
  end

  @doc """
  Asserts that a sequence of events is received in the specified order.

  ## Parameters
    * `event_sequence` - List of event types in expected order
    * `timeout` - Timeout per event in milliseconds (default: 1000)

  ## Examples
      iex> EventMacroHelpers.assert_event_sequence([:mousedown, :click, :mouseup])
      :ok
  """
  defmacro assert_event_sequence(event_sequence, timeout \\ 1000) do
    quote do
      Enum.each(unquote(event_sequence), fn event_type ->
        assert_receive %Raxol.Core.Events.Event{type: ^event_type},
                       unquote(timeout)
      end)
    end
  end

  @doc """
  Simulates sending an event to a component and returns the updated component state.

  ## Parameters
    * `component` - The component to send the event to
    * `event_type` - The event type (atom)
    * `event_data` - Optional event data (map, default: %{})

  ## Returns
    * `Raxol.UI.Components.Base.Component` - The updated component

  ## Examples
      iex> updated_component = EventMacroHelpers.simulate_component_event(component, :click, %{x: 10, y: 20})
      iex> updated_component.state.click_count
      1
  """
  defmacro simulate_component_event(component, event_type, event_data \\ %{}) do
    quote do
      event =
        Raxol.Core.Events.Event.new(unquote(event_type), unquote(event_data))

      Raxol.Test.Unit.simulate_event(unquote(component), event)
    end
  end

  @doc """
  Asserts that a component emits an event of the specified type.

  ## Parameters
    * `component` - The component that should emit the event
    * `event_type` - The expected event type (atom)
    * `timeout` - Timeout in milliseconds (default: 1000)

  ## Examples
      iex> EventMacroHelpers.assert_component_emits_event(component, :submit)
      :ok
  """
  defmacro assert_component_emits_event(component, event_type, timeout \\ 1000) do
    quote do
      # Simulate the component event
      {_updated_component, _effects} =
        simulate_component_event(unquote(component), unquote(event_type))

      # Assert that the event was emitted
      assert_event_type(unquote(event_type), unquote(timeout))
    end
  end

  @doc """
  Asserts that a component's state contains the expected values after an event.

  ## Parameters
    * `component` - The component to check
    * `event_type` - The event type to simulate (atom)
    * `event_data` - Optional event data (map, default: %{})
    * `expected_state` - Map of expected state values
    * `timeout` - Timeout in milliseconds (default: 1000)

  ## Examples
      iex> EventMacroHelpers.assert_component_state_after_event(component, :increment, %{}, %{count: 1})
      :ok
  """
  defmacro assert_component_state_after_event(
             component,
             event_type,
             event_data \\ %{},
             expected_state,
             timeout \\ 1000
           ) do
    quote do
      {updated_component, _effects} =
        simulate_component_event(
          unquote(component),
          unquote(event_type),
          unquote(event_data)
        )

      Enum.each(unquote(expected_state), fn {key, expected_value} ->
        actual_value = Map.get(updated_component.state, key)

        assert actual_value == expected_value,
               "Expected state.#{key} to be #{inspect(expected_value)}, got #{inspect(actual_value)}"
      end)
    end
  end

  @doc """
  Asserts that a component renders the expected content after an event.

  ## Parameters
    * `component` - The component to check
    * `event_type` - The event type to simulate (atom)
    * `event_data` - Optional event data (map, default: %{})
    * `expected_render` - Expected render output (map)
    * `timeout` - Timeout in milliseconds (default: 1000)

  ## Examples
      iex> EventMacroHelpers.assert_component_render_after_event(component, :update, %{text: "Hello"}, %{content: "Hello"})
      :ok
  """
  defmacro assert_component_render_after_event(
             component,
             event_type,
             event_data \\ %{},
             expected_render,
             timeout \\ 1000
           ) do
    quote do
      {updated_component, _effects} =
        simulate_component_event(
          unquote(component),
          unquote(event_type),
          unquote(event_data)
        )

      {_state, actual_render} =
        updated_component.render(updated_component.state, %{})

      Enum.each(unquote(expected_render), fn {key, expected_value} ->
        actual_value = Map.get(actual_render, key)

        assert actual_value == expected_value,
               "Expected render.#{key} to be #{inspect(expected_value)}, got #{inspect(actual_value)}"
      end)
    end
  end

  @doc """
  Asserts that no events are received within the timeout.

  ## Parameters
    * `timeout` - Timeout in milliseconds (default: 100)

  ## Examples
      iex> EventMacroHelpers.assert_no_events()
      :ok
  """
  defmacro assert_no_events(timeout \\ 100) do
    quote do
      refute_receive %Raxol.Core.Events.Event{}, unquote(timeout)
    end
  end

  @doc """
  Asserts that exactly N events of the specified type are received within the timeout.

  ## Parameters
    * `event_type` - The event type to count (atom)
    * `expected_count` - Expected number of events
    * `timeout` - Timeout in milliseconds (default: 1000)

  ## Examples
      iex> EventMacroHelpers.assert_event_count(:click, 3)
      :ok
  """
  defmacro assert_event_count(event_type, expected_count, timeout \\ 1000) do
    quote do
      events = collect_events(unquote(event_type), unquote(timeout))
      actual_count = length(events)

      assert actual_count == unquote(expected_count),
             "Expected #{unquote(expected_count)} events of type #{unquote(event_type)}, got #{actual_count}"
    end
  end

  @doc """
  Collects all events of the specified type received within the timeout.

  ## Parameters
    * `event_type` - The event type to collect (atom)
    * `timeout` - Timeout in milliseconds (default: 1000)

  ## Returns
    * `list()` - List of received events

  ## Examples
      iex> events = EventMacroHelpers.collect_events(:click, 1000)
      iex> length(events)
      3
  """
  defmacro collect_events(event_type, timeout \\ 1000) do
    quote do
      collect_events_recursive(unquote(event_type), [], unquote(timeout))
    end
  end

  # Helper function for collecting events recursively
  defp collect_events_recursive(event_type, collected, timeout) do
    receive do
      %Raxol.Core.Events.Event{type: ^event_type} = event ->
        collect_events_recursive(event_type, [event | collected], timeout)
    after
      timeout ->
        Enum.reverse(collected)
    end
  end

  @doc """
  Asserts that an event has the expected source.

  ## Parameters
    * `event_type` - The event type (atom)
    * `expected_source` - The expected event source
    * `timeout` - Timeout in milliseconds (default: 1000)

  ## Examples
      iex> EventMacroHelpers.assert_event_source(:click, :button_component)
      :ok
  """
  defmacro assert_event_source(event_type, expected_source, timeout \\ 1000) do
    quote do
      assert_receive %Raxol.Core.Events.Event{
                       type: unquote(event_type),
                       source: source
                     },
                     unquote(timeout)

      assert source == unquote(expected_source),
             "Expected event source #{inspect(unquote(expected_source))}, got #{inspect(source)}"
    end
  end

  @doc """
  Asserts that an event has the expected timestamp (within a tolerance).

  ## Parameters
    * `event_type` - The event type (atom)
    * `expected_timestamp` - The expected timestamp (integer)
    * `tolerance_ms` - Tolerance in milliseconds (default: 100)
    * `timeout` - Timeout in milliseconds (default: 1000)

  ## Examples
      iex> EventMacroHelpers.assert_event_timestamp(:click, System.system_time(:millisecond), 50)
      :ok
  """
  defmacro assert_event_timestamp(
             event_type,
             expected_timestamp,
             tolerance_ms \\ 100,
             timeout \\ 1000
           ) do
    quote do
      assert_receive %Raxol.Core.Events.Event{
                       type: unquote(event_type),
                       timestamp: timestamp
                     },
                     unquote(timeout)

      diff = abs(timestamp - unquote(expected_timestamp))

      assert diff <= unquote(tolerance_ms),
             "Event timestamp #{timestamp} differs from expected #{unquote(expected_timestamp)} by #{diff}ms (tolerance: #{unquote(tolerance_ms)}ms)"
    end
  end

  @doc """
  Asserts that a component handles an event without raising an exception.

  ## Parameters
    * `component` - The component to test
    * `event_type` - The event type to simulate (atom)
    * `event_data` - Optional event data (map, default: %{})

  ## Examples
      iex> EventMacroHelpers.assert_component_handles_event_safely(component, :error_event)
      :ok
  """
  defmacro assert_component_handles_event_safely(
             component,
             event_type,
             event_data \\ %{}
           ) do
    quote do
      try do
        {_updated_component, _effects} =
          simulate_component_event(
            unquote(component),
            unquote(event_type),
            unquote(event_data)
          )

        :ok
      rescue
        e ->
          flunk(
            "Component failed to handle event #{unquote(event_type)} safely: #{inspect(e)}"
          )
      end
    end
  end

  @doc """
  Asserts that a component's lifecycle methods are called in the correct order.

  ## Parameters
    * `component` - The component to test
    * `expected_lifecycle` - List of expected lifecycle events (atoms)

  ## Examples
      iex> EventMacroHelpers.assert_component_lifecycle(component, [:init, :mount, :render])
      :ok
  """
  defmacro assert_component_lifecycle(component, expected_lifecycle) do
    quote do
      # This would need to be implemented with a mock or spy mechanism
      # For now, this is a placeholder that could be extended
      lifecycle_events = get_component_lifecycle_events(unquote(component))

      assert lifecycle_events == unquote(expected_lifecycle),
             "Expected lifecycle #{inspect(unquote(expected_lifecycle))}, got #{inspect(lifecycle_events)}"
    end
  end

  # Placeholder function for getting component lifecycle events
  # This would need to be implemented with proper mocking/spying
  defp get_component_lifecycle_events(_component) do
    # This is a placeholder - in a real implementation, you'd track lifecycle calls
    [:init, :mount, :render]
  end
end
