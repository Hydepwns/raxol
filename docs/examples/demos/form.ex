defmodule Raxol.Examples.FormDemo do
  @moduledoc """
  A sample form component that demonstrates parent-child interactions.

  This component includes:
  - Child component management
  - Event bubbling
  - State synchronization
  - Error boundaries
  """

  use Raxol.Core.Runtime.Application
  require Raxol.Core.Runtime.Log
  require Raxol.View.Elements
  alias Raxol.View.Elements, as: UI
  
  defstruct form_data: %{username: "", password: ""}, submitted: false, id: :form_example

  @doc """
  Initialize the form component with default state (for testing compatibility).
  """
  def new(props \\ %{}) do
    %{
      submitted: false,
      button_clicked: nil,
      fields: Map.get(props, :fields, %{}),
      on_submit: Map.get(props, :on_submit, fn -> :submitted end),
      children: Map.get(props, :children, []),
      errors: Map.get(props, :errors, %{}),
      id: Map.get(props, :id, :form_example),
      form_data: Map.get(props, :form_data, %{username: "", password: ""})
    }
  end

  @impl Raxol.Core.Runtime.Application
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl Raxol.Core.Runtime.Application
  def update({:input, field, value}, state) do
    new_form_data = Map.put(state.form_data, field, value)
    {%{state | form_data: new_form_data}, []}
  end

  def update({:submit}, state) do
    # Log submission, don't emit command
    Raxol.Core.Runtime.Log.info("Form submitted: #{inspect state.form_data}")
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

  @doc """
  Render the form UI.
  """
  @impl Raxol.Core.Runtime.Application
  @dialyzer {:nowarn_function, view: 1}
  def view(state) do
    UI.box id: state.id, border: :rounded, padding: 1 do
      UI.column do
        [
          UI.label("Username:"),
          UI.text_input(id: :username_input, value: state.form_data.username),
          UI.label("Password:"),
          UI.text_input(id: :password_input, value: state.form_data.password, password: true),
          UI.button(id: :submit_button, label: "Submit"),
          case state.submitted do
            true -> UI.label("Submitted!")
            false -> nil
          end
        ] |> Enum.reject(&nil?/1)
      end
    end
  end

  # Add a render/2 function for test compatibility
  # def render(state, _context) do
  #   view(state)
  # end

  # Add handle_event/3 for integration testing with Raxol.Test.Integration
  # This will be called by the test framework when events bubble from children.
  def handle_event(state, %Raxol.Core.Events.Event{type: :button_pressed}, _opts) do
    # Log submission (similar to update/2 logic)
    Raxol.Core.Runtime.Log.info("Form received :button_pressed, processing as submit: #{inspect state.form_data}")
    new_state = %{state | submitted: true}
    # For assert_parent_updated to pass, parent must dispatch an event of type :button_clicked.
    # Use a new :dispatch_to_self command that the integration framework will handle.
    {:update, new_state, [{:dispatch_to_self, %Raxol.Core.Events.Event{type: :button_clicked}}]}
  end

  # Catch-all for other events in integration test context if needed,
  # ensuring it doesn't conflict with the Application behaviour handle_event/1.
  # This specific arity is for the test framework.
  def handle_event(state, _event, _opts) do
    # Default pass-through for other events not specifically handled by Form in this context
    {:noreply, state, []} # Or simply :passthrough if state is guaranteed to be a component state map
  end
end
