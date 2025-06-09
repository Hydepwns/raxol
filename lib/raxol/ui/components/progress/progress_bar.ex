defmodule Raxol.UI.Components.Progress.ProgressBar do
  @moduledoc """
  A component to display a progress bar.
  """

  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log

  # Require view macros
  require Raxol.View.Elements
  # Alias view helper if needed
  # alias Raxol.Core.Renderer.View

  # Define state struct
  defstruct id: nil,
            value: 0,
            max: 100,
            width: 20,
            style: %{},
            label: nil,
            # :above, :below, :right
            label_position: :below,
            show_percentage: false,
            mounted: false,
            render_count: 0,
            type: :progress_bar,
            focused: false,
            disabled: false

  # --- Component Behaviour Callbacks ---

  @spec init(map()) :: %__MODULE__{}
  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize state from props
    %__MODULE__{
      id: props[:id],
      value: props[:value] || 0,
      max: props[:max] || 100,
      width: props[:width] || 20,
      style: Map.get(props, :style, %{}),
      label: props[:label],
      label_position: props[:label_position] || :below,
      show_percentage: props[:show_percentage] || false,
      type: :progress_bar,
      focused: Map.get(props, :focused, false),
      disabled: Map.get(props, :disabled, false)
    }
  end

  @spec update(term(), %__MODULE__{}) :: {%__MODULE__{}, list()}
  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle messages to update value
    Raxol.Core.Runtime.Log.debug(
      "ProgressBar #{state.id} received message: #{inspect(msg)}"
    )

    case msg do
      {:set_value, value} when is_number(value) ->
        {%{state | value: clamp(value, 0, state.max)}, []}

      _ ->
        {state, []}
    end
  end

  @spec handle_event(term(), map(), %__MODULE__{}) :: {%__MODULE__{}, list()}
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    # Handle events if needed
    Raxol.Core.Runtime.Log.debug(
      "ProgressBar #{state.id} received event: #{inspect(event)}"
    )

    {state, []}
  end

  # --- Render Logic ---

  @spec render(%__MODULE__{}, map()) :: any()
  @impl Raxol.UI.Components.Base.Component
  # Correct arity
  def render(state, %{} = _props) do
    # Calculate fill
    percentage = state.value / state.max
    filled_width = round(state.width * percentage)
    empty_width = state.width - filled_width

    # Define styles (example)
    filled_style = Map.get(state.style, :filled, %{bg: :green})
    empty_style = Map.get(state.style, :empty, %{bg: :gray})
    label_style = Map.get(state.style, :label, %{})
    percentage_style = Map.get(state.style, :percentage, %{})

    # Create bar portions
    filled_portion =
      Raxol.View.Elements.label(
        content: String.duplicate(" ", filled_width),
        style: filled_style
      )

    empty_portion =
      Raxol.View.Elements.label(
        content: String.duplicate(" ", empty_width),
        style: empty_style
      )

    # Create label/percentage texts/elements conditionally
    percentage_text =
      if state.show_percentage, do: " #{round(percentage * 100)}%", else: nil

    label_content = state.label

    # Combine based on label position
    rendered_view =
      case state.label_position do
        :above ->
          Raxol.View.Elements.column id: state.id do
            Raxol.View.Elements.row style: %{justify: :space_between} do
              [
                if(label_content,
                  do:
                    Raxol.View.Elements.label(
                      content: label_content,
                      style: label_style
                    ),
                  else: nil
                ),
                if(percentage_text,
                  do:
                    Raxol.View.Elements.label(
                      content: percentage_text,
                      style: percentage_style
                    ),
                  else: nil
                )
              ]
              |> Enum.reject(&is_nil(&1))
            end

            Raxol.View.Elements.row do
              [filled_portion, empty_portion]
            end
          end

        :below ->
          Raxol.View.Elements.column id: state.id do
            Raxol.View.Elements.row do
              [filled_portion, empty_portion]
            end

            Raxol.View.Elements.row style: %{justify: :space_between} do
              [
                if(label_content,
                  do:
                    Raxol.View.Elements.label(
                      content: label_content,
                      style: label_style
                    ),
                  else: nil
                ),
                if(percentage_text,
                  do:
                    Raxol.View.Elements.label(
                      content: percentage_text,
                      style: percentage_style
                    ),
                  else: nil
                )
              ]
              |> Enum.reject(&is_nil(&1))
            end
          end

        :right ->
          Raxol.View.Elements.row id: state.id do
            [
              Raxol.View.Elements.row do
                [filled_portion, empty_portion]
              end,
              if(label_content,
                do:
                  Raxol.View.Elements.label(
                    content: label_content,
                    style: label_style
                  ),
                else: nil
              ),
              if(percentage_text,
                do:
                  Raxol.View.Elements.label(
                    content: percentage_text,
                    style: percentage_style
                  ),
                else: nil
              )
            ]
            |> Enum.reject(&is_nil(&1))
          end
      end

    # At the end, ensure :disabled and :focused are present in the returned map if possible
    if is_map(rendered_view) do
      rendered_view
      |> Map.put_new(:disabled, Map.get(state, :disabled, false))
      |> Map.put_new(:focused, Map.get(state, :focused, false))
    else
      rendered_view
    end

    # Or wrap: View.to_element(rendered_view)
  end

  # --- Internal Helpers ---

  defp clamp(value, min_val, max_val) do
    value |> max(min_val) |> min(max_val)
  end

  # Remove old render/1 and handle_event/2 if they existed
end
