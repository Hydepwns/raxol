defmodule Raxol.UI.Components.Terminal do
  @moduledoc """
  A terminal component that emulates a standard terminal within the UI.
  """

  @typedoc """
  State for the Terminal component.

  - :id - unique identifier
  - :width - terminal width
  - :height - terminal height
  - :buffer - list of lines
  - :style - style map
  """
  @type t :: %__MODULE__{
          id: any(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          buffer: [String.t()],
          style: map()
        }

  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component

  require Raxol.Core.Runtime.Log

  # Require view macros
  # require Raxol.View.Elements  # Removed

  # Define state struct
  defstruct id: nil,
            width: 80,
            height: 24,
            # Add buffer, emulator state, etc.
            # Example: List of lines
            buffer: [],
            style: %{}

  # --- Component Behaviour Callbacks ---

  @doc "Initializes the Terminal component state from props."
  @spec init(map()) :: map()
  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Convert keyword list to map if needed
    props_map = if Keyword.keyword?(props), do: Map.new(props), else: props

    # Initialize terminal state using props, providing defaults
    %__MODULE__{
      id: Map.get(props_map, :id, nil),
      width: Map.get(props_map, :width, 80),
      height: Map.get(props_map, :height, 24),
      # Use buffer from props or default to []
      buffer: Map.get(props_map, :buffer, []),
      style: Map.get(props_map, :style, %{})
      # Initialize other relevant fields if added later
    }
  end

  @doc "Updates the Terminal component state in response to messages. Handles writing, clearing, etc."
  @spec update(term(), map()) :: {map(), list()}
  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle messages to write to terminal, clear, etc.
    Raxol.Core.Runtime.Log.debug(
      "Terminal #{Map.get(state, :id, nil)} received message: #{inspect(msg)}"
    )

    # Placeholder
    {state, []}
  end

  @doc "Handles key events for the Terminal component."
  @spec handle_event(map(), map(), map()) :: {map(), list()}
  @impl Raxol.UI.Components.Base.Component
  # Use map matching
  def handle_event(%{type: :key} = event, %{} = _props, state) do
    # Process key event, send to terminal emulator/process
    Raxol.Core.Runtime.Log.debug(
      "Terminal #{Map.get(state, :id, nil)} received key event: #{inspect(event.data)}"
    )

    # Placeholder: Append key to buffer for simple echo
    new_buffer = state.buffer ++ ["Key: #{inspect(event.data.key)}"]
    {%{state | buffer: new_buffer}, []}
  end

  # Catch-all handle_event
  @spec handle_event(map(), map(), map()) :: {map(), list()}
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    Raxol.Core.Runtime.Log.debug(
      "Terminal #{Map.get(state, :id, nil)} received event: #{inspect(event.type)}"
    )

    {state, []}
  end

  # --- Render Logic ---

  @doc "Renders the Terminal component, displaying the buffer as lines."
  @spec render(map(), map()) :: map()
  @impl Raxol.UI.Components.Base.Component
  def render(state, %{} = _props) do
    # Generate label elements
    label_elements =
      Enum.map(state.buffer, fn line_content ->
        # Build label element with attrs as a map
        %{type: :label, attrs: %{content: line_content}}
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
      # Make attrs a map instead of keyword list
      attrs: %{
        id: Map.get(state, :id, nil),
        width: state.width,
        height: state.height,
        style: state.style
      },
      # Assign the column map
      children: column_element
    }

    # Return the final element structure
    box_element
  end

  @doc """
  Mount hook - called when component is mounted.
  No special setup needed for Terminal.
  """
  @impl true
  @spec mount(map()) :: {map(), list()}
  def mount(state), do: {state, []}

  @doc """
  Unmount hook - called when component is unmounted.
  No cleanup needed for Terminal.
  """
  @impl true
  @spec unmount(map()) :: map()
  def unmount(state), do: state
end
