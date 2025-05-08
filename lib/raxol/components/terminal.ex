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
            # Example: List of lines
            buffer: [],
            style: %{}

  # --- Component Behaviour Callbacks ---

  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize terminal state using props, providing defaults
    %__MODULE__{
      id: props[:id],
      width: props[:width] || 80,
      height: props[:height] || 24,
      # Use buffer from props or default to []
      buffer: props[:buffer] || [],
      style: props[:style] || %{}
      # Initialize other relevant fields if added later
    }
  end

  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle messages to write to terminal, clear, etc.
    Logger.debug("Terminal #{state.id} received message: #{inspect(msg)}")
    # Placeholder
    {state, []}
  end

  @impl Raxol.UI.Components.Base.Component
  # Use map matching
  def handle_event(%{type: :key} = event, %{} = _props, state) do
    # Process key event, send to terminal emulator/process
    Logger.debug(
      "Terminal #{state.id} received key event: #{inspect(event.data)}"
    )

    # Placeholder: Append key to buffer for simple echo
    new_buffer = state.buffer ++ ["Key: #{inspect(event.data.key)}"]
    {%{state | buffer: new_buffer}, []}
  end

  # Catch-all handle_event
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    Logger.debug("Terminal #{state.id} received event: #{inspect(event.type)}")
    {state, []}
  end

  # --- Render Logic ---

  @impl Raxol.UI.Components.Base.Component
  def render(state, %{} = _props) do
    # Generate label elements
    label_elements =
      Enum.map(state.buffer, fn line_content ->
        # Still use label macro for consistency, or build map directly
        Raxol.View.Elements.label(content: line_content)
      end)

    # Create column element map explicitly
    column_element = %{
      type: :column,
      # Assuming no specific attrs for column here
      attrs: [],
      # Assign the list of labels
      children: label_elements
    }

    # Create box element map explicitly, using column as child
    box_element = %{
      type: :box,
      # Ensure attrs is a Keyword list as expected by test
      attrs: [
        id: state.id,
        width: state.width,
        height: state.height,
        style: state.style
      ],
      # Assign the column map
      children: column_element
    }

    # Return the final element structure
    box_element
  end

  # --- Internal Helpers ---

  # Remove old handle_event/3 with @impl Component
end
