defmodule Raxol.UI.Components.Progress.Component do
  @moduledoc """
  Handles component behaviour for progress components.
  """

  use Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log
  require Raxol.View.Elements

  # NOTE: This file must be saved as UTF-8 for Unicode characters to work correctly.
  @spinner_frames [
    "⠋",
    "⠙",
    "⠹",
    "⠸",
    "⠼",
    "⠴",
    "⠦",
    "⠧",
    "⠇",
    "⠏"
  ]

  # Define state struct
  defstruct id: nil,
            # :bar, :spinner, :indeterminate, :circular
            type: :bar,
            value: 0,
            max: 100,
            label: nil,
            style: %{},
            # State for spinner
            frames: [],
            frame_index: 0,
            # ms
            interval: 100

  @spec init(map()) :: map()
  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize state based on type and props
    type = Map.get(props, :type, :bar)
    base_state = struct!(__MODULE__, props)

    # Set up frames and interval based on type
    state =
      case type do
        :spinner ->
          %{
            base_state
            | frames:
                Map.get(
                  spinner_types(),
                  Map.get(props, :spinner_type, :dots),
                  @spinner_frames
                ),
              interval: Map.get(props, :interval, 100)
          }

        :indeterminate ->
          %{base_state | interval: Map.get(props, :interval, 100)}

        _ ->
          base_state
      end

    %{state | type: type}
  end

  @spec update(term(), map()) :: {map(), list()}
  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle messages to update value, change type, etc.
    Raxol.Core.Runtime.Log.debug(
      "Progress #{Map.get(state, :id, nil)} received message: #{inspect(msg)}"
    )

    # Placeholder
    case msg do
      {:set_value, value} when is_number(value) ->
        {%{state | value: clamp(value, 0, state.max)}, []}

      :tick when state.type == :spinner ->
        next_frame = rem(state.frame_index + 1, length(state.frames))
        {%{state | frame_index: next_frame}, []}

      _ ->
        {state, []}
    end
  end

  @spec handle_event(term(), map(), map()) :: {map(), list()}
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    # Handle events if needed
    Raxol.Core.Runtime.Log.debug(
      "Progress #{Map.get(state, :id, nil)} received event: #{inspect(event)}"
    )

    {state, []}
  end

  @spec render(map(), map()) :: any()
  @impl Raxol.UI.Components.Base.Component
  def render(state, %{} = _props) do
    case state.type do
      :bar -> Raxol.UI.Components.Progress.Bar.render_bar(state)
      :spinner -> Raxol.UI.Components.Progress.Spinner.render_spinner(state)
      :indeterminate -> Raxol.UI.Components.Progress.Indeterminate.render_indeterminate(state)
      :circular -> Raxol.UI.Components.Progress.Circular.render_circular(state)
      _ -> Raxol.View.Elements.label(content: "Unknown progress type")
    end
  end

  # Helper functions
  defp clamp(value, min, max) do
    value |> Kernel.max(min) |> Kernel.min(max)
  end

  @spec spinner_types() :: map()
  @doc """
  Returns the available spinner types.

  ## Returns

  A map of spinner types to their frame sequences.

  ## Example

  ```elixir
  spinner_types = Progress.Component.spinner_types()
  ```
  """
  def spinner_types do
    %{
      dots: @spinner_frames,
      line: ["|", "/", "-", "\\"],
      braille: ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"],
      pulse: ["█", "▓", "▒", "░"],
      circle: ["◐", "◓", "◑", "◒"]
    }
  end
end
