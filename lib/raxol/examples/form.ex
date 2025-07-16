defmodule Raxol.Examples.Form do
  @moduledoc """
  A simple Form component for testing button interactions.
  """

  @doc """
  Initialize the form component with default state.
  """
  def new(props \\ %{}) do
    %{
      submitted: false,
      button_clicked: nil,
      fields: Map.get(props, :fields, %{}),
      on_submit: Map.get(props, :on_submit, fn -> :submitted end),
      children: Map.get(props, :children, []),
      errors: Map.get(props, :errors, %{}),
      id: Map.get(props, :id, :form_example)
    }
  end

  @doc """
  Handle events for the form component.
  """
  def handle_event(%{type: :clicked}, state) do
    {
      %{state | submitted: true, button_clicked: true},
      [:form_submitted]
    }
  end

  def handle_event(_event, state) do
    {state, []}
  end

  @doc """
  Render the form component.
  """
  def render(state) do
    # Just a stub for testing
    "Form Component: #{inspect(state)}"
  end
end
