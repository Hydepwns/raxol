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
            show_percentage: false

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
      style: props[:style] || %{},
      label: props[:label],
      label_position: props[:label_position] || :below,
      show_percentage: props[:show_percentage] || false
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
    percentage_text = get_percentage_text(state.show_percentage, percentage)

    label_content = state.label

    # Combine based on label position
    rendered_view =
      case state.label_position do
        :above ->
          Raxol.View.Elements.column id: state.id do
            Raxol.View.Elements.row style: %{justify: :space_between} do
              build_label_row(
                label_content,
                label_style,
                percentage_text,
                percentage_style
              )
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
              build_label_row(
                label_content,
                label_style,
                percentage_text,
                percentage_style
              )
            end
          end

        :right ->
          Raxol.View.Elements.row id: state.id do
            [
              Raxol.View.Elements.row do
                [filled_portion, empty_portion]
              end,
              create_label_element(label_content, label_style),
              create_label_element(percentage_text, percentage_style)
            ]
            |> Enum.reject(&is_nil/1)
          end
      end

    # Return element structure
    rendered_view
    # Or wrap: View.to_element(rendered_view)
  end

  # --- Internal Helpers ---

  defp clamp(value, min_val, max_val) do
    value |> max(min_val) |> min(max_val)
  end

  defp get_percentage_text(true, percentage), do: " #{round(percentage * 100)}%"
  defp get_percentage_text(false, _percentage), do: nil

  defp create_label_element(nil, _style), do: nil

  defp create_label_element(content, style) do
    Raxol.View.Elements.label(
      content: content,
      style: style
    )
  end

  defp build_label_row(
         label_content,
         label_style,
         percentage_text,
         percentage_style
       ) do
    [
      create_label_element(label_content, label_style),
      create_label_element(percentage_text, percentage_style)
    ]
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Mount hook - called when component is mounted.
  No special setup needed for ProgressBar.
  """
  @impl true
  @spec mount(map()) :: {map(), list()}
  def mount(state), do: {state, []}

  @doc """
  Unmount hook - called when component is unmounted.
  No cleanup needed for ProgressBar.
  """
  @impl true
  @spec unmount(map()) :: map()
  def unmount(state), do: state

  # Remove old render/1 and handle_event/2 if they existed
end
