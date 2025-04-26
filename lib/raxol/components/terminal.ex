defmodule Raxol.Components.Terminal do
  @moduledoc """
  A terminal component that emulates a standard terminal within the UI.
  """

  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Logger

  # Require view macros
  require Raxol.View.Elements

  # Define state struct
  defstruct id: nil,
            width: 80,
            height: 24,
            # Add buffer, emulator state, etc.
            buffer: [], # Example: List of lines
            style: %{}

  # --- Component Behaviour Callbacks ---

  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize terminal emulator state, buffer, etc.
    %__MODULE__{
      id: props[:id],
      width: props[:width] || 80,
      height: props[:height] || 24,
      style: props[:style] || %{}
      # Initialize buffer, etc.
    }
  end

  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle messages to write to terminal, clear, etc.
    Logger.debug("Terminal #{state.id} received message: #{inspect msg}")
    # Placeholder
    {state, []}
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event(%{type: :key} = event, %{} = _props, state) do # Use map matching
    # Process key event, send to terminal emulator/process
    Logger.debug("Terminal #{state.id} received key event: #{inspect event.data}")
    # Placeholder: Append key to buffer for simple echo
    new_buffer = state.buffer ++ ["Key: #{inspect event.data.key}"]
    {%{state | buffer: new_buffer}, []}
  end

  # Catch-all handle_event
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    Logger.debug("Terminal #{state.id} received event: #{inspect event.type}")
    {state, []}
  end

  # --- Render Logic ---

  @impl Raxol.UI.Components.Base.Component
  def render(state, %{} = _props) do
    # Render the terminal buffer content
    # Assuming buffer is a list of strings
    # Needs proper cell grid rendering based on actual emulator state

    # Use View Elements macros
    lines = Enum.map(state.buffer, &Raxol.View.Elements.label(content: &1))

    dsl_result = Raxol.View.Elements.box id: state.id, width: state.width, height: state.height, style: state.style do
      Raxol.View.Elements.column do
        lines
      end
    end

    # Return the element structure directly
    dsl_result
  end

  # --- Internal Helpers ---

  # Remove old handle_event/3 with @impl Component

end
