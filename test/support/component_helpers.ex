defmodule Raxol.ComponentHelpers do
  @moduledoc """
  Test helpers for Raxol components.

  This module provides utilities for testing components, including
  rendering, event simulation, and state inspection.
  """

  alias Raxol.Core.Events.Event

  @doc """
  Simulates a component event and returns the new state and commands.
  """
  def simulate_event(component, event_type, event_data \\ %{}) do
    event = %Event{type: event_type, data: event_data}
    component.handle_event(event, component.state)
  end

  @doc """
  Renders a component and returns the rendered output.
  """
  def render_component(component) do
    component.render(component.state)
  end

  @doc """
  Asserts that a component has a specific style property.
  """
  defmacro assert_style(component, property, expected) do
    quote do
      style = unquote(component).style
      actual = Map.get(style, unquote(property))

      assert actual == unquote(expected),
             "Expected style property #{unquote(property)} to be #{inspect(unquote(expected))}, got #{inspect(actual)}"
    end
  end

  @doc """
  Asserts that a component emits specific commands.
  """
  defmacro assert_commands(actual_commands, expected_commands) do
    quote do
      assert Enum.sort(unquote(actual_commands)) ==
               Enum.sort(unquote(expected_commands)),
             "Expected commands #{inspect(unquote(expected_commands))}, got #{inspect(unquote(actual_commands))}"
    end
  end

  @doc """
  Creates a test component with the given state.
  """
  def create_test_component(module, state \\ %{}) do
    struct(module, %{state: state})
  end
end
