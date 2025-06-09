defmodule Raxol.UI.Components.HintDisplay do
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
            style: %{},
            mounted: false,
            render_count: 0,
            type: :hint_display,
            focused: false,
            disabled: false,
            text: ""

  # --- Component Behaviour Callbacks ---

  @doc "Initializes the HintDisplay component state from props."
  @spec init(map()) :: %__MODULE__{}
  @impl Raxol.UI.Components.Base.Component
  def init(props) when is_map(props) do
    %__MODULE__{
      id: Map.get(props, :id, nil),
      hints: props[:hints] || [],
      visible: Map.get(props, :visible, true),
      position: props[:position] || :bottom,
      style: Map.get(props, :style, %{}),
      type: Map.get(props, :type, :hint_display),
      focused: Map.get(props, :focused, false),
      disabled: Map.get(props, :disabled, false),
      mounted: Map.get(props, :mounted, false),
      render_count: Map.get(props, :render_count, 0),
      text: Map.get(props, :text, "")
    }
  end

  def init(_),
    do: %__MODULE__{
      style: %{},
      type: :hint_display,
      mounted: false,
      render_count: 0,
      text: ""
    }

  @doc "Updates the HintDisplay component state in response to messages."
  @spec update(term(), %__MODULE__{}) :: {%__MODULE__{}, list()}
  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle messages to update hints or visibility
    Raxol.Core.Runtime.Log.debug(
      "HintDisplay #{Map.get(state, :id, nil)} received message: #{inspect(msg)}"
    )

    case msg do
      {:set_hints, hints} when is_list(hints) ->
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
          hint when is_binary(hint) -> hint
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
      if is_map(dsl_result) do
        dsl_result
        |> Map.put_new(:disabled, Map.get(state, :disabled, false))
        |> Map.put_new(:focused, Map.get(state, :focused, false))
      else
        dsl_result
      end
    else
      # Render nothing if not visible or no hints
      nil
    end
  end

  # Remove old render/2, render_title, render_hints, render_shortcuts, render_footer
  # Remove old @impl Component annotations
end
