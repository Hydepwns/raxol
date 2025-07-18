defmodule Raxol.UI.Components.HintDisplay do
  import Raxol.Guards

  @moduledoc """
  Displays contextual hints and keyboard shortcuts.
  """
  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log

  # Require view macros
  require Raxol.View.Elements

  # Define state struct
  defstruct id: nil,
            # List of hint strings or {key, description} tuples
            hints: [],
            visible: true,
            # :top, :bottom, :left, :right
            position: :bottom,
            style: %{}

  # --- Component Behaviour Callbacks ---

  @doc "Initializes the HintDisplay component state from props."
  @spec init(map()) :: %__MODULE__{}
  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize state
    %__MODULE__{
      id: Map.get(props, :id, nil),
      hints: props[:hints] || [],
      visible: Map.get(props, :visible, true),
      position: props[:position] || :bottom,
      style: props[:style] || %{}
    }
  end

  @doc "Updates the HintDisplay component state in response to messages."
  @spec update(term(), %__MODULE__{}) :: {%__MODULE__{}, list()}
  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle messages to update hints or visibility
    Raxol.Core.Runtime.Log.debug(
      "HintDisplay #{Map.get(state, :id, nil)} received message: #{inspect(msg)}"
    )

    case msg do
      {:set_hints, hints} when list?(hints) ->
        {%{state | hints: hints}, []}

      :show ->
        {%{state | visible: true}, []}

      :hide ->
        {%{state | visible: false}, []}

      _ ->
        {state, []}
    end
  end

  @doc "Handles events for the HintDisplay component. Typically does not handle direct events."
  @spec handle_event(term(), map(), %__MODULE__{}) :: {%__MODULE__{}, list()}
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    # Typically doesn't handle direct events
    Raxol.Core.Runtime.Log.debug(
      "HintDisplay #{Map.get(state, :id, nil)} received event: #{inspect(event)}"
    )

    {state, []}
  end

  # --- Render Logic ---

  @doc "Renders the HintDisplay component if visible and hints are present."
  @spec render(%__MODULE__{}, map()) :: any()
  @impl Raxol.UI.Components.Base.Component
  # Correct arity
  def render(state, %{} = _props) do
    if state.visible and state.hints != [] do
      # Format hints (example: key: desc)
      hint_texts =
        Enum.map(state.hints, fn
          {key, desc} -> "#{key}: #{desc}"
          hint when binary?(hint) -> hint
          _ -> ""
        end)

      # Join hints with a separator
      display_text = Enum.join(hint_texts, " | ")

      # Use View Elements macros
      dsl_result =
        Raxol.View.Elements.box id: Map.get(state, :id, nil),
                                style:
                                  Map.merge(
                                    %{width: :fill, height: 1},
                                    state.style
                                  ) do
          Raxol.View.Elements.label(content: display_text)
        end

      # Return element map directly
      dsl_result
    else
      # Render nothing if not visible or no hints
      nil
    end
  end

  # Remove old render/2, render_title, render_hints, render_shortcuts, render_footer
  # Remove old @impl Component annotations
end
