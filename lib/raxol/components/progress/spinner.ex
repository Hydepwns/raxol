defmodule Raxol.Components.Progress.Spinner do
  @moduledoc """
  A spinner component that provides animated loading indicators.

  ## Props
    * `:style` - The animation style to use (default: :dots)
    * `:dots` - Rotating dots (⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏)
    * `:line` - Rotating line (|/-\\)
    * `:bounce` - Bouncing ball (⠁⠂⠄⠂)
    * `:pulse` - Pulsing circle (●○)
    * `:custom` - Custom animation using `:frames`
    * `:frames` - List of characters to use for custom animation
    * `:colors` - List of colors to transition between
    * `:speed` - Animation speed in milliseconds (default: 80)
    * `:text` - Optional text to display next to the spinner
    * `:text_position` - Position of text relative to spinner (:left or :right, default: :right)
  """

  use Raxol.UI.Components.Base.Component

  require Logger
  import Raxol.View.Elements

  @default_speed 80
  @default_style :dots

  @animation_frames %{
    dots: ~w(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏),
    line: ~w(| / - \\),
    bounce: ~w(⠁ ⠂ ⠄ ⠂),
    pulse: ~w(● ○)
  }

  @impl true
  def init(props) do
    style = props[:style] || @default_style
    frames = get_frames(style, props[:frames])
    colors = props[:colors] || [:white]

    %{
      style: style,
      frames: frames,
      frame_index: 0,
      colors: colors,
      color_index: 0,
      speed: props[:speed] || @default_speed,
      text: props[:text],
      text_position: props[:text_position] || :right,
      last_update: System.monotonic_time(:millisecond)
    }
  end

  defp get_frames(:custom, custom_frames) when is_list(custom_frames),
    do: custom_frames

  defp get_frames(style, _) when is_atom(style),
    do: @animation_frames[style] || @animation_frames.dots

  defp get_frames(_, _), do: @animation_frames.dots

  @impl true
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
    frames = get_frames(style, nil)
    %{state | style: style, frames: frames, frame_index: 0}
  end

  def update({:set_custom_frames, frames}, state) when is_list(frames) do
    %{state | style: :custom, frames: frames, frame_index: 0}
  end

  def update({:set_colors, colors}, state) when is_list(colors) do
    %{state | colors: colors, color_index: 0}
  end

  def update({:set_speed, speed}, state) when is_integer(speed) and speed > 0 do
    %{state | speed: speed}
  end

  def update(_msg, state), do: state

  @impl true
  def render(%{} = _props, state) do
    spinner_char = Enum.at(state.frames, state.frame_index)
    spinner_color = Enum.at(state.colors, state.color_index)
    spinner_style = [color: spinner_color]
    label_style = [color: :white] # Assuming a default label style

    # Use label macro from imported Raxol.View.Elements
    dsl_result =
      row do # Use the imported row macro
        if state.text do
          spinner_content = label(content: spinner_char, style: spinner_style)
          label_content = label(content: state.text, style: label_style)
          case state.text_position do
            :left -> [label_content, label(content: " "), spinner_content]
            _ -> [spinner_content, label(content: " "), label_content]
          end
        else
          label(content: spinner_char, style: spinner_style)
        end
      end

    # Convert to Element struct
    dsl_result # Return the DSL map directly, LayoutEngine handles it
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event(%{type: :timer, data: %{id: _timer_id}} = _event, %{} = _props, state) do
    # Access event fields using dot notation if needed
    # Logger.debug("Spinner timer event: #{inspect event.data}")
    next_frame = rem(state.frame_index + 1, length(state.frames))
    # Return updated state and potentially commands
    {%{state | frame_index: next_frame}, []}
  end

  # Catch-all handle_event
  @impl Raxol.UI.Components.Base.Component
  def handle_event(_event, %{} = _props, state), do: {state, []}

  # Helper functions for common spinner configurations
  def loading(text \\ "Loading") do
    init(%{text: text})
  end

  def processing(text \\ "Processing") do
    init(%{
      style: :dots,
      text: text,
      colors: [:blue, :cyan, :green],
      speed: 100
    })
  end

  def saving(text \\ "Saving") do
    init(%{
      style: :pulse,
      text: text,
      colors: [:yellow, :green],
      speed: 500
    })
  end

  def error(text \\ "Error") do
    init(%{
      style: :pulse,
      text: text,
      colors: [:red],
      speed: 1000
    })
  end
end
