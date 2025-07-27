defmodule Raxol.UI.Components.Progress.Spinner do
  @moduledoc """
  Handles spinner components.
  """

  require Raxol.View.Elements

  @doc """
  Initializes a spinner state with the given properties.
  """
  def init(props \\ %{}) do
    style = Map.get(props, :style, :dots)
    frames = get_frames_for_style(style, Map.get(props, :frames))
    colors = Map.get(props, :colors, [:white])

    %{
      style: style,
      frames: frames,
      frame_index: 0,
      colors: colors,
      color_index: 0,
      speed: Map.get(props, :speed, 80),
      text: Map.get(props, :text),
      text_position: Map.get(props, :text_position, :right),
      last_update: System.monotonic_time(:millisecond)
    }
  end

  @doc """
  Updates the spinner state based on the given event.
  """
  def update(:tick, state) do
    current_time = System.monotonic_time(:millisecond)

    if current_time - state.last_update >= state.speed do
      %{
        state
        | frame_index: rem(state.frame_index + 1, length(state.frames)),
          color_index: rem(state.color_index + 1, length(state.colors)),
          last_update: current_time
      }
    else
      state
    end
  end

  def update(:reset, state) do
    %{state | frame_index: 0, color_index: 0}
  end

  def update({:set_text, text}, state) do
    %{state | text: text}
  end

  def update({:set_style, style}, state) do
    frames = get_frames_for_style(style)
    %{state | style: style, frames: frames, frame_index: 0}
  end

  def update({:set_custom_frames, frames}, state) do
    %{state | style: :custom, frames: frames, frame_index: 0}
  end

  def update({:set_colors, colors}, state) do
    %{state | colors: colors, color_index: 0}
  end

  def update({:set_speed, speed}, state) do
    %{state | speed: speed}
  end

  @doc """
  Handles events for the spinner component.
  """
  def handle_event(
        %Raxol.Core.Events.Event{type: :timer, data: %{id: :spinner_timer}},
        _model,
        state
      ) do
    {update(:tick, state), []}
  end

  def handle_event(_event, _model, state) do
    {state, []}
  end

  @doc """
  Creates a default loading spinner.
  """
  def loading do
    init(%{text: "Loading"})
  end

  @doc """
  Creates a processing spinner with the given text.
  """
  def processing(text) do
    init(%{
      text: text,
      colors: [:blue, :cyan, :green],
      speed: 100
    })
  end

  @doc """
  Creates a saving spinner.
  """
  def saving do
    init(%{
      style: :pulse,
      text: "Saving",
      colors: [:yellow, :green],
      speed: 500
    })
  end

  @doc """
  Creates an error spinner with the given text.
  """
  def error(text) do
    init(%{
      style: :pulse,
      text: text,
      colors: [:red],
      speed: 1000
    })
  end

  @spec render_spinner(map()) :: any()
  def render_spinner(state) do
    # Based on original spinner logic
    frame =
      Enum.at(state.frames, state.frame_index, "?")

    Raxol.View.Elements.row id: Map.get(state, :id, nil), style: state.style do
      Raxol.View.Elements.label(content: frame)

      if state.label do
        Raxol.View.Elements.label(
          content: state.label,
          style: %{margin_left: 1}
        )
      end
    end
  end

  @spec spinner(String.t() | nil, integer(), keyword()) :: any()
  @doc """
  Renders a spinner animation for indicating loading or processing.

  ## Parameters

  * `message` - Optional message to display next to the spinner
  * `frame` - Current animation frame (integer, typically incremented on each render)
  * `opts` - Options for customizing the spinner

  ## Options

  * `:id` - Unique identifier for the spinner (default: "spinner")
  * `:style` - Style for the spinner container
  * `:spinner_style` - Style for the spinner character
  * `:message_style` - Style for the message text
  * `:type` - Type of spinner animation (default: :dots)

  ## Returns

  A view element representing the spinner.

  ## Example

  ```elixir
  # In your update function, increment the frame on each update
  def update(model, :tick) do
    %{model | spinner_frame: model.spinner_frame + 1}
  end

  # In your view function
  Progress.Spinner.spinner(
    "Processing data...",
    model.spinner_frame,
    type: :braille,
    spinner_style: %{fg: :cyan}
  )
  ```
  """
  def spinner(message \\ nil, frame, opts \\ []) do
    # Extract options with defaults
    id = Keyword.get(opts, :id, "spinner")
    style = Keyword.get(opts, :style, %{})
    spinner_style = Keyword.get(opts, :spinner_style, %{fg: :blue})
    message_style = Keyword.get(opts, :message_style, %{})
    spinner_type = Keyword.get(opts, :type, :dots)

    # Get spinner frames
    frames = Map.get(spinner_types(), spinner_type, default_spinner_frames())

    # Calculate current frame to display
    frame_index = rem(frame, length(frames))
    current_frame = Enum.at(frames, frame_index)

    # Create the spinner with optional message
    Raxol.View.Elements.row([id: id, style: style],
      do: fn ->
        # Create spinner character element
        spinner_element =
          Raxol.View.Elements.label(
            content: current_frame,
            style: spinner_style
          )

        # Create message element if provided
        message_element =
          if message do
            Raxol.View.Elements.label(
              content: " #{message}",
              style: message_style
            )
          else
            nil
          end

        # Return elements, filtering nil
        [spinner_element, message_element]
        |> Enum.reject(&is_nil/1)
      end
    )
  end

  # Helper functions
  defp default_spinner_frames do
    [
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
  end

  defp spinner_types do
    %{
      dots: default_spinner_frames(),
      line: ["|", "/", "-", "\\"],
      braille: ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"],
      pulse: ["█", "▓", "▒", "░"],
      circle: ["◐", "◓", "◑", "◒"],
      bounce: ["⠁", "⠂", "⠄", "⠂"]
    }
  end

  defp get_frames_for_style(style, custom_frames \\ nil) do
    case style do
      :custom when not is_nil(custom_frames) -> custom_frames
      :custom -> default_spinner_frames()
      _ -> Map.get(spinner_types(), style, default_spinner_frames())
    end
  end
end
