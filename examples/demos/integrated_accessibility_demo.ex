defmodule Raxol.Examples.IntegratedAccessibilityDemo do
  @moduledoc "Simplified version of the Integrated Accessibility Demo."

  @behaviour Raxol.Core.Runtime.Application

  defstruct message: "Hello from Simplified Demo"

  @impl Raxol.Core.Runtime.Application
  def init(_opts) do
    {%__MODULE__{}, []}
  end

  @impl Raxol.Core.Runtime.Application
  def update(_msg, state) do
    {state, []}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_event(%Raxol.Core.Events.Event{} = event) do
    case event.type do
      :button_clicked ->
        {:increment_clicks, nil}

      :checkbox_toggled ->
        {:toggle_checkbox, nil}

      _ ->
        nil
    end
  end

  @impl Raxol.Core.Runtime.Application
  def handle_message(_msg, state) do
    {state, []}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_tick(_tick) do
    []
  end

  @impl Raxol.Core.Runtime.Application
  def subscriptions(_state) do
    []
  end

  @impl Raxol.Core.Runtime.Application
  def terminate(_reason, _state) do
    :ok
  end

  @impl Raxol.Core.Runtime.Application
  @dialyzer {:nowarn_function, view: 1}
  def view(state) do
    # Using direct map construction for label to avoid macro issues
    %{type: :label, attrs: [content: state.message]}
  end
end
