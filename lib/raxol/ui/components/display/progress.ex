defmodule Raxol.UI.Components.Display.Progress do
  @moduledoc """
  A progress bar component for displaying completion status.

  Features:
  * Customizable colors
  * Percentage display option
  * Custom width
  * Animated progress
  * Optional label
  """

  alias Raxol.UI.Components.Base.Component
  alias Raxol.UI.Theming.Theme

  @behaviour Component

  @type props :: %{
          optional(:id) => String.t(),
          optional(:progress) => float(),  # 0.0 to 1.0
          optional(:width) => integer(),
          optional(:show_percentage) => boolean(),
          optional(:label) => String.t(),
          optional(:theme) => map(),
          optional(:animated) => boolean()
        }

  @type state :: %{
          animation_frame: integer(),
          last_update: integer()  # timestamp for animation
        }

  @type t :: %{
          props: props(),
          state: state()
        }

  @animation_chars [" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"]
  @animation_speed 100  # ms between frames

  @impl Component
  def create(props) do
    %{
      props: normalize_props(props),
      state: %{
        animation_frame: 0,
        last_update: System.monotonic_time(:millisecond)
      }
    }
  end

  @impl Component
  def update(component, new_props) do
    updated_props = Map.merge(component.props, normalize_props(new_props))

    # Update animation state if needed
    state =
      if Map.get(new_props, :animated, false) do
        now = System.monotonic_time(:millisecond)
        time_diff = now - component.state.last_update

        if time_diff >= @animation_speed do
          # Advance animation frame
          new_frame = rem(component.state.animation_frame + 1, length(@animation_chars))
          %{animation_frame: new_frame, last_update: now}
        else
          component.state
        end
      else
        component.state
      end

    %{component | props: updated_props, state: state}
  end

  @impl Component
  def handle_event(component, _event, _context) do
    # Progress bar doesn't respond to events directly
    {:ok, component}
  end

  @impl Component
  def render(component, _context) do
    props = component.props
    progress = props.progress
    width = props.width
    theme = props.theme || Theme.get_current()
    colors = theme[:progress] || %{
      fg: :green,
      bg: :black,
      border: :white,
      text: :white
    }

    # Calculate the filled width
    filled_width = floor(progress * (width - 2))

    # Generate progress bar content
    bar_content = generate_bar_content(filled_width, width - 2, colors, props.animated, component.state.animation_frame)

    # Create percentage text if needed
    percentage_text =
      if props.show_percentage do
        percent_str = "#{floor(progress * 100)}%"
        # Center the percentage text in the bar
        padding = div(width - String.length(percent_str), 2)
        String.duplicate(" ", max(0, padding)) <> percent_str
      else
        ""
      end

    # Elements list
    progress_elements = [
      # Border box
      %{
        type: :box,
        width: width,
        height: 1,
        attrs: %{
          fg: colors.border,
          bg: colors.bg,
          border: %{
            top_left: "[",
            top_right: "]",
            bottom_left: "[",
            bottom_right: "]",
            horizontal: " ",
            vertical: "|"
          }
        }
      },
      # Progress fill
      %{
        type: :text,
        x: 1, # Inside the border
        y: 0,
        text: bar_content,
        attrs: %{
          fg: colors.fg,
          bg: colors.bg
        }
      }
    ]

    # Add percentage text if needed
    progress_elements =
      if props.show_percentage do
        text_element = %{
          type: :text,
          x: 1,
          y: 0,
          text: percentage_text,
          attrs: %{
            fg: colors.text,
            bg: :transparent # To show the bar underneath
          }
        }
        [text_element | progress_elements]
      else
        progress_elements
      end

    # Add label if provided
    progress_elements =
      if label = props.label do
        label_element = %{
          type: :text,
          x: 0,
          y: -1, # Above the progress bar
          text: label,
          attrs: %{
            fg: colors.text,
            bg: colors.bg
          }
        }
        [label_element | progress_elements]
      else
        progress_elements
      end

    progress_elements
  end

  # Private helpers

  defp normalize_props(props) do
    props = Map.new(props)

    # Ensure proper value ranges and defaults
    props
    |> Map.put_new(:progress, 0.0)
    |> Map.put_new(:width, 20)
    |> Map.put_new(:show_percentage, false)
    |> Map.put_new(:animated, false)
    |> Map.put_new(:label, nil)
    |> Map.update!(:progress, &(max(0.0, min(1.0, &1))))  # Clamp between 0.0 and 1.0
  end

  defp generate_bar_content(filled_width, total_width, colors, animated, animation_frame) do
    empty_width = total_width - filled_width

    # For full blocks
    filled_part = String.duplicate("█", filled_width)

    # For empty space
    empty_part = String.duplicate(" ", empty_width)

    # If animated and not complete, add animation character at the edge
    if animated && filled_width < total_width do
      # Calculate animation character
      animation_char = Enum.at(@animation_chars, animation_frame)

      # Insert animation character at the transition point
      if filled_width > 0 do
        filled_part <> animation_char <> String.slice(empty_part, 1..-1)
      else
        animation_char <> String.slice(empty_part, 1..-1)
      end
    else
      # No animation
      filled_part <> empty_part
    end
  end
end
