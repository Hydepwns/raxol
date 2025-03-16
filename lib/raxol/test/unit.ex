defmodule Raxol.Test.Unit do
  @moduledoc """
  Provides utilities for unit testing Raxol components and modules.

  This module offers a comprehensive set of tools for:
  - Component isolation and testing
  - Event simulation and verification
  - State management testing
  - Render output validation

  ## Example

      defmodule MyComponent.Test do
        use ExUnit.Case
        use Raxol.Test.Unit

        test_component "handles keyboard input", MyComponent do
          event = keyboard_event(:enter)
          result = simulate_event(component, event)
          
          assert_state(component, %{text: ""})
          assert_command_emitted(result, :submit)
        end
      end
  """

  alias Raxol.Core.Events.{Event, Manager, Subscription}
  alias Raxol.Core.Runtime.EventLoop

  defmacro __using__(_opts) do
    quote do
      import Raxol.Test.Unit
      import Raxol.Test.Unit.Assertions
      
      setup do
        start_supervised!(Manager)
        start_supervised!(EventLoop)
        :ok
      end
    end
  end

  defmacro test_component(name, component, do: block) do
    quote do
      test unquote(name) do
        {:ok, component} = setup_isolated_component(unquote(component))
        unquote(block)
      end
    end
  end

  @doc """
  Sets up a component for isolated testing.

  This function:
  1. Creates a mock event system
  2. Initializes the component
  3. Sets up state tracking
  4. Configures test subscriptions
  """
  def setup_isolated_component(component) do
    # Initialize component with test props
    state = component.init(%{})
    
    # Create a test process to track events and state
    test_pid = self()
    
    # Mock the event system
    mock_event_system = fn event ->
      send(test_pid, {:event, event})
    end
    
    # Set up the component with mocked dependencies
    {:ok, %{
      module: component,
      state: state,
      subscriptions: [],
      event_handler: mock_event_system
    }}
  end

  @doc """
  Simulates an event being sent to a component.

  Returns the updated state and any emitted commands.
  """
  def simulate_event(component, %Event{} = event) do
    {new_state, commands} = component.module.handle_event(event, component.state)
    
    # Update component state
    updated_component = %{component | state: new_state}
    
    # Track commands for assertions
    send(self(), {:commands, commands})
    
    {updated_component, commands}
  end

  @doc """
  Creates a keyboard event for testing.
  """
  def keyboard_event(key) when is_atom(key) do
    Event.key(key)
  end

  def keyboard_event(char) when is_integer(char) do
    Event.key({:char, char})
  end

  @doc """
  Creates a mouse event for testing.
  """
  def mouse_event(button, position, opts \\ []) do
    Event.mouse(button, position, opts)
  end

  @doc """
  Creates a window event for testing.
  """
  def window_event(width, height, action) do
    Event.window(width, height, action)
  end

  @doc """
  Creates a custom event for testing.
  """
  def custom_event(data) do
    Event.custom(data)
  end

  @doc """
  Asserts that a component's state matches the expected state.
  """
  def assert_state(component, expected_state) do
    actual_state = component.state
    assert_state_match(actual_state, expected_state)
  end

  @doc """
  Asserts that a command was emitted by the component.
  """
  def assert_command_emitted({_component, commands}, command) do
    assert command in commands,
           "Expected command #{inspect(command)} to be emitted, but got: #{inspect(commands)}"
  end

  @doc """
  Asserts that a specific event was handled by the component.
  """
  def assert_event_handled(component, event, expected_result) do
    {updated_component, commands} = simulate_event(component, event)
    assert updated_component.state == expected_result,
           "Expected state to be #{inspect(expected_result)}, but got: #{inspect(updated_component.state)}"
    {updated_component, commands}
  end

  # Private Helpers

  defp assert_state_match(actual, expected) when is_map(actual) and is_map(expected) do
    Enum.each(expected, fn {key, value} ->
      assert Map.get(actual, key) == value,
             "Expected state.#{key} to be #{inspect(value)}, but got: #{inspect(Map.get(actual, key))}"
    end)
  end

  defp assert_state_match(actual, expected) do
    assert actual == expected,
           "Expected state to be #{inspect(expected)}, but got: #{inspect(actual)}"
  end
end 