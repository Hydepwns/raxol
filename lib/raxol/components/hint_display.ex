defmodule Raxol.Components.HintDisplay do
  @moduledoc """
  Displays contextual hints and keyboard shortcuts.
  """
  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Logger

  # Require view macros
  require Raxol.View.Elements

  # Define state struct
  defstruct id: nil,
            hints: [], # List of hint strings or {key, description} tuples
            visible: true,
            position: :bottom, # :top, :bottom, :left, :right
            style: %{}

  # --- Component Behaviour Callbacks ---

  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize state
    %__MODULE__{
      id: props[:id],
      hints: props[:hints] || [],
      visible: Map.get(props, :visible, true),
      position: props[:position] || :bottom,
      style: props[:style] || %{}
    }
  end

  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle messages to update hints or visibility
    Logger.debug("HintDisplay #{state.id} received message: #{inspect msg}")
    case msg do
      {:set_hints, hints} when is_list(hints) ->
        {%{state | hints: hints}, []}
      :show -> {%{state | visible: true}, []}
      :hide -> {%{state | visible: false}, []}
      _ -> {state, []}
    end
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    # Typically doesn't handle direct events
    Logger.debug("HintDisplay #{state.id} received event: #{inspect event}")
    {state, []}
  end

  # --- Render Logic ---

  @impl Raxol.UI.Components.Base.Component
  def render(state, %{} = _props) do # Correct arity
    if state.visible and state.hints != [] do
      # Format hints (example: key: desc)
      hint_texts = Enum.map(state.hints, fn
        {key, desc} -> "#{key}: #{desc}"
        hint when is_binary(hint) -> hint
        _ -> ""
      end)

      # Join hints with a separator
      display_text = Enum.join(hint_texts, " | ")

      # Use View Elements macros
      dsl_result = Raxol.View.Elements.box id: state.id, style: Map.merge(%{width: :fill, height: 1}, state.style) do
        Raxol.View.Elements.label(content: display_text)
      end

      dsl_result # Return element map directly
    else
      nil # Render nothing if not visible or no hints
    end
  end

  # Remove old render/2, render_title, render_hints, render_shortcuts, render_footer
  # Remove old @impl Component annotations

end
