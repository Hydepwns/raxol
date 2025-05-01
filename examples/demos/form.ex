defmodule Raxol.Examples.Form do
  @moduledoc """
  A sample form component that demonstrates parent-child interactions.

  This component includes:
  - Child component management
  - Event bubbling
  - State synchronization
  - Error boundaries
  """

  use Raxol.Core.Runtime.Application
  require Logger
  require Raxol.View.Elements
  alias Raxol.View.Elements, as: UI

  defstruct form_data: %{username: "", password: ""}, submitted: false, id: :form_example

  @impl Raxol.Core.Runtime.Application
  def init(_opts) do
    {%__MODULE__{}, []}
  end

  @impl Raxol.Core.Runtime.Application
  def update({:input, field, value}, state) do
    new_form_data = Map.put(state.form_data, field, value)
    {%{state | form_data: new_form_data}, []}
  end

  def update({:submit}, state) do
    # Log submission, don't emit command
    Logger.info("Form submitted: #{inspect state.form_data}")
    {%{state | submitted: true}, []}
  end

  def update(_msg, state) do
    {state, []} # Ignore other messages
  end

  # Correct arity for Application behaviour
  @impl Raxol.Core.Runtime.Application
  def handle_event({:raxol_event, _source_pid, {:component_event, component_id, event_type, payload}}) do
    # Translate component events into update messages
    case {component_id, event_type} do
      {:username_input, :change} -> [{:input, :username, payload}] # Assuming payload is the new value
      {:password_input, :change} -> [{:input, :password, payload}] # Assuming payload is the new value
      {_, :click} -> [:submit] # Assuming any click in the form context is a submit
      _ -> [] # Ignore other component events
    end
  end

  def handle_event(_event) do
    # State is managed by Dispatcher, just return commands/messages
    # Keep this catch-all for other event types (e.g., keyboard, mouse if needed)
    []
  end

  @impl Raxol.Core.Runtime.Application
  def handle_message(_msg, state), do: {state, []} # Keep state for handle_message

  # Correct arity for Application behaviour
  @impl Raxol.Core.Runtime.Application
  def handle_tick(_tick) do
    # State is managed by Dispatcher, just return commands
    []
  end

  @impl Raxol.Core.Runtime.Application
  def subscriptions(_state), do: []

  @impl Raxol.Core.Runtime.Application
  def terminate(_reason, _state), do: :ok

  # Correct view function with @impl
  @impl Raxol.Core.Runtime.Application
  def view(state) do
    UI.box id: state.id, border: :rounded, padding: 1 do
      UI.column do
        [
          UI.label("Username:"),
          UI.text_input(id: :username_input, value: state.form_data.username),
          UI.label("Password:"),
          UI.text_input(id: :password_input, value: state.form_data.password, is_password: true),
          UI.button(id: :submit_button, label: "Submit"),
          (if state.submitted, do: UI.label("Submitted!"), else: nil)
        ] |> Enum.reject(&is_nil(&1))
      end
    end
  end

  # Remove incorrect render function
  # def render(state) do
  #   ...
  # end
end
