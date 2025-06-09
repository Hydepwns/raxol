defmodule Raxol.UI.Components.Terminal do
  @moduledoc """
  Terminal component for displaying and interacting with terminal content.
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
  require Raxol.View.Elements

  # Define state struct
  defstruct id: nil,
            width: 80,
            height: 24,
            # Add buffer, emulator state, etc.
            # Example: List of lines
            buffer: [],
            style: %{},
            mounted: false,
            render_count: 0,
            type: :terminal,
            focused: false,
            disabled: false

  alias Raxol.Core.Events.Event

  @doc """
  Creates a new terminal component with the given options.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    {:ok, state} = init(opts)
    state
  end

  @doc """
  Initializes the terminal component state from the given props.
  """
  @impl true
  @spec init(keyword()) :: {:ok, t()}
  def init(props) do
    # Initialize terminal state using props, providing defaults
    state = %__MODULE__{
      id: Map.get(props, :id, nil),
      width: props[:width] || 80,
      height: props[:height] || 24,
      # Use buffer from props or default to []
      buffer: props[:buffer] || [],
      style: Map.get(props, :style, %{}),
      type: :terminal,
      focused: props[:focused] || false,
      disabled: props[:disabled] || false
      # Initialize other relevant fields if added later
    }

    {:ok, state}
  end

  @doc """
  Mounts the terminal component. Performs any setup needed after initialization.
  """
  @impl true
  @spec mount(t()) :: {t(), list()}
  def mount(_state) do
    # ... existing code ...
  end

  @doc """
  Unmounts the terminal component, performing any necessary cleanup.
  """
  @impl true
  @spec unmount(t()) :: t()
  def unmount(_state) do
    # ... existing code ...
  end

  @doc """
  Updates the terminal component state in response to messages or prop changes.
  """
  @impl true
  @spec update(map(), t()) :: {:ok, t(), list()}
  def update(props, _state) when is_map(props) do
    # ... existing code ...
  end

  @impl true
  @spec update(term(), t()) :: {:ok, t(), list()}
  def update(_msg, _state) do
    # ... existing code ...
  end

  @doc """
  Handles events for the terminal component.
  """
  @impl true
  def handle_event(%Event{type: :key, data: _data}, _context, _state) do
    # ... existing code ...
  end

  def handle_event(%Event{type: :mouse, data: _data}, _context, _state) do
    # ... existing code ...
  end

  def handle_event(_event, _context, _state) do
    :ok
  end

  @doc """
  Renders the terminal component using the current state and context.
  """
  @impl true
  @spec render(t(), map()) :: any()
  def render(state, _context) do
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
        id: Map.get(state, :id, nil),
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
end
