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

  use ExUnit.CaseTemplate

  # Import the assertions module
  import Raxol.Test.Unit.Assertions

  alias Raxol.Core.Events.Event

  defmacro __using__(_opts) do
    quote do
      import Raxol.Test.Unit
      import Raxol.Test.Unit.Assertions

      # setup do
      #   start_supervised!(Manager)
      #   start_supervised!(EventLoop)
      #   :ok
      # end
      # The setup block is removed as TestHelper.setup_test_env handles this.
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
  Sets up a component for isolated testing with initial properties.
  """
  def setup_isolated_component(component, props) when is_map(props) do
    # Initialize component with test props
    {:ok, state} = component.init(props)

    # Create a test process to track events and state
    test_pid = self()

    # Mock the event system
    mock_event_system = fn event ->
      send(test_pid, {:event, event})
    end

    # Set up the component with mocked dependencies
    result = %{
      module: component,
      state: state,
      subscriptions: [],
      event_handler: mock_event_system
    }

    if !(is_map(result) and Map.has_key?(result, :module) and
           Map.has_key?(result, :state)) do
      raise ArgumentError,
            "setup_isolated_component/2 expected a map with :module and :state keys, got: #{inspect(result)}"
    end

    {:ok, result}
  end

  # Keep setup_isolated_component/1 for default props
  def setup_isolated_component(component) do
    setup_isolated_component(component, %{})
  end

  @doc """
  Simulates an event being sent to a component.

  Returns the updated state and any emitted commands.
  """
  def simulate_event(component, %Event{} = event) do
    # Call handle_event/3, passing empty map as opts for now
    IO.puts("Simulating event: #{inspect(event)}")
    IO.puts("Initial component state: #{inspect(component.state)}")
    result = component.module.handle_event(component.state, event, %{})
    IO.puts("handle_event result: #{inspect(result)}")

    {new_state_map, commands} =
      case result do
        {:update, updated_state, cmds} ->
          {updated_state, cmds}

        # Assume no commands if not specified
        {:update, updated_state} ->
          {updated_state, []}

        {:noreply, state} ->
          {state, []}

        {:handled, state} ->
          {state, []}

        # State unchanged, no commands
        :passthrough ->
          {component.state, []}

        other ->
          raise "Unexpected return value from handle_event/3: #{inspect(other)}"
      end

    # Update component map with new state
    updated_component = %{component | state: new_state_map}
    # Log final state
    IO.puts("Final component state: #{inspect(updated_component.state)}")

    # Track commands for assertions
    send(self(), {:commands, commands})

    {updated_component, commands}
  end

  # Allow simulate_event to accept plain maps as events for test convenience
  def simulate_event(component, event) when is_map(event) do
    simulate_event(component, Raxol.Core.Events.Event.custom_event(event))
  end

  @doc """
  Creates a keyboard event for testing.
  """
  def keyboard_event(key) when is_atom(key) do
    Event.key_event(key, :pressed)
  end

  def keyboard_event(char) when is_integer(char) do
    Event.key_event({:char, char}, :pressed)
  end

  @doc """
  Creates a window event for testing.
  """
  def window_event(width, height, action) do
    Event.window_event(action, width, height)
  end

  @doc """
  Creates a custom event for testing.
  """
  def custom_event(data) do
    Event.custom_event(data)
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
end
